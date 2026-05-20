# backend/api/v1/routes/auth.py - Authentication routes

from fastapi import APIRouter, Depends, HTTPException, status, Header, Request
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from core.security import (
    hash_password,
    verify_password,
    verify_access_token,
    verify_refresh_token,
    SecurityManager
)
from middleware.rate_limiter import LoginAttemptTracker, RateLimiter
from repositories import (
    UserRepository,
    OrganizationRepository,
    EmployeeRepository,
    AuditLogRepository
)
from schemas import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    TokenRefreshRequest,
    UserResponse,
    ChangePasswordRequest,
    UserRole
)
from models import User
from repositories import UserRepository

router = APIRouter(tags=["Authentication"])
security_manager = SecurityManager()
login_tracker = LoginAttemptTracker(
    settings.REDIS_URL,
    max_attempts=settings.LOGIN_MAX_FAILED_ATTEMPTS,
    lockout_seconds=settings.LOGIN_LOCKOUT_SECONDS,
)
rate_limiter = RateLimiter(settings.REDIS_URL)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def get_token(authorization: str = Header(None)):
    if not authorization:
        return None

    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None

    return parts[1]


def get_client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for") or request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def get_current_user(token: str = Depends(get_token), db: Session = Depends(get_db)) -> User:
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = security_manager.verify_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = UserRepository.get_by_id(db, payload.sub)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )

    if user.token_invalid_before and payload.iat <= int(user.token_invalid_before.timestamp()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been invalidated"
        )

    return user


def get_current_employee(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    employee = EmployeeRepository.get_by_user_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee record not found for this user"
        )
    return employee

# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@router.post("/register", response_model=UserResponse)
async def register(request: RegisterRequest, db: Session = Depends(get_db), api_request: Request = None):
    org = None
    if request.organization_id:
        org = OrganizationRepository.get_by_id(db, request.organization_id)
        if not org:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Organization not found"
            )
    else:
        if not request.organization_name or not request.organization_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Organization name and email are required when creating a new organization"
            )
        existing_org = OrganizationRepository.get_by_email(db, request.organization_email)
        if existing_org:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Organization email already registered"
            )
        org = OrganizationRepository.create(
            db,
            name=request.organization_name,
            email=request.organization_email
        )

    if request.role == UserRole.EMPLOYEE and not request.employee_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Employee users must be registered with an existing employee_id"
        )

    assigned_employee_id = None
    if request.employee_id:
        employee = EmployeeRepository.get_by_employee_id(db, org.id, request.employee_id)
        if not employee:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Employee ID not found for this organization"
            )
        if UserRepository.get_by_employee_id(db, employee.id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Employee is already linked to a user account"
            )
        assigned_employee_id = employee.id

    existing_user = UserRepository.get_by_email(db, org.id, request.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this email already exists in the organization"
        )

    hashed_password = hash_password(request.password)
    user = UserRepository.create(
        db,
        org_id=org.id,
        email=request.email,
        password_hash=hashed_password,
        full_name=request.full_name,
        role=request.role,
        employee_id=assigned_employee_id
    )

    AuditLogRepository.create(
        db=db,
        org_id=org.id,
        action="user.register",
        resource_type="user",
        resource_id=user.id,
        user_id=user.id,
        status="success",
        ip_address=get_client_ip(api_request) if api_request else None,
        user_agent=api_request.headers.get("user-agent") if api_request else None,
        new_value=str({
            "email": user.email,
            "role": user.role,
            "employee_id": user.employee_id
        })
    )

    return user


@router.post("/login", response_model=LoginResponse)
async def login(request: Request, credentials: LoginRequest, db: Session = Depends(get_db)):
    ip_address = get_client_ip(request)

    rate_key = f"login_rate:ip:{ip_address}"
    allowed, remaining, reset_time = rate_limiter.check_limit(
        rate_key,
        settings.RATE_LIMIT_AUTH_PER_MINUTE,
        60
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts from this IP. Try again later."
        )

    if login_tracker.is_account_locked(credentials.email):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account locked due to repeated failed login attempts. Try again later."
        )

    user = UserRepository.get_by_email_any_org(db, email=credentials.email)
    if not user or not verify_password(credentials.password, user.password_hash):
        login_tracker.record_failed_attempt(credentials.email, ip_address)
        if user:
            AuditLogRepository.create(
                db=db,
                org_id=user.org_id,
                action="user.login.failure",
                resource_type="user",
                resource_id=user.id,
                user_id=user.id,
                status="failure",
                ip_address=ip_address,
                error_message="Invalid email or password"
            )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )

    login_tracker.record_successful_login(credentials.email)
    UserRepository.update_last_login(db, user.id)

    tokens = security_manager.create_tokens(
        user_id=user.id,
        org_id=user.org_id,
        role=user.role,
        permissions=[]
    )

    AuditLogRepository.create(
        db=db,
        org_id=user.org_id,
        action="user.login.success",
        resource_type="user",
        resource_id=user.id,
        user_id=user.id,
        status="success",
        ip_address=ip_address,
        user_agent=request.headers.get("user-agent")
    )

    return LoginResponse(
        access_token=tokens["access_token"],
        refresh_token=tokens["refresh_token"],
        user={
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role
        }
    )


@router.post("/refresh")
async def refresh_token(
    request: TokenRefreshRequest | None = None,
    authorization: str = Header(None),
    db: Session = Depends(get_db)
):
    refresh_token = None
    if request and getattr(request, "refresh_token", None):
        refresh_token = request.refresh_token
    elif authorization:
        refresh_token = get_token(authorization)

    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is required"
        )

    payload = security_manager.verify_refresh_token(refresh_token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )

    user = UserRepository.get_by_id(db, payload.sub)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )

    if user.token_invalid_before and payload.iat <= int(user.token_invalid_before.timestamp()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token revoked"
        )

    security_manager.blacklist_token(
        payload.jti,
        settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60
    )

    tokens = security_manager.create_tokens(
        user_id=user.id,
        org_id=user.org_id,
        role=user.role,
        permissions=[]
    )
    return tokens

@router.post("/logout")
async def logout(
    request: TokenRefreshRequest = None,
    current_user: User = Depends(get_current_user),
    token: str = Depends(get_token)
):
    access_payload = security_manager.verify_access_token(token)
    if access_payload:
        security_manager.blacklist_token(
            access_payload.jti,
            settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )

    if request and request.refresh_token:
        refresh_payload = security_manager.verify_refresh_token(request.refresh_token)
        if refresh_payload:
            security_manager.blacklist_token(
                refresh_payload.jti,
                settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60
            )

    return {"message": "Successfully logged out"}

@router.post("/change-password")
async def change_password(
    request: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    token: str = Depends(get_token),
    db: Session = Depends(get_db)
):
    if not verify_password(request.old_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Old password is incorrect"
        )

    if request.new_password != request.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passwords do not match"
        )

    UserRepository.update_password(db, current_user.id, hash_password(request.new_password))

    access_payload = security_manager.verify_access_token(token)
    if access_payload:
        security_manager.blacklist_token(
            access_payload.jti,
            settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )

    return {"message": "Password changed successfully"}


@router.post("/register-admin-seed", response_model=LoginResponse)
async def register_admin_seed(request: RegisterRequest, db: Session = Depends(get_db)):
    """One-time endpoint to create initial admin user for the system"""

    # Prevent multiple seeds
    existing = db.query(User).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin seed already completed"
        )

    # Create a new organization if provided or fallback to a default
    org = None
    if request.organization_name and request.organization_email:
        org = OrganizationRepository.create(db, name=request.organization_name, email=request.organization_email)
    else:
        org = OrganizationRepository.create(db, name="Default Org", email=request.email)

    # Create admin user
    hashed_password = hash_password(request.password)
    user = UserRepository.create(
        db,
        org_id=org.id,
        email=request.email,
        password_hash=hashed_password,
        full_name=request.full_name,
        role=UserRole.ADMIN.value
    )

    tokens = security_manager.create_tokens(
        user_id=user.id,
        org_id=org.id,
        role=user.role,
        permissions=[]
    )

    return LoginResponse(
        access_token=tokens["access_token"],
        refresh_token=tokens["refresh_token"],
        user={
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role
        }
    )
