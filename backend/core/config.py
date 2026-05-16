# backend/core/config.py - Application configuration
from pydantic_settings import BaseSettings
from typing import List
from pathlib import Path
import os 
from functools import lru_cache

BASE_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = BASE_DIR / ".env"

class Settings(BaseSettings):
    """Application settings with environment variable support"""
    
    # ========================================================================
    # ENVIRONMENT
    # ========================================================================
    
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    
    # ========================================================================
    # API CONFIGURATION
    # ========================================================================
    
    API_TITLE: str = "OptiWork AI"
    API_VERSION: str = "1.0.0"
    API_PREFIX: str = "/api/v1"
    
    # ========================================================================
    # DATABASE
    # ========================================================================
    
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "sqlite:///./work_sphere_ai.db"
    )
    
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
    
    SECRET_KEY: str = os.getenv(
        "SECRET_KEY",
        "your-secret-key-change-in-production"
    )
    
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
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
    # AI/ML CONFIGURATION
    # ========================================================================
    
    # Face Recognition
    FACE_RECOGNITION_MODEL: str = "insightface_r100"
    FACE_EMBEDDING_DIM: int = 512
    FACE_MATCH_THRESHOLD: float = float(os.getenv("FACE_MATCH_THRESHOLD", "0.6"))
    FACE_LIVENESS_THRESHOLD: float = float(os.getenv("FACE_LIVENESS_THRESHOLD", "0.7"))
    FACE_QUALITY_MIN_SCORE: float = float(os.getenv("FACE_QUALITY_MIN_SCORE", "0.7"))
    
    # GPU Configuration
    USE_GPU: bool = os.getenv("USE_GPU", "true").lower() == "true"
    CUDA_DEVICE_ID: int = int(os.getenv("CUDA_DEVICE_ID", "0"))
    
    # Model paths
    MODELS_PATH: str = os.getenv("MODELS_PATH", "./models")
    FACE_DETECTION_MODEL: str = os.path.join(MODELS_PATH, "retina_face.onnx")
    FACE_EMBEDDING_MODEL: str = os.path.join(MODELS_PATH, "insightface_r100.onnx")
    LIVENESS_MODEL: str = os.path.join(MODELS_PATH, "liveness_detector.onnx")
    
    # ========================================================================
    # SECURITY SETTINGS
    # ========================================================================
    
    ALLOWED_HOSTS: List[str] = [
        "*"
    ]
    
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:19006",  # Flutter web
        "http://127.0.0.1:3000",
        "https://optiwork.ai",
        "https://app.optiwork.ai",
        "http://10.0.2.2:8000",  # Android emulator
        "http://localhost:8000",  # iOS simulator
    ]
    
    # Rate limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_DEFAULT: str = "1000/hour"
    RATE_LIMIT_AUTH: str = "10/minute"
    
    # ========================================================================
    # GEOFENCING
    # ========================================================================
    
    GEOFENCE_DEFAULT_RADIUS_METERS: int = 100
    GPS_ACCURACY_THRESHOLD: float = 100.0  # meters
    GPS_UPDATE_INTERVAL: int = 60  # seconds
    
    # ========================================================================
    # PAYROLL CONFIGURATION
    # ========================================================================
    
    PAYROLL_DEFAULT_CURRENCY: str = "USD"
    PAYROLL_TAX_PERCENTAGE: float = 0.15
    OVERTIME_MULTIPLIER: float = 1.5
    
    # ========================================================================
    # FILE UPLOAD
    # ========================================================================
    
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_IMAGE_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]
    ALLOWED_DOCUMENT_TYPES: List[str] = ["application/pdf", "application/msword"]
    
    # ========================================================================
    # STRIPE CONFIGURATION
    # ========================================================================
    
    STRIPE_SECRET_KEY: str = os.getenv("STRIPE_SECRET_KEY", "")
    STRIPE_PUBLIC_KEY: str = os.getenv("STRIPE_PUBLIC_KEY", "")
    STRIPE_WEBHOOK_SECRET: str = os.getenv("STRIPE_WEBHOOK_SECRET", "")

    # ========================================================================
    # SQUAD PAYMENT INTEGRATION
    # ========================================================================

    SQUAD_API_BASE_URL: str = os.getenv("SQUAD_API_BASE_URL", "https://api.squad.co")
    SQUAD_API_KEY: str = os.getenv("SQUAD_API_KEY", "")
    SQUAD_API_SECRET: str = os.getenv("SQUAD_API_SECRET", "")
    SQUAD_PAYOUT_PATH: str = os.getenv("SQUAD_PAYOUT_PATH", "/v1/transfers")
    SQUAD_REQUEST_TIMEOUT: int = int(os.getenv("SQUAD_REQUEST_TIMEOUT", "30"))
    SQUAD_RETRY_LIMIT: int = int(os.getenv("SQUAD_RETRY_LIMIT", "3"))
    SQUAD_RETRY_BACKOFF_SECONDS: int = int(os.getenv("SQUAD_RETRY_BACKOFF_SECONDS", "2"))
    
    # ========================================================================
    # LOGGING
    # ========================================================================
    
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # ========================================================================
    # PAGINATION
    # ========================================================================
    
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100
    
    # ========================================================================
    # TASK QUEUE
    # ========================================================================
    
    CELERY_BROKER_URL: str = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/1")
    CELERY_RESULT_BACKEND: str = os.getenv("CELERY_RESULT_BACKEND", "redis://localhost:6379/2")
    
    class Config:
        env_file = str(ENV_FILE)
        env_file_encoding = "utf-8"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    """Get settings instance (cached)"""
    return Settings()

# Export settings instance
settings = get_settings()
