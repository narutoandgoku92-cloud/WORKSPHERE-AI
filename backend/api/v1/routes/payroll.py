# backend/api/v1/routes/payroll.py - Payroll and compensation routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List
from datetime import datetime, timedelta

from core.database import get_db
from schemas import (
    PayrollRecordResponse, PayrollSummaryResponse, 
    PayrollReportRequest
)
from repositories import (
    PayrollRepository, EmployeeRepository, 
    AttendanceRepository
)
from models import AttendanceLog
from api.v1.routes.auth import get_current_user

router = APIRouter(tags=["Payroll"])

# ============================================================================
# PAYROLL ENDPOINTS
# ============================================================================

@router.get("/current", response_model=PayrollSummaryResponse)
async def get_current_payroll(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current payroll estimation"""
    
    employee = EmployeeRepository.get_by_user_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Calculate hours for current month
    month_start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    today = datetime.utcnow()
    
    logs = AttendanceRepository.get_employee_logs(db, employee.id, days=(today - month_start).days + 1)
    
    total_hours = 0.0
    for log in logs:
        if log.check_out_time:
            delta = log.check_out_time - log.check_in_time
            total_hours += delta.total_seconds() / 3600
    
    daily_rate = employee.salary_per_hour * 8  # 8 hour workday
    estimated_salary = total_hours * employee.salary_per_hour
    
    return PayrollSummaryResponse(
        employee_name=employee.full_name,
        regular_hours=total_hours,
        overtime_hours=max(0, total_hours - (len(logs) * 8)),
        daily_rate=daily_rate,
        estimated_salary=estimated_salary,
        last_payment_date=None
    )

@router.post("/calculate")
async def calculate_payroll(
    request: PayrollReportRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Calculate payroll for period"""
    
    if current_user.role not in ["admin", "hr"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Get employees
    if request.department_id:
        from repositories import EmployeeRepository
        employees = EmployeeRepository.list_dept_employees(db, request.department_id)
    else:
        employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
    
    payroll_records = []
    total_payroll = 0.0
    
    for employee in employees:
        # Get attendance logs for period
        logs = db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.employee_id == employee.id,
                AttendanceLog.check_in_time >= request.period_start,
                AttendanceLog.check_in_time <= request.period_end
            )
        ).all()
        
        total_hours = 0.0
        for log in logs:
            if log.check_out_time:
                delta = log.check_out_time - log.check_in_time
                total_hours += delta.total_seconds() / 3600
        
        # Calculate pay
        regular_hours = min(total_hours, len(logs) * 8)
        overtime_hours = max(0, total_hours - regular_hours)
        regular_pay = regular_hours * employee.salary_per_hour
        overtime_pay = overtime_hours * employee.salary_per_hour * 1.5
        total_pay = regular_pay + overtime_pay
        
        payroll_records.append({
            "employee_id": employee.id,
            "employee_name": employee.full_name,
            "regular_hours": regular_hours,
            "overtime_hours": overtime_hours,
            "regular_pay": regular_pay,
            "overtime_pay": overtime_pay,
            "total_pay": total_pay
        })
        
        total_payroll += total_pay
    
    return {
        "period_start": request.period_start,
        "period_end": request.period_end,
        "employee_count": len(employees),
        "payroll_records": payroll_records,
        "total_payroll": total_payroll
    }

@router.get("/export-report")
async def export_payroll_report(
    period_start: datetime,
    period_end: datetime,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Export payroll report (CSV/PDF)"""
    
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    return {
        "message": "Payroll report export",
        "format": "csv",
        "filename": f"payroll_{period_start.date()}_{period_end.date()}.csv"
    }
