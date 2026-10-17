
# backend/tests/test_attendance.py

import pytest


# Keep this value consistent with the CheckInMethod enum in your schemas.
TEST_CHECK_IN_METHOD = "face"


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def check_in_data():
    """Sample check-in data matching AttendanceCheckInRequest."""
    return {
        "latitude": 37.7749,
        "longitude": -122.4194,
        "check_in_method": TEST_CHECK_IN_METHOD,
        "face_image": None,
        "device_id": "test-device-001",
    }


@pytest.fixture
def check_out_data():
    """Sample check-out data matching AttendanceCheckOutRequest."""
    return {
        "latitude": 37.7749,
        "longitude": -122.4194,
    }


# ============================================================================
# CHECK-IN TESTS
# ============================================================================

def test_check_in_valid(client, auth_headers, check_in_data):
    """A valid check-in should create an attendance record."""
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert data["id"]
    assert data["employee_id"]
    assert data["check_in_time"] is not None
    assert data["check_in_verified"] is True
    assert "gps_verified" in data
    assert data["check_in_method"] is not None
    assert data["created_at"] is not None


def test_check_in_duplicate_today(client, auth_headers, check_in_data):
    """A second check-in on the same day should be rejected."""
    first_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert first_response.status_code == 201, first_response.text

    second_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    # The current endpoint returns HTTP 400 for duplicate check-ins.
    assert second_response.status_code == 400, second_response.text
    assert "already checked in" in (
        second_response.json()["detail"].lower()
    )


def test_check_in_missing_location(client, auth_headers, check_in_data):
    """Missing required latitude should fail request validation."""
    invalid_data = check_in_data.copy()
    invalid_data.pop("latitude")

    response = client.post(
        "/api/v1/attendance/check-in",
        json=invalid_data,
        headers=auth_headers,
    )

    assert response.status_code == 422, response.text


def test_check_in_invalid_coordinates(
    client,
    auth_headers,
    check_in_data,
):
    """Invalid latitude should be rejected."""
    invalid_data = check_in_data.copy()
    invalid_data["latitude"] = 999

    response = client.post(
        "/api/v1/attendance/check-in",
        json=invalid_data,
        headers=auth_headers,
    )

    # The endpoint must validate coordinate ranges independently
    # of whether the organization has a geofence.
    assert response.status_code == 400, response.text
    assert "invalid gps coordinates" in (
        response.json()["detail"].lower()
    )


def test_check_in_unauthorized(client, check_in_data):
    """Check-in without authentication should be rejected."""
    response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
    )

    assert response.status_code in (401, 403), response.text


# ============================================================================
# CHECK-OUT TESTS
# ============================================================================

def test_check_out_valid(
    client,
    auth_headers,
    check_in_data,
    check_out_data,
):
    """An employee should be able to check out after checking in."""
    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert checkin_response.status_code == 201, checkin_response.text

    checkout_response = client.post(
        "/api/v1/attendance/check-out",
        json=check_out_data,
        headers=auth_headers,
    )

    assert checkout_response.status_code == 200, checkout_response.text

    data = checkout_response.json()

    assert data["id"] == checkin_response.json()["id"]
    assert data["check_out_time"] is not None
    assert data["employee_id"]


def test_check_out_without_check_in(
    client,
    auth_headers,
    check_out_data,
):
    """Check-out without an active check-in should be rejected."""
    response = client.post(
        "/api/v1/attendance/check-out",
        json=check_out_data,
        headers=auth_headers,
    )

    # The current endpoint returns HTTP 400 in this situation.
    assert response.status_code == 400, response.text
    assert "no active check-in found" in (
        response.json()["detail"].lower()
    )


def test_check_out_unauthorized(client, check_out_data):
    """Check-out without authentication should be rejected."""
    response = client.post(
        "/api/v1/attendance/check-out",
        json=check_out_data,
    )

    assert response.status_code in (401, 403), response.text


# ============================================================================
# COMPANY-WIDE TODAY STATISTICS
# ============================================================================

def test_get_today_stats(client, auth_headers):
    """Admins should receive company-wide attendance statistics."""
    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers,
    )

    assert response.status_code == 200, response.text

    data = response.json()

    assert "total_employees" in data
    assert "present_today" in data
    assert "absent_today" in data
    assert "late_today" in data
    assert "checked_in_count" in data
    assert "checked_out_count" in data

    assert data["total_employees"] >= 0
    assert data["present_today"] >= 0
    assert data["absent_today"] >= 0
    assert data["late_today"] >= 0
    assert data["checked_in_count"] >= 0
    assert data["checked_out_count"] >= 0

    assert (
        data["present_today"] + data["absent_today"]
        == data["total_employees"]
    )


def test_get_today_stats_after_check_in(
    client,
    auth_headers,
    check_in_data,
):
    """Statistics should reflect a successful check-in."""
    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert checkin_response.status_code == 201, checkin_response.text

    response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers,
    )

    assert response.status_code == 200, response.text

    data = response.json()

    assert data["total_employees"] >= 1
    assert data["present_today"] >= 1
    assert data["checked_in_count"] >= 1


def test_get_today_stats_unauthorized(client):
    """Statistics should not be available without authentication."""
    response = client.get("/api/v1/attendance/today")

    assert response.status_code in (401, 403), response.text


# ============================================================================
# EMPLOYEE ATTENDANCE HISTORY
# ============================================================================

def test_get_employee_attendance_history(
    client,
    auth_headers,
    check_in_data,
    db_session,
):
    """An admin should be able to retrieve an employee's history."""
    from repositories import EmployeeRepository

    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert checkin_response.status_code == 201, checkin_response.text

    employee_id = checkin_response.json()["employee_id"]

    response = client.get(
        f"/api/v1/attendance/employee/{employee_id}?days=30",
        headers=auth_headers,
    )

    assert response.status_code == 200, response.text

    data = response.json()

    assert isinstance(data, list)
    assert any(record["id"] == checkin_response.json()["id"] for record in data)


def test_get_employee_history_nonexistent(client, auth_headers):
    """An unknown employee ID should return 404."""
    response = client.get(
        "/api/v1/attendance/employee/"
        "00000000-0000-0000-0000-000000000000",
        headers=auth_headers,
    )

    assert response.status_code == 404, response.text


def test_get_my_attendance(
    client,
    auth_headers,
    check_in_data,
):
    """An employee should be able to retrieve their own history."""
    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert checkin_response.status_code == 201, checkin_response.text

    response = client.get(
        "/api/v1/attendance/me?days=30",
        headers=auth_headers,
    )

    assert response.status_code == 200, response.text
    assert isinstance(response.json(), list)


def test_get_employee_history_invalid_days(client, auth_headers):
    """History requests must reject invalid day ranges."""
    response = client.get(
        "/api/v1/attendance/me?days=0",
        headers=auth_headers,
    )

    assert response.status_code == 400, response.text


def test_get_employee_history_invalid_pagination(client, auth_headers):
    """History requests must reject invalid pagination."""
    response = client.get(
        "/api/v1/attendance/me?days=30&skip=-1",
        headers=auth_headers,
    )

    assert response.status_code == 400, response.text


# ============================================================================
# GPS DISTANCE CALCULATION
# ============================================================================

def test_calculate_distance_same_location():
    """Distance between identical coordinates should be approximately zero."""
    from api.v1.routes.attendance import calculate_distance

    distance = calculate_distance(
        37.7749,
        -122.4194,
        37.7749,
        -122.4194,
    )

    assert distance == pytest.approx(0, abs=0.01)


def test_calculate_distance_different_locations():
    """Different coordinates should produce a positive distance."""
    from api.v1.routes.attendance import calculate_distance

    distance = calculate_distance(
        37.7749,
        -122.4194,
        37.7849,
        -122.4094,
    )

    assert distance > 0


# ============================================================================
# INTEGRATION TEST
# ============================================================================

def test_complete_attendance_flow(
    client,
    auth_headers,
    check_in_data,
    check_out_data,
):
    """Test check-in, company statistics, check-out, and final statistics."""

    # 1. Check in.
    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json=check_in_data,
        headers=auth_headers,
    )

    assert checkin_response.status_code == 201, checkin_response.text
    checkin_data = checkin_response.json()

    # 2. Confirm that the employee appears in today's statistics.
    stats_response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers,
    )

    assert stats_response.status_code == 200, stats_response.text
    assert stats_response.json()["present_today"] >= 1

    # 3. Check out.
    checkout_response = client.post(
        "/api/v1/attendance/check-out",
        json=check_out_data,
        headers=auth_headers,
    )

    assert checkout_response.status_code == 200, checkout_response.text

    checkout_data = checkout_response.json()

    assert checkout_data["id"] == checkin_data["id"]
    assert checkout_data["check_out_time"] is not None

    # 4. Confirm that today's statistics still include the employee.
    final_stats_response = client.get(
        "/api/v1/attendance/today",
        headers=auth_headers,
    )

    assert final_stats_response.status_code == 200, final_stats_response.text
    assert final_stats_response.json()["present_today"] >= 1
    assert final_stats_response.json()["checked_out_count"] >= 1
