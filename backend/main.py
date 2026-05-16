# backend/main.py - OptiWork AI FastAPI Backend
# Entry point and application initialization

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
from typing import Optional
import logging
from datetime import datetime

from core.config import settings
from core.database import engine, get_db, init_db
from core.security import SecurityManager
from api.v1.routes import auth, users, attendance, face_recognition, gps, analytics, payroll, admin
from services.cache import RedisManager
from middleware.auth import JWTMiddleware
from middleware.error_handler import error_handler
from middleware.logging import LoggingMiddleware

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# LIFESPAN EVENTS
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    # Startup
    logger.info("Starting OptiWork AI Backend...")
    
    try:
        # Initialize database (create tables if not exists)
        from core.database import init_db
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        raise
    
    # Initialize Redis
    try:
        redis_manager = RedisManager()
        await redis_manager.connect()
        logger.info("Redis connection established")
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}")
    
    # Initialize security manager
    security_manager = SecurityManager()
    logger.info("Security manager initialized")
    
    yield
    
    # Shutdown
    logger.info("Shutting down OptiWork AI Backend...")
    try:
        await redis_manager.disconnect()
        logger.info("Redis connection closed")
    except:
        pass

# ============================================================================
# APPLICATION FACTORY
# ============================================================================

def create_app() -> FastAPI:
    """Create and configure FastAPI application"""
    
    app = FastAPI(
        title="OptiWork AI",
        description="Production-grade AI workforce management platform",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan
    )
    
    # ========================================================================
    # MIDDLEWARE
    # ========================================================================
    
    # Trust host middleware for AWS load balancers
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.ALLOWED_HOSTS
    )
    
    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"]
    )
    
    # Custom middleware
    app.add_middleware(LoggingMiddleware)
    app.add_middleware(JWTMiddleware)
    
    # ========================================================================
    # ERROR HANDLERS
    # ========================================================================
    
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        return await error_handler(request, exc)
    
    # ========================================================================
    # HEALTH CHECK ENDPOINTS
    # ========================================================================
    
    @app.get("/health", tags=["System"])
    async def health_check():
        """System health check endpoint"""
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "1.0.0"
        }
    
    @app.get("/health/live", tags=["System"])
    async def live_check():
        """Kubernetes liveness probe"""
        return {"status": "alive"}
    
    @app.get("/health/ready", tags=["System"])
    async def ready_check(db=None):
        """Kubernetes readiness probe"""
        try:
            # Check database
            db = next(get_db())
            db.execute("SELECT 1")
            
            # Check cache
            redis_manager = RedisManager()
            await redis_manager.ping()
            
            return {"status": "ready"}
        except Exception as e:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "error": str(e)}
            )
    
    @app.get("/metrics", tags=["System"])
    async def metrics():
        """Prometheus metrics endpoint"""
        # TODO: Implement Prometheus metrics collection
        return {"message": "Metrics endpoint coming soon"}
    
    # ========================================================================
    # API ROUTES
    # ========================================================================
    
    # V1 API routes
    app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
    app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
    app.include_router(attendance.router, prefix="/api/v1/attendance", tags=["Attendance"])
    app.include_router(face_recognition.router, prefix="/api/v1/face-recognition", tags=["Face Recognition"])
    app.include_router(gps.router, prefix="/api/v1/gps", tags=["GPS"])
    app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
    app.include_router(payroll.router, prefix="/api/v1/payroll", tags=["Payroll"])
    app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin"])
    
    # ========================================================================
    # ROOT ENDPOINT
    # ========================================================================
    
    @app.get("/", tags=["System"])
    async def root():
        """API information"""
        return {
            "name": "OptiWork AI",
            "version": "1.0.0",
            "description": "Production-grade AI workforce management platform",
            "docs": "/api/docs",
            "api_version": "v1",
            "status": "operational"
        }
    
    return app

# ============================================================================
# APPLICATION INSTANCE
# ============================================================================

app = create_app()

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )
