# backend/services/cache.py - Redis Cache Manager

import redis
import json
import logging
from typing import Any, Optional
from core.config import settings

logger = logging.getLogger(__name__)

class RedisManager:
    """Redis cache management"""
    
    def __init__(self):
        self.redis_client = None
    
    async def connect(self):
        """Connect to Redis"""
        try:
            self.redis_client = redis.from_url(settings.REDIS_URL)
            self.redis_client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.error(f"Redis connection failed: {e}")
            raise
    
    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis_client:
            self.redis_client.close()
            logger.info("Redis connection closed")
    
    async def set(self, key: str, value: Any, ttl: int = None):
        """Set cache value"""
        try:
            if ttl is None:
                ttl = settings.REDIS_CACHE_TTL
            self.redis_client.setex(key, ttl, json.dumps(value))
        except Exception as e:
            logger.error(f"Cache set error: {e}")
    
    async def get(self, key: str) -> Optional[Any]:
        """Get cache value"""
        try:
            value = self.redis_client.get(key)
            return json.loads(value) if value else None
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    async def delete(self, key: str):
        """Delete cache value"""
        try:
            self.redis_client.delete(key)
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
    
    async def ping(self):
        """Ping Redis"""
        if not self.redis_client:
            raise RuntimeError("Redis client not connected")
        return self.redis_client.ping()

# Global instance
redis_manager = None

async def get_redis() -> RedisManager:
    """Get Redis manager instance"""
    global redis_manager
    if not redis_manager:
        redis_manager = RedisManager()
        try:
            await redis_manager.connect()
        except Exception:
            # Provide a no-op fallback so callers can continue without raising
            class DummyRedisManager:
                async def connect(self):
                    return

                async def disconnect(self):
                    return

                async def set(self, key: str, value: Any, ttl: int = None):
                    return

                async def get(self, key: str) -> Optional[Any]:
                    return None

                async def delete(self, key: str):
                    return

                async def ping(self):
                    raise RuntimeError("Redis not available")

            redis_manager = DummyRedisManager()
    return redis_manager
