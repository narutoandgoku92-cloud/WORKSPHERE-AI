
# backend/tests/test_auth.py
# Authentication endpoint tests

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from core.database import get_db
from models import Organization


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def test_organization_id(db_session: Session) -> str:
    """Return the ID of the organization created by conftest.py."""
    organization = (
        db_session.query(Organization)
        .filter_by(email="test-organization@example.com")
        .first()
    )

    assert organization is not None, (
        "The test organization was not created by conftest.py"
    )

    return str(organization.id)


@pytest.fixture
def test_user_data(test_organization_id):
    """Registration data for a new user in the test organization."""
    return {
        "email": "new-test-user@example.com",
        "password": "TestPassword123!",
        "full_name": "New Test User",
        "organization_id": test_organization_id,
    }


# ============================================================================
# REGISTRATION TESTS
# ============================================================================

def test_register_new_user(client: TestClient, test_user_data):
    """Registration succeeds for a new user in an existing organization."""
    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )

    assert response.status_code == 200, response.text

    data = response.json()
    assert data["email"] == test_user_data["email"]
    assert data["full_name"] == test_user_data["full_name"]
    assert "id" in data
    assert data["is_active"] is True


def test_register_duplicate_email(client: TestClient, test_user_data):
    """Registration rejects an email already registered in the organization."""
    first_response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )
    assert first_response.status_code == 200, first_response.text

    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )

    assert response.status_code == 400
    assert "already exists" in response.json()["detail"].lower()


def test_register_invalid_email(client: TestClient, test_user_data):
    """Registration rejects an invalid email."""
    test_user_data["email"] = "invalid-email"

    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )

    assert response.status_code == 422


def test_register_weak_password(client: TestClient, test_user_data):
    """Registration rejects a password that fails schema validation."""
    test_user_data["password"] = "123"

    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )

    assert response.status_code == 422


def test_register_missing_fields(client: TestClient, test_user_data):
    """Registration rejects missing required fields."""
    test_user_data.pop("full_name")

    response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )

    assert response.status_code == 422


# ============================================================================
# LOGIN TESTS
# ============================================================================

def test_login_valid_credentials(client: TestClient, admin_credentials):
    """An existing test administrator can log in."""
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )

    assert response.status_code == 200, response.text

    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == admin_credentials["email"]



def test_login_invalid_email(client: TestClient, monkeypatch):
    """Login rejects an email that does not exist."""
    from api.v1.routes import auth

    # Isolate this test from account-lock state in shared Redis.
    monkeypatch.setattr(
        auth.login_tracker,
        "is_account_locked",
        lambda email: False,
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "nonexistent@example.com",
            "password": "WrongPassword123!",
        },
    )

    assert response.status_code == 401
    assert "invalid email or password" in response.json()["detail"].lower()



def test_login_wrong_password(client: TestClient, admin_credentials):
    """Login rejects an incorrect password."""
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": admin_credentials["email"],
            "password": "WrongPassword123!",
        },
    )

    assert response.status_code == 401
    assert "invalid email or password" in response.json()["detail"].lower()



def test_login_inactive_user(client: TestClient, monkeypatch):
    """An unknown account cannot authenticate."""
    from api.v1.routes import auth

    # Keep shared Redis lock state from affecting this test.
    monkeypatch.setattr(
        auth.login_tracker,
        "is_account_locked",
        lambda email: False,
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "inactive@example.com",
            "password": "TestPassword123!",
        },
    )

    assert response.status_code == 401



def test_login_missing_credentials(client: TestClient):
    """Login rejects a request without a password."""
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "test@example.com"},
    )

    assert response.status_code == 422


# ============================================================================
# TOKEN REFRESH TESTS
# ============================================================================

def test_refresh_token_valid(client: TestClient, admin_credentials):
    """A valid refresh token returns a new token pair."""
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )
    assert login_response.status_code == 200, login_response.text

    refresh_token = login_response.json()["refresh_token"]

    response = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )

    assert response.status_code == 200, response.text

    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_refresh_token_invalid(client: TestClient):
    """An invalid refresh token is rejected."""
    response = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": "Bearer invalid_token"},
    )

    assert response.status_code == 401


def test_refresh_token_missing(client: TestClient):
    """A refresh request without a token is rejected."""
    response = client.post("/api/v1/auth/refresh")

    # The current endpoint explicitly returns 401 when the token is absent.
    assert response.status_code == 401


# ============================================================================
# PASSWORD CHANGE TESTS
# ============================================================================

def test_change_password_valid(client: TestClient, admin_credentials):
    """An authenticated user can change their password."""
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )
    assert login_response.status_code == 200, login_response.text

    access_token = login_response.json()["access_token"]
    new_password = "NewTestPassword456!"

    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": admin_credentials["password"],
            "new_password": new_password,
            "confirm_password": new_password,
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200, response.text
    assert response.json()["message"] == "Password changed successfully"


def test_change_password_wrong_old_password(
    client: TestClient,
    admin_credentials,
):
    """An incorrect old password prevents a password change."""
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )
    assert login_response.status_code == 200, login_response.text

    access_token = login_response.json()["access_token"]
    new_password = "NewTestPassword456!"

    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": "WrongOldPassword123!",
            "new_password": new_password,
            "confirm_password": new_password,
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )

    # The current endpoint returns 400 for an incorrect old password.
    assert response.status_code == 400
    assert "old password is incorrect" in response.json()["detail"].lower()


def test_change_password_weak_new_password(
    client: TestClient,
    admin_credentials,
):
    """A weak new password is rejected by request validation."""
    login_response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials,
    )
    assert login_response.status_code == 200, login_response.text

    access_token = login_response.json()["access_token"]

    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": admin_credentials["password"],
            "new_password": "123",
            "confirm_password": "123",
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 422


def test_change_password_unauthorized(client: TestClient):
    """Password change requires authentication."""
    response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": "OldPassword123!",
            "new_password": "NewPassword456!",
            "confirm_password": "NewPassword456!",
        },
    )

    # get_current_user explicitly returns 401 when no token is supplied.
    assert response.status_code == 401


# ============================================================================
# INTEGRATION TEST
# ============================================================================

def test_complete_auth_flow(
    client: TestClient,
    test_user_data,
):
    """Exercise registration, login, password change, and token refresh."""
    register_response = client.post(
        "/api/v1/auth/register",
        json=test_user_data,
    )
    assert register_response.status_code == 200, register_response.text

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": test_user_data["email"],
            "password": test_user_data["password"],
        },
    )
    assert login_response.status_code == 200, login_response.text

    tokens = login_response.json()
    access_token = tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    new_password = "NewTestPassword456!"

    change_response = client.post(
        "/api/v1/auth/change-password",
        json={
            "old_password": test_user_data["password"],
            "new_password": new_password,
            "confirm_password": new_password,
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert change_response.status_code == 200, change_response.text

    # Use the refresh token from the login response.
    refresh_response = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )
    assert refresh_response.status_code == 200, refresh_response.text


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
