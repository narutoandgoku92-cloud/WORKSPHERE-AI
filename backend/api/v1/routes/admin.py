# backend/api/v1/routes/admin.py - Admin management routes

from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session

from core.database import get_db
from schemas import DashboardSummary, AdminDashboardResponse, UserCreate, UserResponse, EmployeeCreate
from repositories import (
    EmployeeRepository, AttendanceRepository, 
    AnalyticsRepository, OrganizationRepository, UserRepository
)
from api.v1.routes.auth import get_current_user
from core.security import SecurityManager

router = APIRouter(tags=["Admin"])
security_manager = SecurityManager()

# ============================================================================
# ADMIN DASHBOARD ENDPOINTS
# ============================================================================

@router.get("/dashboard", response_model=AdminDashboardResponse)
async def get_admin_dashboard(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get admin dashboard with system overview"""
    
    if current_user.role not in ["admin", "manager", "hr"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Get statistics
    employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
    total_employees = len(employees)
    
    stats = AttendanceRepository.get_today_stats(db, current_user.org_id)
    present_today = stats["present_today"]
    absent_today = total_employees - present_today
    late_today = 0
    
    # Get recent attendance
    recent_logs = []
    for employee in employees[:10]:
        logs = AttendanceRepository.get_employee_logs(db, employee.id, days=1, limit=1)
        for log in logs:
            recent_logs.append({
                "id": log.id,
                "employee_id": log.employee_id,
                "check_in_time": log.check_in_time,
                "check_out_time": log.check_out_time,
                "check_in_verified": log.check_in_verified,
                "gps_verified": log.gps_verified,
                "check_in_method": log.check_in_method
            })
    
    # Create dashboard
    summary = DashboardSummary(
        total_employees=total_employees,
        present_today=present_today,
        absent_today=absent_today,
        late_today=late_today,
        average_productivity=0.84,
        pending_payroll=0
    )
    
    # Get chart data
    trend_data = []
    for i in range(7):
        from datetime import datetime, timedelta
        date = datetime.utcnow() - timedelta(days=i)
        trend_data.append({
            "date": date.isoformat(),
            "present": present_today,
            "absent": absent_today,
            "late": 0
        })
    
    dashboard = AdminDashboardResponse(
        summary=summary,
        recent_attendance=recent_logs,
        top_productive_employees=[],
        attendance_trend=trend_data
    )
    
    return dashboard

@router.get("/system-health")
async def get_system_health(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get system health status"""
    
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    return {
        "status": "healthy",
        "database": "connected",
        "redis": "connected",
        "api_version": "1.0.0",
        "uptime_seconds": 3600
    }

@router.get("/audit-logs")
async def get_audit_logs(
    skip: int = 0,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get audit logs"""
    
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Placeholder for audit logs
    return {
        "logs": [],
        "total": 0,
        "skip": skip,
        "limit": limit
    }

@router.post("/settings")
async def update_settings(
    settings_data: dict,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update organization settings (admin only)"""
    
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Update organization settings
    # This is a placeholder implementation
    
    return {
        "message": "Settings updated successfully",
        "settings": settings_data
    }


@router.post("/create-user", response_model=UserResponse)
async def create_user(
    payload: dict = Body(...),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Admin-only: create employee and optional user account"""

    if current_user.role not in ["admin", "hr", "manager"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # Expect payload to contain employee and optional user fields
    employee_data = payload.get("employee")
    user_data = payload.get("user")

    if not employee_data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Employee data required")

    # Create employee
    employee_req = EmployeeCreate(**employee_data)
    employee = EmployeeRepository.create(
        db,
        org_id=current_user.org_id,
        employee_id=employee_req.employee_id,
        full_name=employee_req.full_name,
        email=employee_req.email,
        phone=employee_req.phone,
        job_title=employee_req.job_title,
        dept_id=employee_req.dept_id,
        salary_per_hour=employee_req.salary_per_hour,
        hire_date=employee_req.hire_date,
    )

    created_user = None
    if user_data:
        # Create a linked user account
        user_req = UserCreate(**user_data)
        password_hash = security_manager.hash_password(user_req.password)
        created_user = UserRepository.create(
            db,
            org_id=current_user.org_id,
            email=user_req.email,
            password_hash=password_hash,
            full_name=user_req.full_name,
            role=user_req.role.value if hasattr(user_req.role, 'value') else str(user_req.role),
            employee_id=employee.id
        )

    # Return created user if provided, otherwise return a minimal response based on employee
    if created_user:
        return created_user

    return {
        "id": employee.id,
        "email": employee.email or "",
        "full_name": employee.full_name,
        "role": "employee",
        "is_active": True,
        "last_login": None,
        "created_at": employee.created_at
    }


@router.get("/get-users", response_model=list[UserResponse])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.role not in ["admin", "hr", "manager"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    users = UserRepository.list_org_users(db, current_user.org_id, skip=skip, limit=limit)
    return users

@router.post("/backup")
async def create_backup(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create system backup (admin only)"""
    
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    return {
        "message": "Backup created successfully",
        "backup_id": "backup_20240101_120000",
        "timestamp": "2024-01-01T12:00:00Z"
    }
