# backend/core/security.py - Security utilities and authentication

from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from pydantic import BaseModel
import logging
import uuid
import bcrypt
from functools import lru_cache

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# PASSWORD HASHING
# ============================================================================

def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    salt = bcrypt.gensalt(rounds=12)
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
# JWT TOKENS
# ============================================================================

class TokenPayload(BaseModel):
    """JWT token payload"""
    sub: str  # Subject (user ID)
    type: str  # Token type: 'access' or 'refresh'
    org_id: str  # Organization ID
    role: str  # User role
    permissions: list = []
    exp: Optional[datetime] = None

def create_access_token(
    user_id: str,
    org_id: str,
    role: str,
    permissions: list = [],
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token"""
    
    if expires_delta is None:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    expire = datetime.utcnow() + expires_delta
    
    payload = {
        "sub": user_id,
        "type": "access",
        "org_id": org_id,
        "role": role,
        "permissions": permissions,
        "exp": expire,
        "iat": datetime.utcnow()
    }
    
    encoded_jwt = jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return encoded_jwt

def create_refresh_token(
    user_id: str,
    org_id: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT refresh token"""
    
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    expire = datetime.utcnow() + expires_delta
    
    payload = {
        "sub": user_id,
        "type": "refresh",
        "org_id": org_id,
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": str(uuid.uuid4())  # Token ID for revocation
    }
    
    encoded_jwt = jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return encoded_jwt

def verify_token(token: str) -> Optional[TokenPayload]:
    """Verify and decode JWT token"""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        if user_id is None or token_type is None:
            logger.warning("Invalid token payload")
            return None
        
        return TokenPayload(**payload)
    
    except JWTError as e:
        logger.warning(f"JWT verification failed: {e}")
        return None
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        return None

def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode JWT token and return payload"""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except:
        return None

def create_tokens(
    user_id: str,
    org_id: str,
    role: str,
    permissions: list = []
) -> Dict[str, str]:
    """Create both access and refresh tokens"""
    
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
        self.token_blacklist: set = set()  # In production, use Redis
    
    def hash_password(self, password: str) -> str:
        """Hash password"""
        return hash_password(password)
    
    def verify_password(self, plain: str, hashed: str) -> bool:
        """Verify password"""
        return verify_password(plain, hashed)
    
    def create_tokens(
        self,
        user_id: str,
        org_id: str,
        role: str,
        permissions: list = []
    ) -> Dict[str, str]:
        """Create JWT tokens"""
        return create_tokens(user_id, org_id, role, permissions)
    
    def verify_token(self, token: str) -> Optional[TokenPayload]:
        """Verify JWT token"""
        return verify_token(token)
    
    def is_token_blacklisted(self, token_id: str) -> bool:
        """Check if token is blacklisted"""
        return token_id in self.token_blacklist
    
    def blacklist_token(self, token_id: str):
        """Add token to blacklist"""
        self.token_blacklist.add(token_id)
    
    @staticmethod
    def generate_reset_token() -> str:
        """Generate password reset token"""
        return str(uuid.uuid4())
    
    @staticmethod
    def generate_verification_token() -> str:
        """Generate email verification token"""
        return str(uuid.uuid4())

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
