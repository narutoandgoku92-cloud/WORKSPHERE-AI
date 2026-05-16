# OptiWork AI - API Documentation

**Version:** 1.0  
**Base URL:** `https://api.optiwork.ai/v1`  
**Authentication:** JWT Bearer Token

---

## TABLE OF CONTENTS

1. [Authentication APIs](#authentication-apis)
2. [User Management APIs](#user-management-apis)
3. [Attendance APIs](#attendance-apis)
4. [Facial Recognition APIs](#facial-recognition-apis)
5. [GPS & Geofencing APIs](#gps--geofencing-apis)
6. [Analytics APIs](#analytics-apis)
7. [Payroll APIs](#payroll-apis)
8. [Admin APIs](#admin-apis)
9. [Error Handling](#error-handling)
10. [Rate Limiting](#rate-limiting)

---

## AUTHENTICATION APIs

### POST /auth/login
Employee/Admin login with credentials.

**Request:**
```json
{
  "email": "user@company.com",
  "password": "secure_password",
  "device_id": "device_uuid_xyz",
  "remember_device": true
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@company.com",
    "first_name": "John",
    "last_name": "Doe",
    "role": "EMPLOYEE",
    "organization_id": "550e8400-e29b-41d4-a716-446655440001",
    "avatar_url": "https://s3.aws.com/optiwork/avatars/user.jpg"
  },
  "mfa_required": false,
  "expires_in": 900
}
```

**Error Responses:**
- 401: Invalid credentials
- 429: Too many login attempts
- 422: Email not verified

---

### POST /auth/biometric-login
Login using biometric (fingerprint/face).

**Request:**
```json
{
  "device_id": "device_uuid_xyz",
  "biometric_type": "fingerprint",
  "biometric_token": "encrypted_biometric_hash"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {...},
  "expires_in": 900
}
```

---

### POST /auth/refresh-token
Refresh access token using refresh token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 900
}
```

---

### POST /auth/logout
Logout and invalidate tokens.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (204 No Content)**

---

### POST /auth/register
Register new employee account.

**Request:**
```json
{
  "email": "user@company.com",
  "password": "secure_password",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1-555-123-4567",
  "organization_code": "ORG123",
  "invite_token": "optional_invite_token"
}
```

**Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@company.com",
  "first_name": "John",
  "last_name": "Doe",
  "email_verified": false,
  "verification_email_sent": true
}
```

---

### POST /auth/verify-email
Verify email with token.

**Request:**
```json
{
  "email": "user@company.com",
  "verification_token": "verification_token_xyz"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Email verified successfully"
}
```

---

### POST /auth/request-password-reset
Request password reset email.

**Request:**
```json
{
  "email": "user@company.com"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password reset link sent to email"
}
```

---

### POST /auth/reset-password
Reset password with token.

**Request:**
```json
{
  "email": "user@company.com",
  "reset_token": "reset_token_xyz",
  "new_password": "new_secure_password"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

---

## USER MANAGEMENT APIs

### GET /users/profile
Get current user profile.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@company.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1-555-123-4567",
  "avatar_url": "https://s3.aws.com/optiwork/avatars/user.jpg",
  "organization": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Acme Corporation"
  },
  "department": {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "name": "Engineering"
  },
  "role": "EMPLOYEE",
  "job_title": "Software Engineer",
  "employment_type": "full_time",
  "start_date": "2023-01-15",
  "biometric_enrolled": true,
  "face_enrollment_status": "VERIFIED",
  "mfa_enabled": false,
  "timezone": "America/New_York",
  "created_at": "2023-01-15T10:30:00Z",
  "updated_at": "2024-05-13T14:22:00Z"
}
```

---

### PUT /users/profile
Update user profile.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

**Request:**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1-555-123-4567",
  "timezone": "America/New_York"
}
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1-555-123-4567",
  "timezone": "America/New_York",
  "updated_at": "2024-05-13T14:22:00Z"
}
```

---

### PUT /users/password
Change password.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Request:**
```json
{
  "current_password": "current_password",
  "new_password": "new_secure_password"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

---

### POST /users/enable-mfa
Enable two-factor authentication.

**Response (200 OK):**
```json
{
  "secret": "JBSWY3DPEBLW64TMMQ======",
  "qr_code_url": "https://chart.googleapis.com/chart?cht=qr&chl=...",
  "backup_codes": ["XXXX-XXXX", "YYYY-YYYY"],
  "message": "Scan QR code with your authenticator app"
}
```

---

### POST /users/verify-mfa
Verify MFA setup.

**Request:**
```json
{
  "mfa_code": "123456"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "MFA enabled successfully"
}
```

---

### GET /users/devices
List all connected devices.

**Response (200 OK):**
```json
{
  "devices": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "device_name": "iPhone 13",
      "device_type": "mobile",
      "os_type": "iOS",
      "os_version": "16.3",
      "app_version": "1.0.0",
      "is_active": true,
      "last_activity_at": "2024-05-13T14:22:00Z",
      "created_at": "2024-05-01T10:30:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "device_name": "Chrome Web",
      "device_type": "web",
      "os_type": "Windows",
      "os_version": "10",
      "app_version": "latest",
      "is_active": true,
      "last_activity_at": "2024-05-13T16:00:00Z",
      "created_at": "2024-05-10T09:15:00Z"
    }
  ]
}
```

---

### DELETE /users/devices/{device_id}
Remove a device session.

**Response (204 No Content)**

---

## ATTENDANCE APIs

### POST /attendance/clock-in
Clock in with facial recognition.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: multipart/form-data
```

**Request (Multipart):**
```
- face_image: [binary image data]
- latitude: 40.7128
- longitude: -74.0060
- device_id: device_uuid_xyz
```

**Response (200 OK):**
```json
{
  "status": "success",
  "attendance_id": "550e8400-e29b-41d4-a716-446655440000",
  "clock_in_time": "2024-05-13T09:00:00Z",
  "verification": {
    "method": "FACE",
    "confidence_score": 0.9876,
    "liveness_passed": true,
    "geofence_verified": true
  },
  "message": "Clocked in successfully"
}
```

**Error Responses:**
- 400: Face not recognized
- 400: Outside geofence
- 400: Liveness check failed
- 409: Already clocked in

---

### POST /attendance/clock-out
Clock out.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Request:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "notes": "Optional notes"
}
```

**Response (200 OK):**
```json
{
  "status": "success",
  "attendance_id": "550e8400-e29b-41d4-a716-446655440000",
  "clock_out_time": "2024-05-13T17:30:00Z",
  "total_hours": 8.5,
  "overtime_hours": 0.5,
  "message": "Clocked out successfully"
}
```

---

### GET /attendance/today
Get today's attendance record.

**Response (200 OK):**
```json
{
  "attendance_id": "550e8400-e29b-41d4-a716-446655440000",
  "date": "2024-05-13",
  "clock_in_time": "2024-05-13T09:00:00Z",
  "clock_out_time": "2024-05-13T17:30:00Z",
  "status": "PRESENT",
  "total_hours": 8.5,
  "break_duration": 60,
  "clock_in_location": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "geofence_name": "Headquarters"
  },
  "verification_method": "FACE"
}
```

---

### GET /attendance/history?month=2024-05&limit=30&offset=0
Get attendance history.

**Query Parameters:**
- `month`: YYYY-MM format
- `limit`: Default 30, Max 100
- `offset`: Pagination offset
- `status`: Filter by status (PRESENT, ABSENT, LATE, etc.)

**Response (200 OK):**
```json
{
  "total": 21,
  "records": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "date": "2024-05-13",
      "clock_in_time": "2024-05-13T09:00:00Z",
      "clock_out_time": "2024-05-13T17:30:00Z",
      "status": "PRESENT",
      "total_hours": 8.5,
      "verification_method": "FACE"
    }
  ],
  "pagination": {
    "limit": 30,
    "offset": 0,
    "total": 21
  }
}
```

---

### GET /attendance/{user_id}/analytics
Get user attendance analytics.

**Response (200 OK):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "month": "2024-05",
  "summary": {
    "total_days": 22,
    "present_days": 20,
    "absent_days": 1,
    "late_days": 1,
    "on_leave_days": 0,
    "attendance_rate": 0.9545,
    "punctuality_rate": 0.9545
  },
  "hours": {
    "total_hours": 160.5,
    "average_daily_hours": 8.025,
    "overtime_hours": 0.5,
    "total_break_time": 1200
  },
  "trends": {
    "consistency_score": 0.92,
    "trend": "improving"
  }
}
```

---

## FACIAL RECOGNITION APIs

### POST /face-recognition/enroll
Enroll user face for recognition.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: multipart/form-data
```

**Request (Multipart):**
```
- face_images: [binary image data] (1-3 images)
- enrollment_method: "mobile_app"
```

**Response (201 Created):**
```json
{
  "enrollment_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "PENDING",
  "quality_scores": [0.92, 0.95, 0.89],
  "message": "Face enrollment submitted for verification"
}
```

---

### GET /face-recognition/enrollment-status
Check face enrollment status.

**Response (200 OK):**
```json
{
  "enrollment_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "VERIFIED",
  "verified_at": "2024-05-12T14:30:00Z",
  "verified_by": "admin@company.com",
  "quality_score": 0.95,
  "created_at": "2024-05-12T10:00:00Z"
}
```

---

### POST /face-recognition/verify
Verify face for attendance (real-time).

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: multipart/form-data
```

**Request (Multipart):**
```
- face_image: [binary image data]
```

**Response (200 OK):**
```json
{
  "matched": true,
  "confidence_score": 0.9876,
  "enrollment_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "550e8400-e29b-41d4-a716-446655440001",
  "user_name": "John Doe",
  "liveness_passed": true,
  "liveness_score": 0.98,
  "processing_time_ms": 320
}
```

---

### DELETE /face-recognition/enrollment
Delete face enrollment.

**Response (204 No Content)**

---

## GPS & GEOFENCING APIs

### POST /gps/location-update
Submit real-time location update.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Request:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 5.5,
  "altitude": 10.2,
  "speed": 1.5,
  "heading": 45.2,
  "device_id": "device_uuid_xyz",
  "timestamp": "2024-05-13T14:22:00Z"
}
```

**Response (201 Created):**
```json
{
  "location_id": "550e8400-e29b-41d4-a716-446655440000",
  "recorded_at": "2024-05-13T14:22:00Z",
  "is_valid": true,
  "is_mock_location": false
}
```

---

### GET /gps/current-location
Get current user location.

**Response (200 OK):**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 5.5,
  "altitude": 10.2,
  "speed": 0,
  "heading": 45.2,
  "recorded_at": "2024-05-13T14:22:00Z",
  "geofence": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Headquarters",
    "is_within": true,
    "distance_meters": 45
  }
}
```

---

### GET /gps/location-history?start_date=2024-05-13&end_date=2024-05-13&limit=100
Get location history.

**Query Parameters:**
- `start_date`: Start date (YYYY-MM-DD)
- `end_date`: End date (YYYY-MM-DD)
- `limit`: Max records (default 100)

**Response (200 OK):**
```json
{
  "total": 50,
  "locations": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "accuracy": 5.5,
      "recorded_at": "2024-05-13T14:22:00Z"
    }
  ]
}
```

---

### POST /gps/geofence-check
Check if user is within any geofence.

**Request:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060
}
```

**Response (200 OK):**
```json
{
  "is_within_geofence": true,
  "matched_geofences": [
    {
      "geofence_id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Headquarters",
      "distance_meters": 45
    }
  ]
}
```

---

## ANALYTICS APIs

### GET /analytics/dashboard?period=today
Get analytics dashboard.

**Query Parameters:**
- `period`: today, this_week, this_month, custom
- `start_date`: For custom period
- `end_date`: For custom period

**Response (200 OK):**
```json
{
  "period": "today",
  "generated_at": "2024-05-13T16:00:00Z",
  "summary": {
    "total_employees": 250,
    "present_today": 248,
    "absent_today": 2,
    "on_leave_today": 0,
    "attendance_rate": 0.992,
    "avg_productivity_score": 0.87,
    "critical_alerts": 3
  },
  "department_breakdown": [
    {
      "department": "Engineering",
      "total": 50,
      "present": 49,
      "absent": 1,
      "avg_productivity": 0.89
    }
  ],
  "alerts": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "type": "understaffing",
      "severity": "high",
      "message": "Engineering team understaffed tomorrow",
      "recommendation": "Approve overtime for 2 employees"
    }
  ]
}
```

---

### GET /analytics/productivity?user_id=xxx&period=this_month
Get productivity metrics.

**Response (200 OK):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "period": "this_month",
  "metrics": {
    "productivity_score": 0.876,
    "attendance_reliability": 0.95,
    "shift_efficiency": 0.92,
    "task_completion_rate": 0.88,
    "consistency_index": 0.84
  },
  "daily_breakdown": [
    {
      "date": "2024-05-13",
      "score": 0.89,
      "hours": 8.5,
      "tasks_completed": 12
    }
  ],
  "trend": "improving",
  "burnout_risk": "low"
}
```

---

### GET /analytics/predictions
Get AI predictions and insights.

**Response (200 OK):**
```json
{
  "predictions": {
    "understaffing": {
      "probability": 0.75,
      "predicted_date": "2024-05-20",
      "affected_department": "Warehouse",
      "recommendation": "Start hiring process or arrange overtime"
    },
    "high_performers": {
      "count": 15,
      "employees": [
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "name": "John Doe",
          "productivity_score": 0.95
        }
      ]
    },
    "burnout_risk": {
      "high_risk_count": 5,
      "medium_risk_count": 12,
      "recommendations": [
        "Schedule wellness check-ins",
        "Reduce overtime assignments"
      ]
    }
  }
}
```

---

## PAYROLL APIs

### GET /payroll/salary-structure
Get user salary structure.

**Response (200 OK):**
```json
{
  "assignment_id": "550e8400-e29b-41d4-a716-446655440000",
  "base_salary": 5000,
  "hourly_rate": 30.5,
  "overtime_multiplier": 1.5,
  "currency": "USD",
  "effective_from": "2024-01-01",
  "allowances": {
    "housing": 500,
    "transport": 200,
    "meal": 150
  },
  "deductions": {
    "insurance": 100,
    "loan": 50
  }
}
```

---

### POST /payroll/payroll-run
Create payroll run (Admin only).

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Admin-Token: admin_secret_token
```

**Request:**
```json
{
  "payroll_month": "2024-05",
  "period_start": "2024-05-01",
  "period_end": "2024-05-31"
}
```

**Response (201 Created):**
```json
{
  "payroll_run_id": "550e8400-e29b-41d4-a716-446655440000",
  "payroll_month": "2024-05",
  "status": "DRAFT",
  "total_employees": 250,
  "created_at": "2024-05-13T14:22:00Z"
}
```

---

### GET /payroll/payslip/{payroll_id}
Get payslip PDF.

**Response (200 OK with PDF):**
```
Content-Type: application/pdf
Content-Disposition: attachment; filename="payslip_2024_05.pdf"
```

---

### POST /payroll/export-payroll
Export payroll data (Admin only).

**Request:**
```json
{
  "payroll_run_id": "550e8400-e29b-41d4-a716-446655440000",
  "format": "csv"
}
```

**Response (200 OK with CSV):**
```
Content-Type: text/csv
Content-Disposition: attachment; filename="payroll_2024_05.csv"
```

---

## ADMIN APIs

### GET /admin/users?limit=50&offset=0&role=EMPLOYEE&department_id=xxx
List all users (Admin only).

**Response (200 OK):**
```json
{
  "total": 250,
  "users": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@company.com",
      "first_name": "John",
      "last_name": "Doe",
      "role": "EMPLOYEE",
      "department": "Engineering",
      "status": "ACTIVE",
      "last_login": "2024-05-13T14:22:00Z"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "total": 250
  }
}
```

---

### POST /admin/users
Create new user (Admin only).

**Request:**
```json
{
  "email": "user@company.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1-555-123-4567",
  "role": "EMPLOYEE",
  "department_id": "550e8400-e29b-41d4-a716-446655440000",
  "job_title": "Software Engineer",
  "employment_type": "full_time",
  "monthly_salary": 5000
}
```

**Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@company.com",
  "invitation_sent": true
}
```

---

### GET /admin/audit-logs?limit=100&action=LOGIN&resource_type=user
Get audit logs (Admin only).

**Response (200 OK):**
```json
{
  "logs": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "user": "admin@company.com",
      "action": "LOGIN",
      "resource_type": "user",
      "ip_address": "192.168.1.1",
      "timestamp": "2024-05-13T14:22:00Z",
      "status": "success"
    }
  ]
}
```

---

### GET /admin/system-health
Get system health status (Admin only).

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2024-05-13T16:00:00Z",
  "components": {
    "database": {
      "status": "healthy",
      "response_time_ms": 2
    },
    "cache": {
      "status": "healthy",
      "response_time_ms": 1
    },
    "ai_service": {
      "status": "healthy",
      "response_time_ms": 150
    },
    "storage": {
      "status": "healthy",
      "available_gb": 1500
    }
  },
  "active_users": 145,
  "api_requests_per_minute": 2540
}
```

---

## ERROR HANDLING

### Standard Error Response

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ],
    "timestamp": "2024-05-13T14:22:00Z",
    "request_id": "req_550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### Error Codes

| Code | HTTP | Meaning |
|------|------|---------|
| VALIDATION_ERROR | 422 | Input validation failed |
| UNAUTHORIZED | 401 | Missing or invalid token |
| FORBIDDEN | 403 | Insufficient permissions |
| NOT_FOUND | 404 | Resource not found |
| CONFLICT | 409 | Resource conflict (e.g., already clocked in) |
| RATE_LIMITED | 429 | Too many requests |
| SERVER_ERROR | 500 | Internal server error |
| SERVICE_UNAVAILABLE | 503 | Service temporarily unavailable |

---

## RATE LIMITING

### Rate Limit Headers

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1620000000
```

### Default Limits

| Endpoint Category | Limit | Window |
|------------------|-------|--------|
| Auth | 10 | per minute |
| Attendance | 100 | per hour |
| Analytics | 60 | per minute |
| Admin | 300 | per hour |
| General | 1000 | per hour |

---

**API Version:** 1.0  
**Last Updated:** May 2026  
**Status:** Production Ready
