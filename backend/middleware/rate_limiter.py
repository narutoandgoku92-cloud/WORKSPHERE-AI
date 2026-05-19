# CRITICAL FIX #2: Rate Limiting & Brute Force Protection
# backend/middleware/rate_limiter.py - Production-grade rate limiting

from redis import Redis
from datetime import datetime, timedelta
from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)

class RateLimiter:
    """Production-grade rate limiter using Redis"""
    
    def __init__(self, redis_url: str):
        self.redis = Redis.from_url(redis_url, decode_responses=True)
    
    def check_limit(
        self,
        key: str,
        max_attempts: int,
        window_seconds: int
    ) -> Tuple[bool, int, Optional[datetime]]:
        """
        Check if request is within rate limit
        
        Returns: (allowed: bool, remaining: int, reset_time: datetime)
        """
        try:
            current = int(self.redis.get(key) or 0)
            
            if current == 0:
                # First request in window
                self.redis.setex(key, window_seconds, 1)
                ttl = window_seconds
            else:
                # Increment counter
                current += 1
                self.redis.incr(key)
                ttl = self.redis.ttl(key)
            
            allowed = current <= max_attempts
            remaining = max(0, max_attempts - current)
            reset_time = datetime.utcnow() + timedelta(seconds=ttl) if ttl > 0 else None
            
            return (allowed, remaining, reset_time)
        
        except Exception as e:
            logger.error(f"Rate limit check error: {e}")
            return (False, 0, None)  # Fail secure

class LoginAttemptTracker:
    """Track failed login attempts and lock accounts"""
    
    def __init__(self, redis_url: str, max_attempts: int = 5, lockout_seconds: int = 3600):
        self.redis = Redis.from_url(redis_url, decode_responses=True, socket_timeout=5)
        self.max_attempts = max_attempts
        self.lockout_duration = lockout_seconds
    
    def record_failed_attempt(self, email: str, ip: str):
        """Record failed login attempt"""
        email_key = f"login_fail:email:{email}"
        ip_key = f"login_fail:ip:{ip}"
        
        try:
            self.redis.incr(email_key)
            self.redis.expire(email_key, 3600)
            
            self.redis.incr(ip_key)
            self.redis.expire(ip_key, 3600)
            
            failed_count = int(self.redis.get(email_key) or 0)
            logger.warning(f"Failed login for {email}: attempt {failed_count}")
            
            # Lock account after max attempts
            if failed_count >= self.max_attempts:
                self.lock_account(email)
        
        except Exception as e:
            logger.error(f"Failed to record login attempt: {e}")
    
    def record_successful_login(self, email: str):
        """Clear failed attempts on successful login"""
        email_key = f"login_fail:email:{email}"
        lock_key = f"account_lock:{email}"
        
        try:
            self.redis.delete(email_key)
            self.redis.delete(lock_key)
            logger.info(f"Login successful for {email}, cleared failed attempts")
        except Exception as e:
            logger.error(f"Failed to clear login attempts: {e}")
    
    def is_account_locked(self, email: str) -> bool:
        """Check if account is locked"""
        lock_key = f"account_lock:{email}"
        
        try:
            return self.redis.exists(lock_key) > 0
        except Exception as e:
            logger.error(f"Failed to check account lock: {e}")
            return False
    
    def lock_account(self, email: str):
        """Lock account temporarily"""
        lock_key = f"account_lock:{email}"
        
        try:
            self.redis.setex(lock_key, self.lockout_duration, "1")
            logger.warning(f"Account {email} locked for {self.lockout_duration}s")
        except Exception as e:
            logger.error(f"Failed to lock account: {e}")
    
    def get_failed_attempts(self, email: str) -> int:
        """Get number of failed attempts"""
        email_key = f"login_fail:email:{email}"
        
        try:
            return int(self.redis.get(email_key) or 0)
        except Exception as e:
            logger.error(f"Failed to get failed attempts: {e}")
            return 0
    
    def get_lockout_remaining(self, email: str) -> int:
        """Get seconds until account unlock"""
        lock_key = f"account_lock:{email}"
        
        try:
            ttl = self.redis.ttl(lock_key)
            return max(0, ttl)
        except Exception as e:
            logger.error(f"Failed to get lockout remaining: {e}")
            return 0
