# backend/core/config.py - Application configuration
import json
import os
from functools import lru_cache
from typing import List, Any

from pydantic import BaseModel, Field, field_validator, model_validator
from pydantic_settings import BaseSettings


def _parse_host_list(value: Any) -> List[str]:
    if value is None:
        return []

    if isinstance(value, list):
        return [str(item).strip() for item in value if item]

    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return []

        if raw.startswith("[") and raw.endswith("]"):
            try:
                parsed = json.loads(raw)
                return [str(item).strip() for item in parsed if item]
            except json.JSONDecodeError:
                pass

        return [item.strip() for item in raw.split(",") if item.strip()]

    return [str(value).strip()]


class Settings(BaseSettings):
    """Application settings with explicit environment validation"""

    # ========================================================================
    # ENVIRONMENT
    # ========================================================================
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development").lower()
    AUTO_INIT_DB: bool = os.getenv("AUTO_INIT_DB", "false").lower() == "true"

    # ========================================================================
    # API CONFIGURATION
    # ========================================================================
    API_TITLE: str = "OptiWork AI"
    API_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"

    # ========================================================================
    # DATABASE
    # ========================================================================
    DATABASE_URL: str = Field(default="")
    DATABASE_ECHO: bool = os.getenv("DATABASE_ECHO", "false").lower() == "true"
    DATABASE_POOL_SIZE: int = int(os.getenv("DATABASE_POOL_SIZE", "20"))
    DATABASE_MAX_OVERFLOW: int = int(os.getenv("DATABASE_MAX_OVERFLOW", "10"))
    DATABASE_POOL_TIMEOUT: int = int(os.getenv("DATABASE_POOL_TIMEOUT", "30"))

    # ========================================================================
    # REDIS CACHE
    # ========================================================================
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    REDIS_CACHE_TTL: int = int(os.getenv("REDIS_CACHE_TTL", "3600"))

    # ========================================================================
    # JWT SECURITY
    # ========================================================================
    SECRET_KEY: str = Field(default="")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

    # ========================================================================
    # LOGGING
    # ========================================================================
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    # ========================================================================
    # SECURITY SETTINGS
    # ========================================================================
    ALLOWED_HOSTS: str | List[str] = Field(default_factory=list)
    CORS_ORIGINS: str | List[str] = Field(default_factory=list)

    RATE_LIMIT_ENABLED: bool = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
    RATE_LIMIT_AUTH_PER_MINUTE: int = int(os.getenv("RATE_LIMIT_AUTH_PER_MINUTE", "30"))
    RATE_LIMIT_PUBLIC_PER_MINUTE: int = int(os.getenv("RATE_LIMIT_PUBLIC_PER_MINUTE", "120"))
    LOGIN_MAX_FAILED_ATTEMPTS: int = int(os.getenv("LOGIN_MAX_FAILED_ATTEMPTS", "5"))
    LOGIN_LOCKOUT_SECONDS: int = int(os.getenv("LOGIN_LOCKOUT_SECONDS", "3600"))

    # ========================================================================
    # AWS CONFIGURATION
    # ========================================================================
    AWS_REGION: str = os.getenv("AWS_REGION", "us-east-1")
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    AWS_S3_BUCKET: str = os.getenv("AWS_S3_BUCKET", "optiwork-uploads")
    AWS_S3_DOMAIN: str = os.getenv("AWS_S3_DOMAIN", "s3.amazonaws.com")

    # ========================================================================
    # EMAIL CONFIGURATION
    # ========================================================================
    SMTP_SERVER: str = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL: str = os.getenv("SMTP_FROM_EMAIL", "noreply@optiwork.ai")
    SMTP_FROM_NAME: str = "OptiWork AI"

    # ========================================================================
    # FACE RECOGNITION
    # ========================================================================
    USE_GPU: bool = Field(default=False, env="USE_GPU")
    FACE_MATCH_THRESHOLD: float = Field(default=0.5, env="FACE_MATCH_THRESHOLD")
    FACE_LIVENESS_THRESHOLD: float = Field(default=0.7, env="FACE_LIVENESS_THRESHOLD")
    FACE_QUALITY_MIN_SCORE: float = Field(default=0.55, env="FACE_QUALITY_MIN_SCORE")

    # ========================================================================
    # OTHER CONFIGURATION
    # ========================================================================
    SENTRY_DSN: str = os.getenv("SENTRY_DSN", "")

    class Config:
        env_file = ".env"
        case_sensitive = True

    @field_validator("ALLOWED_HOSTS", "CORS_ORIGINS", mode="before")
    @classmethod
    def _normalize_list(cls, value):
        return _parse_host_list(value)

    @model_validator(mode="after")
    def validate_environment(self):
        environment = self.ENVIRONMENT

        if environment in ("production", "staging"):
            if not self.SECRET_KEY:
                raise ValueError("SECRET_KEY must be provided for production or staging environments")
            if not self.DATABASE_URL:
                raise ValueError("DATABASE_URL must be provided for production or staging environments")
            if self.DATABASE_URL.startswith("sqlite"):
                raise ValueError("SQLite DATABASE_URL is not allowed in production or staging")
            if not self.ALLOWED_HOSTS:
                raise ValueError("ALLOWED_HOSTS must be provided for production or staging environments")
            if not self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS must be provided for production or staging environments")
        else:
            if not self.DATABASE_URL:
                object.__setattr__(self, "DATABASE_URL", "sqlite:///./work_sphere_ai.db")
            if not self.SECRET_KEY:
                object.__setattr__(self, "SECRET_KEY", "dev-secret-key-change-me")
            if not self.ALLOWED_HOSTS:
                object.__setattr__(self, "ALLOWED_HOSTS", ["localhost", "127.0.0.1"])
            if not self.CORS_ORIGINS:
                object.__setattr__(
                    self,
                    "CORS_ORIGINS",
                    [
                        "http://localhost:3000",
                        "http://127.0.0.1:3000",
                        "http://10.0.2.2:8000",
                        "http://localhost:8000"
                    ]
                )

        return self


@lru_cache()
def get_settings() -> Settings:
    """Get settings instance (cached)"""
    return Settings()


# Export settings instance
settings = get_settings()
