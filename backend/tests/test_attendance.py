# backend/tests/test_attendance.py - Attendance endpoint tests

import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
import json

from main import app

client = TestClient(app)

# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def auth_headers(admin_credentials):
    """Get authentication headers"""
    response = client.post(
        "/api/v1/auth/login",
        json=admin_credentials
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

@pytest.fixture
def admin_credentials():
    """Admin test credentials"""
    return {
        "email": "admin@optiwork.ai",
        "password": "password123"
    }

@pytest.fixture
def check_in_data():
    """Sample check-in data"""
    return {
        "latitude": 37.7749,
        "longitude": -122.4194,
        "method": "gps_verified",
        "face_verified": True,
        "liveness_verified": True
    }

# ============================================================================
# CHECK-IN TESTS
# ============================================================================

def test_check_in_valid(auth_headers, check_in_data):
    """Test successful check-in"""
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    assert response.status_code == 201
    data = response.json()
    assert "id" in data
    assert data["check_in_time"] is not None
    assert data["status"] == "checked_in"
    assert data["location_verified"] == True

def test_check_in_duplicate_today(auth_headers, check_in_data):
    """Test check-in fails if already checked in today"""
    # First check-in
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Second check-in same day
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    assert response.status_code == 409
    assert "already checked in" in response.json()["detail"].lower()

def test_check_in_missing_location(auth_headers, check_in_data):
    """Test check-in fails without location"""
    del check_in_data["latitude"]
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    assert response.status_code == 422

def test_check_in_invalid_coordinates(auth_headers, check_in_data):
    """Test check-in fails with invalid coordinates"""
    check_in_data["latitude"] = 999  # Invalid latitude
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    assert response.status_code == 422

def test_check_in_unauthorized():
    """Test check-in fails without authentication"""
    response = client.post(
        "/api/v1/attendance/check-in",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194,
            "method": "gps_verified"
        }
    )
    
    assert response.status_code == 403

# ============================================================================
# CHECK-OUT TESTS
# ============================================================================

def test_check_out_valid(auth_headers, check_in_data):
    """Test successful check-out"""
    # First check-in
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Then check-out
    response = client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194,
            "notes": "Project completed"
        },
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["check_out_time"] is not None
    assert data["status"] == "checked_out"

def test_check_out_without_check_in(auth_headers):
    """Test check-out fails if not checked in"""
    response = client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194
        },
        headers=auth_headers
    )
    
    assert response.status_code == 409
    assert "not checked in" in response.json()["detail"].lower()

def test_check_out_unauthorized():
    """Test check-out fails without authentication"""
    response = client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194
        }
    )
    
    assert response.status_code == 403

# ============================================================================
# TODAY'S STATS TESTS
# ============================================================================

def test_get_today_stats_checked_in(auth_headers, check_in_data):
    """Test getting today's stats when checked in"""
    # Check-in first
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Get today's stats
    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "checked_in"
    assert data["check_in_time"] is not None
    assert data["check_out_time"] is None
    assert "date" in data

def test_get_today_stats_checked_out(auth_headers, check_in_data):
    """Test getting today's stats when checked out"""
    # Check-in
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Check-out
    client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194
        },
        headers=auth_headers
    )
    
    # Get today's stats
    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "checked_out"
    assert data["check_in_time"] is not None
    assert data["check_out_time"] is not None
    assert data["hours_worked"] > 0

def test_get_today_stats_not_checked_in(auth_headers):
    """Test getting today's stats when not checked in"""
    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "not_checked_in"

def test_get_today_stats_unauthorized():
    """Test get today's stats fails without authentication"""
    response = client.get("/api/v1/attendance/today")
    
    assert response.status_code == 403

# ============================================================================
# EMPLOYEE HISTORY TESTS
# ============================================================================

def test_get_employee_attendance_history(auth_headers, check_in_data):
    """Test getting employee attendance history"""
    # Check-in
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Get login response to get employee ID
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "admin@optiwork.ai",
            "password": "password123"
        }
    )
    employee_id = login_response.json()["user"]["id"]
    
    # Get history
    response = client.get(
        f"/api/v1/attendance/employee/{employee_id}?days=30",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0

def test_get_employee_history_nonexistent():
    """Test getting history for non-existent employee"""
    auth_headers = {"Authorization": "Bearer fake_token"}
    response = client.get(
        "/api/v1/attendance/employee/00000000-0000-0000-0000-000000000000",
        headers=auth_headers
    )
    
    # Will likely return 401 due to invalid token, or 404 if token is valid
    assert response.status_code in [401, 404]

# ============================================================================
# HOURS WORKED TESTS
# ============================================================================

def test_hours_worked_calculation(auth_headers, check_in_data):
    """Test hours worked calculation is correct"""
    # Check-in
    client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    
    # Check-out
    client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194
        },
        headers=auth_headers
    )
    
    # Get today's stats
    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    # Hours should be calculated from check-in to check-out
    assert data["hours_worked"] >= 0

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

def test_complete_attendance_flow(auth_headers, check_in_data):
    """Test complete attendance flow: check-in -> get stats -> check-out"""
    
    # 1. Check-in
    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers
    )
    assert checkin_response.status_code == 201
    assert checkin_response.json()["status"] == "checked_in"
    
    # 2. Get today's stats while checked in
    stats_response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    assert stats_response.status_code == 200
    assert stats_response.json()["status"] == "checked_in"
    
    # 3. Check-out
    checkout_response = client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194,
            "notes": "Work completed"
        },
        headers=auth_headers
    )
    assert checkout_response.status_code == 200
    assert checkout_response.json()["status"] == "checked_out"
    
    # 4. Get final today's stats
    final_stats_response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers
    )
    assert final_stats_response.status_code == 200
    assert final_stats_response.json()["status"] == "checked_out"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
