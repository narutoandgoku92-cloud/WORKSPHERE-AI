# backend/tests/test_auth.py - Authentication endpoint tests

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import json

from main import app
from core.database import get_db
from schemas import LoginRequest, UserCreate
from repositories import UserRepository
from core.security import SecurityManager

client = TestClient(app)

# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def db_session(monkeypatch):
    """Create test database session"""
    # Mock database session
    class MockSession:
        pass
    return MockSession()

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
def admin_credentials():
    """Admin test credentials"""
    return {
        "email": "admin@optiwork.ai",
        "password": "password123"
    }

# ============================================================================
# REGISTRATION TESTS
# ============================================================================

def test_register_new_user(test_user_data):
    """Test user registration with valid data"""
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == test_user_data["email"]
    assert data["full_name"] == test_user_data["full_name"]
    assert "id" in data
    assert data["is_active"] == True

def test_register_duplicate_email(test_user_data):
    """Test registration fails with duplicate email"""
    # First registration
    client.post("/api/v1/auth/register", json=test_user_data)
    
    # Second registration with same email
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"]

def test_register_invalid_email(test_user_data):
    """Test registration fails with invalid email"""
    test_user_data["email"] = "invalid-email"
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    
    assert response.status_code == 422

def test_register_weak_password(test_user_data):
    """Test registration fails with weak password"""
    test_user_data["password"] = "123"  # Too weak
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    
    assert response.status_code == 422

def test_register_missing_fields(test_user_data):
    """Test registration fails with missing required fields"""
    del test_user_data["full_name"]
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    
    assert response.status_code == 422

# ============================================================================
# LOGIN TESTS
# ============================================================================

def test_login_valid_credentials(admin_credentials):
    """Test successful login"""
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert "user" in data
    assert data["user"]["email"] == admin_credentials["email"]

def test_login_invalid_email():
    """Test login fails with non-existent email"""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "nonexistent@optiwork.ai",
            "password": "password123"
        }
    )
    
    assert response.status_code == 401
    assert "Invalid credentials" in response.json()["detail"]

def test_login_wrong_password(admin_credentials):
    """Test login fails with wrong password"""
    admin_credentials["password"] = "wrongpassword"
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    
    assert response.status_code == 401
    assert "Invalid credentials" in response.json()["detail"]

def test_login_inactive_user():
    """Test login fails for inactive user"""
    # This would need a user marked as inactive in DB
    # Assuming we have such a user
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "inactive@optiwork.ai",
            "password": "password123"
        }
    )
    
    assert response.status_code == 401

def test_login_missing_credentials():
    """Test login fails with missing fields"""
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "test@optiwork.ai"}  # Missing password
    )
    
    assert response.status_code == 422

# ============================================================================
# TOKEN REFRESH TESTS
# ============================================================================

def test_refresh_token_valid(admin_credentials):
    """Test token refresh with valid refresh token"""
    # First login
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    refresh_token = login_response.json()["refresh_token"]
    
    # Refresh token
    response = client.post(
        "/api/v1/auth/refresh",
        json={},
        headers={"Authorization": f"Bearer {refresh_token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_refresh_token_invalid():
    """Test token refresh fails with invalid token"""
    response = client.post(
        "/api/v1/auth/refresh",
        json={},
        headers={"Authorization": "Bearer invalid_token"}
    )
    
    assert response.status_code == 401

def test_refresh_token_missing():
    """Test token refresh fails without token"""
    response = client.post(
        "/api/v1/auth/refresh",
        json={}
    )
    
    assert response.status_code == 403

# ============================================================================
# PASSWORD CHANGE TESTS
# ============================================================================

def test_change_password_valid(admin_credentials):
    """Test successful password change"""
    # Login first
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    access_token = login_response.json()["access_token"]
    
    # Change password
    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": admin_credentials["password"],
            "new_password": "NewPassword123!"
        },
        headers={"Authorization": f"Bearer {access_token}"}
    )
    
    assert response.status_code == 200
    assert response.json()["message"] == "Password changed successfully"

def test_change_password_wrong_old_password(admin_credentials):
    """Test password change fails with wrong old password"""
    # Login first
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    access_token = login_response.json()["access_token"]
    
    # Try to change with wrong old password
    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": "wrongpassword",
            "new_password": "NewPassword123!"
        },
        headers={"Authorization": f"Bearer {access_token}"}
    )
    
    assert response.status_code == 401
    assert "Invalid" in response.json()["detail"]

def test_change_password_weak_new_password(admin_credentials):
    """Test password change fails with weak new password"""
    # Login first
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    access_token = login_response.json()["access_token"]
    
    # Try to change to weak password
    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": admin_credentials["password"],
            "new_password": "123"
        },
        headers={"Authorization": f"Bearer {access_token}"}
    )
    
    assert response.status_code == 422

def test_change_password_unauthorized():
    """Test password change fails without authentication"""
    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": "password",
            "new_password": "NewPassword123!"
        }
    )
    
    assert response.status_code == 403

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

def test_complete_auth_flow(test_user_data, admin_credentials):
    """Test complete authentication flow: register -> login -> refresh -> change password"""
    
    # 1. Register new user
    register_response = client.post(
        "/api/v1/auth/register",
        json=test_user_data
    )
    assert register_response.status_code == 201
    
    # 2. Login with registered credentials
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": test_user_data["email"],
            "password": test_user_data["password"]
        }
    )
    assert login_response.status_code == 200
    access_token = login_response.json()["access_token"]
    refresh_token = login_response.json()["refresh_token"]
    
    # 3. Use access token to change password
    change_pwd_response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": test_user_data["password"],
            "new_password": "NewPassword123!"
        },
        headers={"Authorization": f"Bearer {access_token}"}
    )
    assert change_pwd_response.status_code == 200
    
    # 4. Refresh token
    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={},
        headers={"Authorization": f"Bearer {refresh_token}"}
    )
    assert refresh_response.status_code == 200

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
