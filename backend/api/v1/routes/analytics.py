# backend/api/v1/routes/analytics.py - Analytics and reporting routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta

from core.database import get_db
from schemas import (
    EmployeeAnalyticsResponse, AttendanceChartData, 
    DepartmentAnalyticsResponse
)
from repositories import (
    AnalyticsRepository, AttendanceRepository, 
    EmployeeRepository
)
from api.v1.routes.auth import get_current_user

router = APIRouter(tags=["Analytics"])

# ============================================================================
# ANALYTICS ENDPOINTS
# ============================================================================

@router.get("/employee/{employee_id}", response_model=EmployeeAnalyticsResponse)
async def get_employee_analytics(
    employee_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get employee daily analytics"""
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Get today's logs
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    logs = AttendanceRepository.get_employee_logs(db, employee_id, days=1)
    
    total_hours = 0.0
    for log in logs:
        if log.check_out_time:
            delta = log.check_out_time - log.check_in_time
            total_hours += delta.total_seconds() / 3600
    
    return EmployeeAnalyticsResponse(
        employee_id=employee_id,
        date=today_start,
        hours_worked=total_hours,
        attendance_count=len(logs),
        on_time_count=len([l for l in logs if l.check_in_time.hour <= 9]),
        late_count=len([l for l in logs if l.check_in_time.hour > 9]),
        productivity_score=0.85
    )

@router.get("/department/{dept_id}", response_model=DepartmentAnalyticsResponse)
async def get_department_analytics(
    dept_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get department analytics"""
    
    employees = EmployeeRepository.list_dept_employees(db, dept_id)
    
    total_hours = 0.0
    for employee in employees:
        logs = AttendanceRepository.get_employee_logs(db, employee.id, days=1)
        for log in logs:
            if log.check_out_time:
                delta = log.check_out_time - log.check_in_time
                total_hours += delta.total_seconds() / 3600
    
    return DepartmentAnalyticsResponse(
        department_name=dept_id,
        total_employees=len(employees),
        present_today=len([e for e in employees if AttendanceRepository.get_today_check_in(db, e.id)]),
        average_hours=total_hours / len(employees) if employees else 0,
        productivity_score=0.82
    )

@router.get("/attendance-trend", response_model=List[AttendanceChartData])
async def get_attendance_trend(
    days: int = 7,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get attendance trend chart data"""
    
    trend_data = []
    
    for i in range(days):
        date = datetime.utcnow() - timedelta(days=i)
        date_start = date.replace(hour=0, minute=0, second=0, microsecond=0)
        date_end = date_start + timedelta(days=1)
        
        # Count attendance
        from sqlalchemy import and_
        from models import AttendanceLog
        
        present = db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.org_id == current_user.org_id,
                AttendanceLog.check_in_time >= date_start,
                AttendanceLog.check_in_time < date_end
            )
        ).count()
        
        employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
        absent = len(employees) - present
        late = 0  # Simplified
        
        trend_data.append(AttendanceChartData(
            date=date_start.isoformat(),
            present=present,
            absent=absent,
            late=late
        ))
    
    return sorted(trend_data, key=lambda x: x.date)

@router.get("/summary")
async def get_analytics_summary(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get analytics summary"""
    
    employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
    
    present_count = 0
    total_hours = 0.0
    
    for employee in employees:
        today_checkin = AttendanceRepository.get_today_check_in(db, employee.id)
        if today_checkin:
            present_count += 1
            if today_checkin.check_out_time:
                delta = today_checkin.check_out_time - today_checkin.check_in_time
                total_hours += delta.total_seconds() / 3600
    
    return {
        "total_employees": len(employees),
        "present_today": present_count,
        "absent_today": len(employees) - present_count,
        "average_hours_today": total_hours / present_count if present_count > 0 else 0,
        "average_productivity": 0.84
    }
