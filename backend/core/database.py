
# backend/core/database.py - Database setup and session management

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from sqlalchemy.pool import QueuePool
from typing import Generator
import logging

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

# Use the Psycopg 3 driver for PostgreSQL.
# The requirements file already includes psycopg[binary].
database_url = settings.DATABASE_URL

if database_url.startswith("postgresql://"):
    database_url = database_url.replace(
        "postgresql://",
        "postgresql+psycopg://",
        1,
    )
elif database_url.startswith("postgres://"):
    # Normalize older PostgreSQL URL schemes if encountered.
    database_url = database_url.replace(
        "postgres://",
        "postgresql+psycopg://",
        1,
    )

is_sqlite = database_url.startswith("sqlite")

if is_sqlite:
    engine = create_engine(
        database_url,
        echo=settings.DATABASE_ECHO,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
        future=True,
    )
else:
    engine = create_engine(
        database_url,
        echo=settings.DATABASE_ECHO,
        poolclass=QueuePool,
        pool_size=settings.DATABASE_POOL_SIZE,
        max_overflow=settings.DATABASE_MAX_OVERFLOW,
        pool_timeout=settings.DATABASE_POOL_TIMEOUT,
        pool_pre_ping=True,
        connect_args={
            "connect_timeout": 10,
            "options": "-c statement_timeout=30000",
        },
        future=True,
    )

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    expire_on_commit=False,
    future=True,
)

Base = declarative_base()

# ============================================================================
# DATABASE EVENTS
# ============================================================================

@event.listens_for(engine, "connect")
def enable_sqlite_foreign_keys(dbapi_conn, connection_record):
    """Enable SQLite foreign-key enforcement."""
    if is_sqlite:
        cursor = dbapi_conn.cursor()
        try:
            cursor.execute("PRAGMA foreign_keys=ON")
        finally:
            cursor.close()


# ============================================================================
# DEPENDENCY INJECTION
# ============================================================================

def get_db() -> Generator[Session, None, None]:
    """Provide a database session and close it after use."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ============================================================================
# DATABASE INITIALIZATION
# ============================================================================

def init_db():
    """Initialize database tables and PostgreSQL extensions."""
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")

        if not is_sqlite:
            with engine.connect() as conn:
                conn.execute(
                    text('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
                )
                conn.execute(
                    text('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
                )
                conn.commit()
                logger.info("PostgreSQL extensions created successfully")

    except Exception as e:
        logger.error("Database initialization error: %s", e)
        raise


def drop_db():
    """Drop all database tables (use with caution)."""
    Base.metadata.drop_all(bind=engine)
    logger.warning("All database tables dropped")


def truncate_db():
    """Truncate all tables (use with caution)."""
    db = SessionLocal()
    try:
        for table in reversed(Base.metadata.sorted_tables):
            db.execute(table.delete())

        db.commit()
        logger.warning("All tables truncated")

    except Exception as e:
        db.rollback()
        logger.error("Truncate error: %s", e)

    finally:
        db.close()


# ============================================================================
# HEALTH CHECK
# ============================================================================

def check_db_health() -> bool:
    """Check database connection health."""
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True

    except Exception as e:
        logger.error("Database health check failed: %s", e)
        return False
