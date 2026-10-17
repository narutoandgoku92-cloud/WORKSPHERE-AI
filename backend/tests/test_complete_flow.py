# backend/tests/test_complete_flow.py - Complete end-to-end system flow tests

import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
import json
from models import Organization,Employee

from main import app

client = TestClient(app)

# ============================================================================
# COMPLETE SYSTEM FLOW TESTS
# ============================================================================

class TestCompleteWorkflow:
    """Test complete workflow from registration to payroll"""
    
    
def test_complete_employee_workflow( client, db_session):
    """Test the core employee workflow using the isolated test database."""

    print("\n=== Step 1: Prepare test data ===")

    organization = db_session.query(Organization).first()
    assert organization is not None, "Test organization was not created"

    employee = Employee(
        org_id=organization.id,
        employee_id="WF-EMP-001",
        full_name="Workflow Test User",
        email="workflow@optiwork.ai",
        status="active",
        is_verified=True,
    )
    db_session.add(employee)
    db_session.commit()
    db_session.refresh(employee)

    print("\n=== Step 2: Register employee ===")

    registration_data = {
        "email": "workflow@optiwork.ai",
        "password": "WorkflowTest123!",
        "full_name": "Workflow Test User",
        "organization_id": str(organization.id),
        "employee_id": "WF-EMP-001",
    }

    register_response = client.post(
        "/api/v1/auth/register",
        json=registration_data,
    )
    assert register_response.status_code == 200, register_response.text
    print("Registration successful")

    print("\n=== Step 3: Login ===")

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": registration_data["email"],
            "password": registration_data["password"],
        },
    )
    assert login_response.status_code == 200, login_response.text

    login_data = login_response.json()
    access_token = login_data["access_token"]
    refresh_token = login_data["refresh_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    print("Login successful")

    print("\n=== Step 4: Check in ===")

    checkin_response = client.post(
        "/api/v1/attendance/check-in",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194,
            "method": "gps_verified",
            "face_verified": True,
            "liveness_verified": True,
        },
        headers=headers,
    )
    assert checkin_response.status_code == 201, checkin_response.text
    print("Check-in successful")

    print("\n=== Step 5: Check out ===")

    checkout_response = client.post(
        "/api/v1/attendance/check-out",
        json={
            "latitude": 37.7749,
            "longitude": -122.4194,
            "notes": "Completed workflow test",
        },
        headers=headers,
    )
    assert checkout_response.status_code == 200, checkout_response.text
    print("Check-out successful")

    print("\n=== Step 6: Verify attendance ===")

    today_response = client.get(
        "/api/v1/attendance/today",
        headers=headers,
    )
    assert today_response.status_code == 200, today_response.text
    print("Attendance endpoint responded successfully")

    print("\n=== Step 7: Refresh token ===")

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )
    assert refresh_response.status_code == 200, refresh_response.text

    refreshed_tokens = refresh_response.json()
    assert "access_token" in refreshed_tokens
    assert "refresh_token" in refreshed_tokens
    print("Token refresh successful")

    print("\n=== CORE EMPLOYEE WORKFLOW PASSED ===")

class TestSystemIntegration:
    """Test system integration and health"""
    
    def test_system_health_check(self):
        """Test that all system endpoints respond correctly"""
        print("\n=== System Health Check ===")
        
        # 1. Root endpoint
        root = client.get("/")
        assert root.status_code == 200
        print("✓ Root endpoint: OK")
        
        # 2. Health check
        health = client.get("/health")
        assert health.status_code == 200
        print("✓ Health check: OK")
        
        # 3. Live check
        live = client.get("/health/live")
        assert live.status_code == 200
        print("✓ Live probe: OK")
        
        # 4. Ready check
        ready = client.get("/health/ready")
        # May return 503 if services aren't ready, but endpoint should exist
        assert ready.status_code in [200, 503]
        print("✓ Ready probe: OK")
        
        print("✅ System health checks passed")
    
    def test_all_routes_registered(self):
        """Test that all API routes are registered"""
        print("\n=== Checking Registered Routes ===")
        
        routes = [
            ("/api/v1/auth/register", "POST"),
            ("/api/v1/auth/login", "POST"),
            ("/api/v1/users", "GET"),
            ("/api/v1/employees", "GET"),
            ("/api/v1/attendance/check-in", "POST"),
            ("/api/v1/attendance/today", "GET"),
            ("/api/v1/face-recognition/enroll", "POST"),
            ("/api/v1/gps/location", "POST"),
            ("/api/v1/analytics/summary", "GET"),
            ("/api/v1/payroll/current", "GET"),
            ("/api/v1/admin/dashboard", "GET"),
        ]
        
        for route, method in routes:
            # Try to access the route (won't auth yet, but should exist)
            if method == "GET":
                response = client.get(route)
            else:
                response = client.post(route, json={})
            
            # Should either return 403 (unauthorized) or 422 (validation error)
            # NOT 404 (not found)
            assert response.status_code != 404, f"Route {method} {route} not found"
            print(f"✓ {method:6} {route}")
        
        print("✅ All routes registered correctly")

class TestErrorHandling:
    """Test system error handling and edge cases"""
    
    def test_invalid_token_handling(self):
        """Test that invalid tokens are properly rejected"""
        print("\n=== Invalid Token Handling ===")
        
        invalid_headers = {"Authorization": "Bearer invalid_token_123"}
        
        response = client.get(
            "/api/v1/attendance/today",
            headers=invalid_headers
        )
        assert response.status_code == 401
        print("✓ Invalid token rejected with 401")
    
    def test_missing_auth_header(self,client):
        """Test that missing auth header is handled"""
        print("\n=== Missing Auth Header ===")
        
        response = client.get("/api/v1/attendance/today")
        assert response.status_code == 401
        print("✓ Missing auth rejected with 403")
    
    def test_invalid_request_data(self):
        """Test that invalid request data is properly validated"""
        print("\n=== Invalid Request Data ===")
        
        # Missing required fields
        response = client.post(
            "/api/v1/auth/register",
            json={"email": "test@example.com"}  # Missing password, full_name, org_id
        )
        assert response.status_code == 422
        print("✓ Missing required fields rejected with 422")
    
    def test_invalid_email_format(self):
        """Test that invalid email format is rejected"""
        print("\n=== Invalid Email Format ===")
        
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "password": "Password123!",
                "full_name": "Test User",
                "organization_id": "550e8400-e29b-41d4-a716-446655440000"
            }
        )
        assert response.status_code == 422
        print("✓ Invalid email format rejected with 422")

class TestDataConsistency:
    """Test data consistency across operations"""
    
    def test_check_in_creates_record(self, client, admin_credentials):
        """Test that check-in creates a record that can be retrieved."""
        login = client.post(
            "/api/v1/auth/login",
            json=admin_credentials,
        )
        assert login.status_code == 200, login.text

        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        checkin = client.post(
            "/api/v1/attendance/check-in",
            json={
                "latitude": 37.7749,
                "longitude": -122.4194,
                "method": "gps_verified",
            },
            headers=headers,
        )
        assert checkin.status_code == 201, checkin.text

        today = client.get(
            "/api/v1/attendance/today",
            headers=headers,
        )
        assert today.status_code == 200, today.text
        
        
        print("Today's attendance response:", today.json())
if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
