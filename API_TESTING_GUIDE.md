# WorkSphere AI - API Testing Guide

This guide demonstrates how to test the WorkSphere AI API endpoints using curl, Postman, or the built-in Swagger UI.

## 🌐 Quick Access

- **Swagger UI (Interactive)**: http://localhost:8000/api/docs
- **ReDoc (Documentation)**: http://localhost:8000/api/redoc
- **OpenAPI Schema**: http://localhost:8000/api/openapi.json

---

## 🔐 Authentication Flow

### 1. Register New User

**Endpoint**: `POST /api/v1/auth/register`

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@optiwork.ai",
    "password": "SecurePassword123!",
    "full_name": "John Doe",
    "organization_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

**Response** (201 Created):
```json
{
  "id": "user_id",
  "email": "john@optiwork.ai",
  "full_name": "John Doe",
  "role": "employee",
  "is_active": true
}
```

### 2. Login & Get Tokens

**Endpoint**: `POST /api/v1/auth/login`

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@optiwork.ai",
    "password": "password123"
  }'
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "admin@optiwork.ai",
    "full_name": "Admin User",
    "role": "admin",
    "org_id": "550e8400-e29b-41d4-a716-446655440001",
    "is_active": true
  }
}
```

### 3. Refresh Token

**Endpoint**: `POST /api/v1/auth/refresh`

```bash
curl -X POST http://localhost:8000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_REFRESH_TOKEN" \
  -d '{}'
```

### 4. Change Password

**Endpoint**: `POST /api/v1/auth/change-password`

```bash
curl -X POST http://localhost:8000/api/v1/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "old_password": "password123",
    "new_password": "NewPassword123!"
  }'
```

---

## 👥 User Management

### List All Users (Admin Only)

**Endpoint**: `GET /api/v1/users`

```bash
curl -X GET http://localhost:8000/api/v1/users \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Get User Details

**Endpoint**: `GET /api/v1/users/{user_id}`

```bash
curl -X GET http://localhost:8000/api/v1/users/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Update User

**Endpoint**: `PUT /api/v1/users/{user_id}`

```bash
curl -X PUT http://localhost:8000/api/v1/users/550e8400-e29b-41d4-a716-446655440000 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "full_name": "John Updated",
    "is_active": true,
    "role": "manager"
  }'
```

### Delete User (Admin Only)

**Endpoint**: `DELETE /api/v1/users/{user_id}`

```bash
curl -X DELETE http://localhost:8000/api/v1/users/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 👨‍💼 Employee Management

### Create Employee

**Endpoint**: `POST /api/v1/employees`

```bash
curl -X POST http://localhost:8000/api/v1/employees \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "employee_id": "EMP001",
    "full_name": "Jane Smith",
    "email": "jane@company.com",
    "phone": "+1234567890",
    "job_title": "Software Engineer",
    "salary_per_hour": 50.00,
    "department_id": "550e8400-e29b-41d4-a716-446655440002",
    "hire_date": "2024-01-15"
  }'
```

### List Employees

**Endpoint**: `GET /api/v1/employees`

```bash
# Get all employees
curl -X GET http://localhost:8000/api/v1/employees \
  -H "Authorization: Bearer ACCESS_TOKEN"

# Filter by department
curl -X GET "http://localhost:8000/api/v1/employees?department_id=550e8400-e29b-41d4-a716-446655440002" \
  -H "Authorization: Bearer ACCESS_TOKEN"

# Pagination
curl -X GET "http://localhost:8000/api/v1/employees?skip=0&limit=10" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Get Employee Details

**Endpoint**: `GET /api/v1/employees/{employee_id}`

```bash
curl -X GET http://localhost:8000/api/v1/employees/550e8400-e29b-41d4-a716-446655440003 \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Update Employee

**Endpoint**: `PUT /api/v1/employees/{employee_id}`

```bash
curl -X PUT http://localhost:8000/api/v1/employees/550e8400-e29b-41d4-a716-446655440003 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "job_title": "Senior Software Engineer",
    "salary_per_hour": 65.00,
    "status": "active"
  }'
```

### Upload Employee Photo

**Endpoint**: `POST /api/v1/employees/{employee_id}/upload-photo`

```bash
curl -X POST http://localhost:8000/api/v1/employees/550e8400-e29b-41d4-a716-446655440003/upload-photo \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -F "file=@/path/to/photo.jpg"
```

---

## 🕐 Attendance Management

### Employee Check-In

**Endpoint**: `POST /api/v1/attendance/check-in`

```bash
curl -X POST http://localhost:8000/api/v1/attendance/check-in \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "method": "gps_verified",
    "face_verified": true,
    "liveness_verified": true
  }'
```

### Employee Check-Out

**Endpoint**: `POST /api/v1/attendance/check-out`

```bash
curl -X POST http://localhost:8000/api/v1/attendance/check-out \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "notes": "Project completed"
  }'
```

### Get Today's Attendance Stats

**Endpoint**: `GET /api/v1/attendance/today`

```bash
curl -X GET http://localhost:8000/api/v1/attendance/today \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

**Response**:
```json
{
  "date": "2024-01-20",
  "check_in_time": "2024-01-20T09:00:00Z",
  "check_out_time": null,
  "hours_worked": 0,
  "status": "checked_in",
  "location_verified": true
}
```

### Get Employee Attendance History

**Endpoint**: `GET /api/v1/attendance/employee/{employee_id}`

```bash
curl -X GET "http://localhost:8000/api/v1/attendance/employee/550e8400-e29b-41d4-a716-446655440003?days=30" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 🔐 Face Recognition

### Enroll Face

**Endpoint**: `POST /api/v1/face-recognition/enroll`

```bash
curl -X POST http://localhost:8000/api/v1/face-recognition/enroll \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "face_id": "550e8400-e29b-41d4-a716-446655440004"
  }'
```

### Verify Face

**Endpoint**: `POST /api/v1/face-recognition/verify`

```bash
curl -X POST http://localhost:8000/api/v1/face-recognition/verify \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "face_id": "550e8400-e29b-41d4-a716-446655440004"
  }'
```

**Response**:
```json
{
  "verified": true,
  "confidence": 0.95,
  "match_score": 0.92
}
```

---

## 📍 GPS & Geofence

### Log Location

**Endpoint**: `POST /api/v1/gps/location`

```bash
curl -X POST http://localhost:8000/api/v1/gps/location \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 5.5,
    "timestamp": "2024-01-20T09:15:00Z"
  }'
```

### Get Latest Location

**Endpoint**: `GET /api/v1/gps/location/latest`

```bash
curl -X GET http://localhost:8000/api/v1/gps/location/latest \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Validate Location in Geofence

**Endpoint**: `POST /api/v1/gps/validate`

```bash
curl -X POST http://localhost:8000/api/v1/gps/validate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "geofence_id": "550e8400-e29b-41d4-a716-446655440005"
  }'
```

**Response**:
```json
{
  "is_inside": true,
  "distance_meters": 120.5
}
```

### Create Geofence

**Endpoint**: `POST /api/v1/gps/geofence`

```bash
curl -X POST http://localhost:8000/api/v1/gps/geofence \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "name": "Office HQ",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "radius_meters": 500,
    "is_active": true
  }'
```

### List Geofences

**Endpoint**: `GET /api/v1/gps/geofences`

```bash
curl -X GET http://localhost:8000/api/v1/gps/geofences \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 📊 Analytics

### Get Employee Analytics

**Endpoint**: `GET /api/v1/analytics/employee/{employee_id}`

```bash
curl -X GET "http://localhost:8000/api/v1/analytics/employee/550e8400-e29b-41d4-a716-446655440003?days=30" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

**Response**:
```json
{
  "employee_id": "550e8400-e29b-41d4-a716-446655440003",
  "total_hours": 160,
  "days_present": 20,
  "days_absent": 0,
  "on_time_count": 18,
  "late_count": 2,
  "avg_check_in_delay_minutes": 5.5,
  "productivity_score": 92.5
}
```

### Get Department Analytics

**Endpoint**: `GET /api/v1/analytics/department/{department_id}`

```bash
curl -X GET "http://localhost:8000/api/v1/analytics/department/550e8400-e29b-41d4-a716-446655440002?days=30" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Get Attendance Trends

**Endpoint**: `GET /api/v1/analytics/attendance-trend`

```bash
curl -X GET "http://localhost:8000/api/v1/analytics/attendance-trend?days=30" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Get Analytics Summary

**Endpoint**: `GET /api/v1/analytics/summary`

```bash
curl -X GET http://localhost:8000/api/v1/analytics/summary \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 💰 Payroll

### Get Current Payroll

**Endpoint**: `GET /api/v1/payroll/current`

```bash
curl -X GET http://localhost:8000/api/v1/payroll/current \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

**Response**:
```json
{
  "employee_id": "550e8400-e29b-41d4-a716-446655440003",
  "period_start": "2024-01-01",
  "period_end": "2024-01-31",
  "total_hours": 160,
  "overtime_hours": 5,
  "base_salary": 8000.00,
  "overtime_pay": 375.00,
  "total_pay": 8375.00
}
```

### Calculate Payroll

**Endpoint**: `POST /api/v1/payroll/calculate`

```bash
curl -X POST http://localhost:8000/api/v1/payroll/calculate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "start_date": "2024-01-01",
    "end_date": "2024-01-31"
  }'
```

---

## 🔧 Admin Functions

### Get Dashboard Summary

**Endpoint**: `GET /api/v1/admin/dashboard`

```bash
curl -X GET http://localhost:8000/api/v1/admin/dashboard \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

**Response**:
```json
{
  "total_employees": 50,
  "present_today": 48,
  "absent_today": 2,
  "on_time_today": 45,
  "late_today": 3,
  "recent_attendance": [...]
}
```

### Get System Health

**Endpoint**: `GET /api/v1/admin/system-health`

```bash
curl -X GET http://localhost:8000/api/v1/admin/system-health \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Get Audit Logs

**Endpoint**: `GET /api/v1/admin/audit-logs`

```bash
curl -X GET "http://localhost:8000/api/v1/admin/audit-logs?skip=0&limit=50" \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

### Trigger System Backup

**Endpoint**: `POST /api/v1/admin/backup`

```bash
curl -X POST http://localhost:8000/api/v1/admin/backup \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 🧪 Testing with Postman

### Import Collection

1. Open Postman
2. Click "Import" → "Link"
3. Paste: `http://localhost:8000/api/openapi.json`
4. Click "Generate from OpenAPI 3.0"

### Set Environment Variables

Create a Postman environment with:
- `base_url`: `http://localhost:8000`
- `token`: (obtained from login endpoint)
- `employee_id`: (UUID from employee creation)

### Save Common Requests

Create a collection with pre-configured requests for:
- Login (stores token automatically)
- Check-in/Check-out
- Get Analytics
- View Payroll

---

## ⚠️ Common Errors

### 401 Unauthorized
**Problem**: Token not provided or expired
**Solution**: 
```bash
# Get new token
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@optiwork.ai","password":"password123"}'

# Use token in Authorization header
-H "Authorization: Bearer YOUR_NEW_TOKEN"
```

### 403 Forbidden
**Problem**: User doesn't have permission for this action
**Solution**: Use an admin account or appropriate role

### 404 Not Found
**Problem**: Resource doesn't exist
**Solution**: Verify the ID exists with GET request first

### 422 Unprocessable Entity
**Problem**: Invalid request body
**Solution**: Check JSON format and required fields in API docs

---

## 📚 Additional Resources

- [Full API Documentation](API_DOCUMENTATION.md)
- [Architecture Guide](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)

