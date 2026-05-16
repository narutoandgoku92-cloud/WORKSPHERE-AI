# backend/core/database.py - Database setup and session management

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from sqlalchemy.pool import QueuePool
from typing import Generator
import logging

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

# Determine if using SQLite
is_sqlite = "sqlite" in settings.DATABASE_URL.lower()

# Create engine with connection pooling
if is_sqlite:
    # SQLite doesn't support connection pooling or these options
    engine = create_engine(
        settings.DATABASE_URL,
        echo=settings.DATABASE_ECHO,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True
    )
else:
    # PostgreSQL configuration
    engine = create_engine(
        settings.DATABASE_URL,
        echo=settings.DATABASE_ECHO,
        poolclass=QueuePool,
        pool_size=settings.DATABASE_POOL_SIZE,
        max_overflow=settings.DATABASE_MAX_OVERFLOW,
        pool_timeout=settings.DATABASE_POOL_TIMEOUT,
        pool_pre_ping=True,  # Test connections before using them
        connect_args={
            "connect_timeout": 10,
            "options": "-c statement_timeout=30000"
        }
    )

# Session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base class for all models
Base = declarative_base()

# ============================================================================
# DATABASE EVENTS
# ============================================================================

@event.listens_for(engine, "connect")
def receive_connect(dbapi_conn, connection_record):
    """Enable foreign keys on SQLite"""
    if "sqlite" in settings.DATABASE_URL.lower():
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

# Commented out invalid event listener for SQLAlchemy 2.0 compatibility
# @event.listens_for(engine, "pool_connect")
# def receive_pool_connect(dbapi_conn, connection_record):
#     """Log pool connections in debug mode"""
#     if settings.DEBUG:
#         logger.debug("Database pool connection established")

# ============================================================================
# DEPENDENCY INJECTION
# ============================================================================

def get_db() -> Generator[Session, None, None]:
    """Get database session dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ============================================================================
# DATABASE INITIALIZATION
# ============================================================================

def init_db():
    """Initialize database tables and extensions"""
    try:
        # Create all tables
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
        
        # Enable PostgreSQL extensions if using PostgreSQL
        if "postgresql" in settings.DATABASE_URL.lower():
            from sqlalchemy import text
            with engine.connect() as conn:
                conn.execute(text("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"))
                conn.execute(text("CREATE EXTENSION IF NOT EXISTS \"pgvector\";"))
                conn.execute(text("CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"))
                conn.commit()
                logger.info("PostgreSQL extensions created successfully")
    except Exception as e:
        logger.error(f"Database initialization error: {e}")
        raise

def drop_db():
    """Drop all database tables (use with caution)"""
    Base.metadata.drop_all(bind=engine)
    logger.warning("All database tables dropped")

def truncate_db():
    """Truncate all tables (use with caution)"""
    db = SessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())
        db.commit()
        logger.warning("All tables truncated")
    except Exception as e:
        db.rollback()
        logger.error(f"Truncate error: {e}")
    finally:
        db.close()

# ============================================================================
# HEALTH CHECK
# ============================================================================

def check_db_health() -> bool:
    """Check database connection health"""
    try:
        from sqlalchemy import text
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        return True
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return False
