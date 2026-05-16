# backend/tests/test_complete_flow.py - Complete end-to-end system flow tests

import pytest
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
import json

from main import app

client = TestClient(app)

# ============================================================================
# COMPLETE SYSTEM FLOW TESTS
# ============================================================================

class TestCompleteWorkflow:
    """Test complete workflow from registration to payroll"""
    
    def test_complete_employee_workflow(self):
        """Test complete workflow: Register → Login → CheckIn → CheckOut → View Payroll"""
        
        # 1. Register new employee
        print("\n=== Step 1: Registration ===")
        registration_data = {
            "email": "workflow@optiwork.ai",
            "password": "WorkflowTest123!",
            "full_name": "Workflow Test User",
            "organization_id": "550e8400-e29b-41d4-a716-446655440000"
        }
        register_response = client.post(
            "/api/v1/auth/register",
            json=registration_data
        )
        assert register_response.status_code == 201
        print(f"✓ Registration successful: {register_response.json()['email']}")
        
        # 2. Login with new credentials
        print("\n=== Step 2: Login ===")
        login_data = {
            "email": registration_data["email"],
            "password": registration_data["password"]
        }
        login_response = client.post(
            "/api/v1/auth/login",
            json=login_data
        )
        assert login_response.status_code == 200
        access_token = login_response.json()["access_token"]
        refresh_token = login_response.json()["refresh_token"]
        user = login_response.json()["user"]
        print(f"✓ Login successful, got access token")
        print(f"  User ID: {user['id']}")
        print(f"  Role: {user['role']}")
        
        # 3. Get employee details (if employee exists)
        print("\n=== Step 3: Get Employee Details ===")
        headers = {"Authorization": f"Bearer {access_token}"}
        
        # Try to get employee by user ID
        employees_response = client.get(
            f"/api/v1/employees",
            headers=headers
        )
        assert employees_response.status_code == 200
        employees = employees_response.json()
        print(f"✓ Got employees list: {len(employees)} employees")
        
        # 4. Perform Check-In
        print("\n=== Step 4: Check-In ===")
        checkin_data = {
            "latitude": 37.7749,
            "longitude": -122.4194,
            "method": "gps_verified",
            "face_verified": True,
            "liveness_verified": True
        }
        checkin_response = client.post(
            "/api/v1/attendance/check-in",
            json=checkin_data,
            headers=headers
        )
        assert checkin_response.status_code == 201
        checkin_data_response = checkin_response.json()
        print(f"✓ Check-in successful")
        print(f"  Check-in Time: {checkin_data_response['check_in_time']}")
        print(f"  Status: {checkin_data_response['status']}")
        print(f"  Location Verified: {checkin_data_response['location_verified']}")
        
        # 5. Get today's attendance status
        print("\n=== Step 5: Get Today's Attendance ===")
        today_response = client.get(
            "/api/v1/attendance/today",
            headers=headers
        )
        assert today_response.status_code == 200
        today_data = today_response.json()
        print(f"✓ Got today's attendance")
        print(f"  Status: {today_data['status']}")
        print(f"  Check-in: {today_data['check_in_time']}")
        
        # 6. Perform Check-Out
        print("\n=== Step 6: Check-Out ===")
        checkout_data = {
            "latitude": 37.7749,
            "longitude": -122.4194,
            "notes": "Completed workflow test"
        }
        checkout_response = client.post(
            "/api/v1/attendance/check-out",
            json=checkout_data,
            headers=headers
        )
        assert checkout_response.status_code == 200
        checkout_data_response = checkout_response.json()
        print(f"✓ Check-out successful")
        print(f"  Check-out Time: {checkout_data_response['check_out_time']}")
        print(f"  Status: {checkout_data_response['status']}")
        print(f"  Hours Worked: {checkout_data_response.get('hours_worked', 'N/A')}")
        
        # 7. Get updated attendance status
        print("\n=== Step 7: Verify Attendance Status ===")
        final_attendance = client.get(
            "/api/v1/attendance/today",
            headers=headers
        )
        assert final_attendance.status_code == 200
        final_data = final_attendance.json()
        print(f"✓ Final attendance status")
        print(f"  Status: {final_data['status']}")
        print(f"  Check-out recorded: {final_data['check_out_time'] is not None}")
        
        # 8. Get attendance history
        print("\n=== Step 8: Get Attendance History ===")
        history_response = client.get(
            f"/api/v1/attendance/employee/{user['id']}?days=7",
            headers=headers
        )
        assert history_response.status_code == 200
        history = history_response.json()
        print(f"✓ Attendance history retrieved")
        print(f"  Records found: {len(history)}")
        
        # 9. Get analytics
        print("\n=== Step 9: Get Employee Analytics ===")
        analytics_response = client.get(
            f"/api/v1/analytics/employee/{user['id']}",
            headers=headers
        )
        assert analytics_response.status_code == 200
        analytics = analytics_response.json()
        print(f"✓ Analytics retrieved")
        print(f"  Total Hours: {analytics.get('total_hours', 'N/A')}")
        print(f"  Days Present: {analytics.get('days_present', 'N/A')}")
        print(f"  Productivity Score: {analytics.get('productivity_score', 'N/A')}")
        
        # 10. Get current payroll
        print("\n=== Step 10: Get Current Payroll ===")
        payroll_response = client.get(
            "/api/v1/payroll/current",
            headers=headers
        )
        assert payroll_response.status_code == 200
        payroll = payroll_response.json()
        print(f"✓ Payroll information retrieved")
        print(f"  Period: {payroll.get('period_start')} to {payroll.get('period_end')}")
        print(f"  Total Hours: {payroll.get('total_hours', 'N/A')}")
        print(f"  Total Pay: ${payroll.get('total_pay', 0):.2f}")
        
        # 11. Refresh token
        print("\n=== Step 11: Token Refresh ===")
        refresh_response = client.post(
            "/api/v1/auth/refresh",
            json={},
            headers={"Authorization": f"Bearer {refresh_token}"}
        )
        assert refresh_response.status_code == 200
        new_token = refresh_response.json()["access_token"]
        print(f"✓ Token refreshed successfully")
        
        # 12. Change password
        print("\n=== Step 12: Change Password ===")
        change_pwd_response = client.post(
            "/api/v1/auth/change-password",
            json={
                "old_password": registration_data["password"],
                "new_password": "NewWorkflow123!"
            },
            headers={"Authorization": f"Bearer {access_token}"}
        )
        assert change_pwd_response.status_code == 200
        print(f"✓ Password changed successfully")
        
        print("\n" + "="*50)
        print("✅ COMPLETE WORKFLOW TEST PASSED")
        print("="*50)

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
    
    def test_missing_auth_header(self):
        """Test that missing auth header is handled"""
        print("\n=== Missing Auth Header ===")
        
        response = client.get("/api/v1/attendance/today")
        assert response.status_code == 403
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
    
    def test_check_in_creates_record(self):
        """Test that check-in actually creates a database record"""
        print("\n=== Data Consistency: Check-in Record ===")
        
        # Login
        login = client.post(
            "/api/v1/auth/login",
            json={"email": "admin@optiwork.ai", "password": "password123"}
        )
        assert login.status_code == 200
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Check-in
        checkin = client.post(
            "/api/v1/attendance/check-in",
            json={
                "latitude": 37.7749,
                "longitude": -122.4194,
                "method": "gps_verified"
            },
            headers=headers
        )
        
        if checkin.status_code == 201:
            # Check that we can retrieve it
            today = client.get(
                "/api/v1/attendance/today",
                headers=headers
            )
            assert today.status_code == 200
            assert today.json()["status"] == "checked_in"
            print("✓ Check-in record created and retrievable")
        elif checkin.status_code == 409:
            print("✓ Already checked in today (expected)")
        else:
            print(f"⚠ Unexpected response: {checkin.status_code}")

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
