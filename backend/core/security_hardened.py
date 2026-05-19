# CRITICAL FIX #1: Authentication & JWT Security Module
# backend/core/security_hardened.py - Production-ready security

import os
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from pydantic import BaseModel
import logging
import uuid
import bcrypt
from redis import Redis

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# REDIS CONNECTION FOR TOKEN BLACKLIST
# ============================================================================

class TokenBlacklist:
    """Redis-based token revocation/blacklist"""
    
    def __init__(self, redis_url: str):
        self.redis = Redis.from_url(redis_url, decode_responses=True)
    
    async def add_to_blacklist(self, jti: str, ttl: int):
        """Add token JTI to blacklist"""
        try:
            await self.redis.setex(f"blacklist:{jti}", ttl, "1")
            logger.info(f"Token {jti} added to blacklist, TTL: {ttl}s")
        except Exception as e:
            logger.error(f"Failed to add token to blacklist: {e}")
            raise
    
    async def is_blacklisted(self, jti: str) -> bool:
        """Check if token is blacklisted"""
        try:
            return await self.redis.exists(f"blacklist:{jti}") > 0
        except Exception as e:
            logger.error(f"Blacklist check error: {e}")
            return False  # If Redis fails, be permissive

# ============================================================================
# VALIDATE CONFIGURATION
# ============================================================================

def validate_security_config():
    """Validate security configuration for production"""
    
    if os.getenv("ENVIRONMENT") == "production":
        secret_key = os.getenv("SECRET_KEY")
        
        # Must be set
        if not secret_key:
            raise RuntimeError("❌ CRITICAL: SECRET_KEY not set in production!")
        
        # Must be strong
        if secret_key == "your-secret-key-change-in-production":
            raise RuntimeError("❌ CRITICAL: Using default secret key in production!")
        
        # Must be long enough
        if len(secret_key) < 32:
            raise RuntimeError(
                f"❌ CRITICAL: SECRET_KEY too short ({len(secret_key)} chars). "
                f"Minimum 32 characters required."
            )
        
        logger.info("✅ Security configuration validated")

# ============================================================================
# PASSWORD SECURITY
# ============================================================================

def hash_password(password: str, rounds: int = 12) -> str:
    """Hash password using bcrypt with strong rounds"""
    
    # Validate password strength
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    
    if not any(c.isupper() for c in password):
        raise ValueError("Password must contain uppercase letter")
    
    if not any(c.isdigit() for c in password):
        raise ValueError("Password must contain digit")
    
    if not any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password):
        raise ValueError("Password must contain special character")
    
    salt = bcrypt.gensalt(rounds=rounds)
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash safely"""
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
    """Validated JWT payload"""
    sub: str  # User ID
    type: str  # 'access' or 'refresh'
    jti: str  # JWT ID for revocation
    org_id: str  # Organization ID
    role: str  # User role
    permissions: list = []
    iat: Optional[int] = None  # Issued at
    exp: Optional[int] = None  # Expiration

def create_access_token(
    user_id: str,
    org_id: str,
    role: str,
    permissions: list = [],
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token with security features"""
    
    if not expires_delta:
        expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    expire = datetime.utcnow() + expires_delta
    
    payload = {
        "sub": user_id,
        "type": "access",
        "jti": str(uuid.uuid4()),  # Unique token ID for revocation
        "org_id": org_id,
        "role": role,
        "permissions": permissions,
        "iat": datetime.utcnow().timestamp(),
        "exp": expire.timestamp()
    }
    
    encoded_jwt = jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    logger.debug(f"Access token created for user {user_id}")
    return encoded_jwt

def create_refresh_token(
    user_id: str,
    org_id: str,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT refresh token with security features"""
    
    if not expires_delta:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    expire = datetime.utcnow() + expires_delta
    
    payload = {
        "sub": user_id,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
        "org_id": org_id,
        "iat": datetime.utcnow().timestamp(),
        "exp": expire.timestamp()
    }
    
    encoded_jwt = jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    logger.debug(f"Refresh token created for user {user_id}")
    return encoded_jwt

def verify_token(token: str) -> Optional[TokenPayload]:
    """Verify and decode JWT token"""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        
        # Validate required fields
        required_fields = ["sub", "type", "jti"]
        for field in required_fields:
            if field not in payload:
                logger.warning(f"Missing required field in token: {field}")
                return None
        
        return TokenPayload(**payload)
    
    except JWTError as e:
        logger.warning(f"JWT verification failed: {e}")
        return None
    except Exception as e:
        logger.error(f"Token verification error: {e}")
        return None

def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode JWT token and return raw payload"""
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
    
    access_token = create_access_token(user_id, org_id, role, permissions)
    refresh_token = create_refresh_token(user_id, org_id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }

# ============================================================================
# DEVICE FINGERPRINTING FOR EXTRA SECURITY
# ============================================================================

def generate_device_fingerprint(
    device_id: str,
    user_agent: str,
    ip_address: str
) -> str:
    """Generate secure device fingerprint"""
    import hashlib
    
    fingerprint_data = f"{device_id}:{user_agent}:{ip_address}"
    return hashlib.sha256(fingerprint_data.encode()).hexdigest()

# ============================================================================
# INITIALIZE SECURITY ON APP STARTUP
# ============================================================================

def init_security():
    """Initialize security systems"""
    logger.info("Initializing security systems...")
    
    validate_security_config()
    
    logger.info("✅ Security systems initialized")
