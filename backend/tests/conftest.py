
# backend/tests/conftest.py

import os
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Ensure the backend directory is importable.
sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..")),
)

from main import app
from core.database import Base, get_db
from core.security import hash_password
from models import Employee, Organization, User


TEST_ADMIN_EMAIL = "test-admin@example.com"
TEST_ADMIN_PASSWORD = "TestAdminPassword123!"


@pytest.fixture(scope="session")
def engine():
    """Use one isolated in-memory SQLite database for the test session."""
    test_engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    # Ensure all model tables are registered before creating the schema.
    Base.metadata.create_all(bind=test_engine)

    yield test_engine

    Base.metadata.drop_all(bind=test_engine)
    test_engine.dispose()


@pytest.fixture
def db_session(engine):
    """Give each test a clean database session."""
    TestingSessionLocal = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=engine,
        expire_on_commit=False,
    )
    db = TestingSessionLocal()

    # Start each test with a clean database.
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    # Create the test organization.
    organization = Organization(
        name="Test Organization",
        email="test-organization@example.com",
    )
    db.add(organization)
    db.flush()

    # Create an employee record for the admin.
    employee = Employee(
        org_id=organization.id,
        employee_id="TEST-EMP-001",
        full_name="Test Admin",
        email=TEST_ADMIN_EMAIL,
        status="active",
        is_verified=True,
    )
    db.add(employee)
    db.flush()

    # Create the admin user and link it to the employee.
    admin = User(
        org_id=organization.id,
        employee_id=employee.id,
        email=TEST_ADMIN_EMAIL,
        password_hash=hash_password(TEST_ADMIN_PASSWORD),
        full_name="Test Admin",
        role="admin",
        is_active=True,
    )
    db.add(admin)
    db.commit()

    # Make API requests use the isolated test database.
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    yield db

    # Clean up after each test.
    app.dependency_overrides.pop(get_db, None)
    db.close()


@pytest.fixture
def client(db_session):
    """Create a test client using the isolated test database."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def admin_credentials():
    """Credentials for the seeded test admin."""
    return {
        "email": TEST_ADMIN_EMAIL,
        "password": TEST_ADMIN_PASSWORD,
    }


@pytest.fixture
def test_user_data():
    """Sample registration data."""
    return {
        "email": "test-user@example.com",
        "password": "TestUserPassword123!",
        "full_name": "Test User",
    }


@pytest.fixture
def auth_headers(client, admin_credentials):
    """Authenticate the test admin and return its bearer token."""
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )

    assert response.status_code == 200, (
        f"Test admin login failed: "
        f"{response.status_code} {response.text}"
    )

    token = response.json().get("access_token")
    assert token, "Login response did not contain access_token"

    return {"Authorization": f"Bearer {token}"}


def pytest_configure(config):
    """Register custom pytest markers."""
    config.addinivalue_line(
        "markers",
        "integration: mark tests as integration tests",
    )
    config.addinivalue_line(
        "markers",
        "unit: mark tests as unit tests",
    )
