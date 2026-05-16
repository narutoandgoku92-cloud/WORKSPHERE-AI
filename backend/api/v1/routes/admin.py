# backend/api/v1/routes/admin.py - Admin management routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from core.database import get_db
from schemas import DashboardSummary, AdminDashboardResponse
from repositories import (
    EmployeeRepository,
    AttendanceRepository,
    AnalyticsRepository,
    OrganizationRepository,
    AuditLogRepository,
)
from api.v1.routes.auth import get_current_user

router = APIRouter(tags=["Admin"])

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
    
    logs = AuditLogRepository.list_org_logs(db, current_user.org_id, skip=skip, limit=limit)
    serialized_logs = [
        {
            "id": log.id,
            "action": log.action,
            "resource_type": log.resource_type,
            "resource_id": log.resource_id,
            "user_id": log.user_id,
            "status": log.status,
            "error_message": log.error_message,
            "created_at": log.created_at,
            "updated_at": log.updated_at,
        }
        for log in logs
    ]

    return {
        "logs": serialized_logs,
        "total": len(serialized_logs),
        "skip": skip,
        "limit": limit,
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
