# backend/core/security.py - Security utilities and authentication

from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from jose import JWTError, jwt
from pydantic import BaseModel
import logging
import uuid
import bcrypt
from redis import Redis

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# TOKEN BLACKLISTING
# ============================================================================

class TokenBlacklist:
    """Redis-backed token revocation store"""

    def __init__(self, redis_url: str = settings.REDIS_URL):
        self.redis = Redis.from_url(redis_url, decode_responses=True)

    def add(self, jti: str, ttl: int):
        try:
            self.redis.setex(f"token_blacklist:{jti}", ttl, "1")
            logger.debug(f"Blacklisted token {jti} for {ttl}s")
        except Exception as e:
            logger.error(f"Token blacklist write failed: {e}")

    def is_blacklisted(self, jti: str) -> bool:
        try:
            return self.redis.exists(f"token_blacklist:{jti}") > 0
        except Exception as e:
            logger.error(f"Token blacklist read failed: {e}")
            return False

# ============================================================================
# PASSWORD HASHING
# ============================================================================

def hash_password(password: str, rounds: int = 12) -> str:
    """Hash password using bcrypt"""
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    salt = bcrypt.gensalt(rounds=rounds)
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'),
            hashed_password.encode('utf-8')
        )
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False

# ============================================================================
# JWT TOKEN MANAGEMENT
# ============================================================================

class TokenPayload(BaseModel):
    """JWT token payload"""
    sub: str
    type: str
    org_id: str
    role: str
    permissions: List[str] = []
    jti: str
    iat: int
    exp: int


def _decode_token(token: str) -> Optional[Dict[str, Any]]:
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError as e:
        logger.warning(f"JWT verification failed: {e}")
        return None
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        return None


def create_access_token(
    user_id: str,
    org_id: str,
    role: str,
    permissions: List[str] = [],
    expires_delta: Optional[timedelta] = None
) -> str:
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    expire = datetime.utcnow() + expires_delta
    payload = {
        "sub": user_id,
        "type": "access",
        "jti": str(uuid.uuid4()),
        "org_id": org_id,
        "role": role,
        "permissions": permissions,
        "iat": int(datetime.utcnow().timestamp()),
        "exp": int(expire.timestamp())
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(
    user_id: str,
    org_id: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    expire = datetime.utcnow() + expires_delta
    payload = {
        "sub": user_id,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
        "org_id": org_id,
        "iat": int(datetime.utcnow().timestamp()),
        "exp": int(expire.timestamp())
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def verify_token(token: str, expected_type: str) -> Optional[TokenPayload]:
    payload = _decode_token(token)
    if not payload:
        return None

    if payload.get("type") != expected_type:
        logger.warning(f"Token type mismatch: expected {expected_type} got {payload.get('type')}")
        return None

    try:
        return TokenPayload(**payload)
    except Exception as e:
        logger.error(f"Malformed token payload: {e}")
        return None


def verify_access_token(token: str) -> Optional[TokenPayload]:
    return verify_token(token, "access")


def verify_refresh_token(token: str) -> Optional[TokenPayload]:
    return verify_token(token, "refresh")


def create_tokens(
    user_id: str,
    org_id: str,
    role: str,
    permissions: List[str] = []
) -> Dict[str, str]:
    access_token = create_access_token(
        user_id=user_id,
        org_id=org_id,
        role=role,
        permissions=permissions
    )
    refresh_token = create_refresh_token(
        user_id=user_id,
        org_id=org_id
    )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }

# ============================================================================
# SECURITY MANAGER
# ============================================================================

class SecurityManager:
    """Centralized security operations"""

    def __init__(self):
        self.blacklist = TokenBlacklist(settings.REDIS_URL)

    def hash_password(self, password: str) -> str:
        return hash_password(password)

    def verify_password(self, plain: str, hashed: str) -> bool:
        return verify_password(plain, hashed)

    def create_tokens(
        self,
        user_id: str,
        org_id: str,
        role: str,
        permissions: List[str] = []
    ) -> Dict[str, str]:
        return create_tokens(user_id, org_id, role, permissions)

    def verify_access_token(self, token: str) -> Optional[TokenPayload]:
        payload = verify_access_token(token)
        if payload and self.blacklist.is_blacklisted(payload.jti):
            logger.warning(f"Access token blacklisted: {payload.jti}")
            return None
        return payload

    def verify_refresh_token(self, token: str) -> Optional[TokenPayload]:
        payload = verify_refresh_token(token)
        if payload and self.blacklist.is_blacklisted(payload.jti):
            logger.warning(f"Refresh token blacklisted: {payload.jti}")
            return None
        return payload

    def blacklist_token(self, token_id: str, ttl: int):
        self.blacklist.add(token_id, ttl)

    def get_token_expiration(self, payload: TokenPayload) -> int:
        return payload.exp

    @staticmethod
    def generate_reset_token() -> str:
        return str(uuid.uuid4())

    @staticmethod
    def generate_verification_token() -> str:
        return str(uuid.uuid4())

# ============================================================================
# DEVICE FINGERPRINTING
# ============================================================================

class DeviceFingerprint:
    @staticmethod
    def create_fingerprint(
        device_id: str,
        device_type: str,
        os_type: str,
        os_version: str,
        app_version: str,
        user_agent: str,
        ip_address: str
    ) -> str:
        import hashlib
        fingerprint_string = f"{device_id}:{device_type}:{os_type}:{os_version}:{app_version}:{user_agent}:{ip_address}"
        return hashlib.sha256(fingerprint_string.encode()).hexdigest()

    @staticmethod
    def verify_fingerprint(
        current_fingerprint: str,
        stored_fingerprint: str,
        tolerance: int = 2
    ) -> bool:
        return current_fingerprint == stored_fingerprint

# ============================================================================
# ENCRYPTION UTILITIES
# ============================================================================

class EncryptionManager:
    from cryptography.fernet import Fernet

    @staticmethod
    def encrypt_field(value: str, key: str = settings.SECRET_KEY) -> str:
        f = EncryptionManager.Fernet(key.encode()[:32].ljust(32, b'0'))
        return f.encrypt(value.encode()).decode()

    @staticmethod
    def decrypt_field(encrypted_value: str, key: str = settings.SECRET_KEY) -> str:
        f = EncryptionManager.Fernet(key.encode()[:32].ljust(32, b'0'))
        return f.decrypt(encrypted_value.encode()).decode()

# ============================================================================
# DEVICE FINGERPRINTING
# ============================================================================

class DeviceFingerprint:
    """Create and verify device fingerprints for anti-fraud"""
    
    @staticmethod
    def create_fingerprint(
        device_id: str,
        device_type: str,
        os_type: str,
        os_version: str,
        app_version: str,
        user_agent: str,
        ip_address: str
    ) -> str:
        """Create device fingerprint hash"""
        import hashlib
        
        fingerprint_string = f"{device_id}:{device_type}:{os_type}:{os_version}:{app_version}:{user_agent}:{ip_address}"
        fingerprint_hash = hashlib.sha256(fingerprint_string.encode()).hexdigest()
        
        return fingerprint_hash
    
    @staticmethod
    def verify_fingerprint(
        current_fingerprint: str,
        stored_fingerprint: str,
        tolerance: int = 2
    ) -> bool:
        """Verify device fingerprint (allows minor changes)"""
        # Simple check - in production, use more sophisticated methods
        return current_fingerprint == stored_fingerprint

# ============================================================================
# ENCRYPTION UTILITIES
# ============================================================================

class EncryptionManager:
    """Handle sensitive data encryption"""
    
    from cryptography.fernet import Fernet
    
    @staticmethod
    def encrypt_field(value: str, key: str = settings.SECRET_KEY) -> str:
        """Encrypt sensitive field"""
        f = Fernet(key.encode()[:32].ljust(32, b'0'))
        return f.encrypt(value.encode()).decode()
    
    @staticmethod
    def decrypt_field(encrypted_value: str, key: str = settings.SECRET_KEY) -> str:
        """Decrypt sensitive field"""
        f = Fernet(key.encode()[:32].ljust(32, b'0'))
        return f.decrypt(encrypted_value.encode()).decode()

# ============================================================================
# PERMISSION CHECKS
# ============================================================================

ROLE_PERMISSIONS = {
    "SUPER_ADMIN": [
        "manage_all_organizations",
        "manage_all_users",
        "manage_payroll",
        "view_all_analytics",
        "manage_system_settings",
        "view_audit_logs"
    ],
    "ADMIN": [
        "manage_users",
        "manage_payroll",
        "view_analytics",
        "manage_settings",
        "view_audit_logs",
        "manage_departments"
    ],
    "HR_MANAGER": [
        "manage_users",
        "manage_payroll",
        "view_analytics",
        "manage_departments",
        "approve_attendance",
        "manage_leave"
    ],
    "MANAGER": [
        "view_team_analytics",
        "approve_team_attendance",
        "manage_team",
        "view_team_data"
    ],
    "EMPLOYEE": [
        "view_own_data",
        "clock_in_out",
        "view_own_analytics",
        "request_leave",
        "view_payslip"
    ]
}

def has_permission(role: str, permission: str) -> bool:
    """Check if role has permission"""
    permissions = ROLE_PERMISSIONS.get(role, [])
    return permission in permissions

def get_role_permissions(role: str) -> list:
    """Get all permissions for a role"""
    return ROLE_PERMISSIONS.get(role, [])

# ============================================================================
# RATE LIMITING KEY GENERATION
# ============================================================================

def get_rate_limit_key(user_id: str, endpoint: str) -> str:
    """Generate rate limit key"""
    return f"ratelimit:{user_id}:{endpoint}"

def get_ip_rate_limit_key(ip_address: str, endpoint: str) -> str:
    """Generate IP-based rate limit key"""
    return f"ratelimit:ip:{ip_address}:{endpoint}"
