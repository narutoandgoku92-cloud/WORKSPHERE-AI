
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import logging
from datetime import datetime

from core.config import settings
from core.database import get_db, init_db, check_db_health
from core.security import SecurityManager
from api.v1.routes import (
    auth,
    users,
    employees,
    attendance,
    face_recognition,
    gps,
    analytics,
    payroll,
    admin,
)
from services.cache import RedisManager
from services.cache import get_redis
from middleware.auth import JWTMiddleware
from middleware.error_handler import error_handler
from middleware.logging import LoggingMiddleware

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting OptiWork AI Backend...")

    if settings.DEBUG or settings.AUTO_INIT_DB:
        try:
            init_db()
            logger.info("Database initialized successfully")
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise
    else:
        logger.info(
            "Database initialization skipped. "
            "Use Alembic migrations for schema management."
        )

    try:
        redis_manager = await get_redis()
        app.state.redis_manager = redis_manager
        logger.info("Redis connection established (or dummy fallback in use)")
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}")
        app.state.redis_manager = None

    security_manager = SecurityManager()
    app.state.security_manager = security_manager
    logger.info("Security manager initialized")

    yield

    logger.info("Shutting down OptiWork AI Backend...")

    if getattr(app.state, "redis_manager", None):
        try:
            await app.state.redis_manager.disconnect()
            logger.info("Redis connection closed")
        except Exception:
            logger.exception("Error while closing Redis connection")


def create_app() -> FastAPI:
    app = FastAPI(
        title="OptiWork AI",
        description="Production-grade AI workforce management platform",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    # Trusted host configuration
    if settings.ALLOWED_HOSTS:
        if "*" in settings.ALLOWED_HOSTS:
            logger.warning(
                "ALLOWED_HOSTS contains '*' — "
                "skipping TrustedHostMiddleware (allowing all hosts)"
            )
        else:
            app.add_middleware(
                TrustedHostMiddleware,
                allowed_hosts=settings.ALLOWED_HOSTS,
            )

    # CORS configuration
    # In development, allow Flutter Web's dynamically assigned localhost port.
    # In production/staging, only the configured CORS_ORIGINS are allowed.
    is_development = settings.ENVIRONMENT == "development"

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_origin_regex=(
            r"^http://(localhost|127\.0\.0\.1):\d+$"
            if is_development
            else None
        ),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=[
            "X-RateLimit-Limit",
            "X-RateLimit-Remaining",
            "X-RateLimit-Reset",
        ],
    )

    # Application middleware
    app.add_middleware(LoggingMiddleware)
    app.add_middleware(JWTMiddleware)

    @app.exception_handler(Exception)
    async def global_exception_handler(
        request: Request,
        exc: Exception,
    ):
        return await error_handler(request, exc)

    # Health endpoints
    @app.get("/health", tags=["System"])
    async def health_check():
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }

    @app.get("/health/live", tags=["System"])
    async def live_check():
        return {"status": "alive"}

    @app.get("/health/ready", tags=["System"])
    async def ready_check():
        if not check_db_health():
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "not_ready",
                    "error": "Database unavailable",
                },
            )

        redis_manager = getattr(app.state, "redis_manager", None)

        if redis_manager:
            try:
                await redis_manager.ping()
            except Exception as e:
                return JSONResponse(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    content={
                        "status": "not_ready",
                        "error": f"Redis unavailable: {e}",
                    },
                )

        return {"status": "ready"}

    @app.get("/metrics", tags=["System"])
    async def metrics():
        return {"message": "Metrics endpoint coming soon"}

    # API routes
    app.include_router(
        auth.router,
        prefix="/api/v1/auth",
        tags=["Authentication"],
    )
    app.include_router(
        users.router,
        prefix="/api/v1/users",
        tags=["Users"],
    )
    app.include_router(
        employees.router,
        prefix="/api/v1",
        tags=["Employees"],
    )
    app.include_router(
        attendance.router,
        prefix="/api/v1/attendance",
        tags=["Attendance"],
    )
    app.include_router(
        face_recognition.router,
        prefix="/api/v1/face-recognition",
        tags=["Face Recognition"],
    )
    app.include_router(
        gps.router,
        prefix="/api/v1/gps",
        tags=["GPS"],
    )
    app.include_router(
        analytics.router,
        prefix="/api/v1/analytics",
        tags=["Analytics"],
    )
    app.include_router(
        payroll.router,
        prefix="/api/v1/payroll",
        tags=["Payroll"],
    )
    app.include_router(
        admin.router,
        prefix="/api/v1/admin",
        tags=["Admin"],
    )

    # Root endpoint
    @app.get("/", tags=["System"])
    async def root():
        return {
            "name": "OptiWork AI",
            "version": "1.0.0",
            "description": "Production-grade AI workforce management platform",
            "docs": "/docs",
            "api_version": "v1",
            "status": "operational",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="info",
    )
