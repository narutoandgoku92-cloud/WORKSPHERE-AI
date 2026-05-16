# backend/tests/conftest.py - Pytest configuration and fixtures

import pytest
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

# Add parent directory to path
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app
from core.database import Base, get_db

# ============================================================================
# TEST DATABASE SETUP
# ============================================================================

# Use in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

@pytest.fixture(scope="session")
def engine():
    """Create test database engine"""
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL,
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session(engine):
    """Create test database session"""
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    
    def override_get_db():
        try:
            yield db
        finally:
            db.close()
    
    app.dependency_overrides[get_db] = override_get_db
    
    yield db
    
    app.dependency_overrides.clear()

@pytest.fixture
def client(db_session):
    """Create test client"""
    return TestClient(app)

# ============================================================================
# GLOBAL FIXTURES
# ============================================================================

@pytest.fixture
def admin_credentials():
    """Admin test credentials"""
    return {
        "email": "admin@optiwork.ai",
        "password": "password123"
    }

@pytest.fixture
def test_user_data():
    """Sample user data for testing"""
    return {
        "email": "test@optiwork.ai",
        "password": "TestPassword123!",
        "full_name": "Test User",
        "organization_id": "550e8400-e29b-41d4-a716-446655440000"
    }

@pytest.fixture
def auth_headers(client, admin_credentials):
    """Get authentication headers"""
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    if response.status_code == 200:
        token = response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}
    return {}

# ============================================================================
# PYTEST CONFIGURATION
# ============================================================================

def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers", "unit: mark test as unit test"
    )

# ============================================================================
# TEST MARKERS
# ============================================================================

@pytest.fixture(scope="session")
def pytest_plugins():
    """Load pytest plugins"""
    return ["pytest_asyncio"]
