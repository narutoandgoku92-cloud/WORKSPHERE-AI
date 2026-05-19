# CRITICAL FIX #4: Production-Grade Payroll Calculation
# backend/services/payroll_service.py - Accurate payroll computation

from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import Dict, List, Any, Optional
from enum import Enum
import logging

logger = logging.getLogger(__name__)

class PayrollStatus(str, Enum):
    DRAFT = "draft"
    PENDING_APPROVAL = "pending_approval"
    APPROVED = "approved"
    PROCESSING = "processing"
    PAID = "paid"
    FAILED = "failed"

class PayrollCalculationService:
    """Production-grade payroll calculation engine"""
    
    # Configuration
    STANDARD_WORKDAY_HOURS = Decimal("8.0")
    STANDARD_WORKWEEK_HOURS = Decimal("40.0")
    OVERTIME_MULTIPLIER = Decimal("1.5")
    
    # Tax configuration
    FEDERAL_TAX_RATE = Decimal("0.12")  # 12% federal
    STATE_TAX_RATE = Decimal("0.05")    # 5% state (vary by state)
    FICA_RATE = Decimal("0.0765")       # 7.65% (SS + Medicare combined)
    
    # Deductions
    HEALTH_INSURANCE_MONTHLY = Decimal("200.00")
    RETIREMENT_CONTRIBUTION_RATE = Decimal("0.03")  # 3% of gross
    
    # Unpaid time
    LUNCH_BREAK_MINUTES = 60  # Unpaid lunch
    BREAK_TIME_MINUTES = 15   # Unpaid breaks (per 4 hours)
    
    # Company holidays (hardcoded - should be in database)
    HOLIDAYS = {
        (1, 1): "New Year's Day",
        (7, 4): "Independence Day",
        (11, 23): "Thanksgiving",
        (12, 25): "Christmas",
    }
    
    def __init__(self, db):
        self.db = db
    
    @staticmethod
    def is_weekend(date_obj: date) -> bool:
        """Check if date is weekend (Saturday=5, Sunday=6)"""
        return date_obj.weekday() >= 5
    
    @staticmethod
    def is_holiday(date_obj: date) -> bool:
        """Check if date is company holiday"""
        return (date_obj.month, date_obj.day) in PayrollCalculationService.HOLIDAYS
    
    @staticmethod
    def is_business_day(date_obj: date) -> bool:
        """Check if date is a working day"""
        return not (PayrollCalculationService.is_weekend(date_obj) or 
                   PayrollCalculationService.is_holiday(date_obj))
    
    @staticmethod
    def calculate_actual_hours(
        check_in: datetime,
        check_out: datetime
    ) -> float:
        """
        Calculate actual work hours, excluding breaks
        
        Logic:
        - Total time minus lunch break (1 hour if day >= 6 hours)
        - Minus break time (15 min per 4 hours worked)
        - Minimum 0 hours
        """
        
        if not check_out:
            return 0.0
        
        total_time = check_out - check_in
        total_seconds = total_time.total_seconds()
        total_hours = total_seconds / 3600
        
        # Subtract lunch break if working 6+ hours
        if total_hours >= 6:
            total_hours -= (PayrollCalculationService.LUNCH_BREAK_MINUTES / 60)
        
        # Subtract break time (15 min per 4 hours)
        break_periods = int(total_hours / 4)
        total_hours -= (PayrollCalculationService.BREAK_TIME_MINUTES * break_periods / 60)
        
        return max(0.0, total_hours)
    
    def calculate_expected_hours(
        self,
        period_start: date,
        period_end: date
    ) -> int:
        """Calculate expected work hours for period (business days only)"""
        
        expected_hours = 0
        current_date = period_start
        
        while current_date <= period_end:
            if self.is_business_day(current_date):
                expected_hours += self.STANDARD_WORKDAY_HOURS
            current_date += timedelta(days=1)
        
        return int(expected_hours)
    
    def calculate_regular_and_overtime(
        self,
        total_hours: float,
        expected_hours: float
    ) -> tuple:
        """Calculate regular and overtime hours"""
        
        if total_hours <= expected_hours:
            return (total_hours, 0.0)
        
        overtime = total_hours - expected_hours
        return (expected_hours, overtime)
    
    def calculate_gross_pay(
        self,
        regular_hours: float,
        overtime_hours: float,
        hourly_rate: float
    ) -> Decimal:
        """Calculate gross pay before deductions"""
        
        regular = Decimal(str(regular_hours)) * Decimal(str(hourly_rate))
        overtime = Decimal(str(overtime_hours)) * Decimal(str(hourly_rate)) * self.OVERTIME_MULTIPLIER
        
        return regular + overtime
    
    def calculate_deductions(
        self,
        gross_pay: Decimal
    ) -> Dict[str, Decimal]:
        """Calculate all deductions from gross pay"""
        
        deductions = {
            "federal_tax": gross_pay * self.FEDERAL_TAX_RATE,
            "state_tax": gross_pay * self.STATE_TAX_RATE,
            "fica": gross_pay * self.FICA_RATE,
            "health_insurance": self.HEALTH_INSURANCE_MONTHLY,
            "retirement": gross_pay * self.RETIREMENT_CONTRIBUTION_RATE,
        }
        
        deductions["total"] = sum(deductions.values())
        
        return deductions
    
    def calculate_employee_payroll(
        self,
        employee: Any,
        period_start: date,
        period_end: date
    ) -> Dict[str, Any]:
        """
        Calculate complete payroll for employee for period
        
        Returns comprehensive payroll data with validation
        """
        
        from models import AttendanceLog, LeaveRequest, PayrollRecord
        from sqlalchemy import and_
        from repositories import PayrollRepository
        
        try:
            # ✅ Check if payroll already processed for this period
            existing = self.db.query(PayrollRecord).filter(
                and_(
                    PayrollRecord.employee_id == employee.id,
                    PayrollRecord.period_start == period_start,
                    PayrollRecord.period_end == period_end,
                    PayrollRecord.status.in_([
                        PayrollStatus.APPROVED,
                        PayrollStatus.PROCESSING,
                        PayrollStatus.PAID
                    ])
                )
            ).first()
            
            if existing:
                logger.warning(
                    f"Payroll already processed for {employee.id} "
                    f"({period_start} to {period_end})"
                )
                return {
                    "error": "already_processed",
                    "message": f"Payroll already processed on {existing.created_at}",
                    "existing_id": existing.id
                }
            
            # Get verified attendance logs
            logs = self.db.query(AttendanceLog).filter(
                and_(
                    AttendanceLog.employee_id == employee.id,
                    AttendanceLog.check_in_time >= datetime.combine(period_start, datetime.min.time()),
                    AttendanceLog.check_in_time < datetime.combine(period_end + timedelta(days=1), datetime.min.time()),
                    AttendanceLog.check_in_verified == True,  # Only verified
                    AttendanceLog.check_out_time.isnot(None)  # Has check-out
                )
            ).order_by(AttendanceLog.check_in_time).all()
            
            # Get approved leave
            leave_records = self.db.query(LeaveRequest).filter(
                and_(
                    LeaveRequest.employee_id == employee.id,
                    LeaveRequest.start_date >= period_start,
                    LeaveRequest.end_date <= period_end,
                    LeaveRequest.status == "approved"
                )
            ).all()
            
            # Calculate hours
            total_hours_worked = Decimal("0.0")
            work_days = []
            
            for log in logs:
                hours = self.calculate_actual_hours(log.check_in_time, log.check_out_time)
                total_hours_worked += Decimal(str(hours))
                work_days.append(log.check_in_time.date())
            
            # Calculate approved leave hours
            approved_leave_hours = Decimal("0.0")
            for leave in leave_records:
                leave_days = 0
                current = leave.start_date
                while current <= leave.end_date:
                    if self.is_business_day(current):
                        leave_days += 1
                    current += timedelta(days=1)
                
                approved_leave_hours += Decimal(str(leave_days * self.STANDARD_WORKDAY_HOURS))
            
            # Calculate expected hours for period
            expected_hours = self.calculate_expected_hours(period_start, period_end)
            
            # Total hours paid (worked + approved leave)
            total_hours_paid = total_hours_worked + approved_leave_hours
            
            # Calculate regular and overtime
            regular_hours, overtime_hours = self.calculate_regular_and_overtime(
                float(total_hours_paid),
                float(expected_hours)
            )
            
            # Calculate pay
            hourly_rate = employee.salary_per_hour
            gross_pay = self.calculate_gross_pay(regular_hours, overtime_hours, hourly_rate)
            
            # Calculate deductions
            deductions = self.calculate_deductions(gross_pay)
            
            # Net pay
            net_pay = gross_pay - deductions["total"]
            
            # Calculate variance from expected
            variance_hours = float(total_hours_worked) - expected_hours
            variance_percentage = (variance_hours / expected_hours * 100) if expected_hours > 0 else 0
            
            return {
                "success": True,
                "employee_id": employee.id,
                "employee_name": employee.full_name,
                "period_start": period_start.isoformat(),
                "period_end": period_end.isoformat(),
                
                # Hours
                "days_worked": len(work_days),
                "expected_days": int(expected_hours / self.STANDARD_WORKDAY_HOURS),
                "total_hours_worked": float(total_hours_worked),
                "approved_leave_hours": float(approved_leave_hours),
                "total_hours_paid": float(total_hours_paid),
                "regular_hours": float(regular_hours),
                "overtime_hours": float(overtime_hours),
                
                # Pay
                "hourly_rate": float(hourly_rate),
                "regular_pay": float(regular_hours * Decimal(str(hourly_rate))),
                "overtime_pay": float(overtime_hours * Decimal(str(hourly_rate)) * self.OVERTIME_MULTIPLIER),
                "gross_pay": float(gross_pay),
                
                # Deductions
                "federal_tax": float(deductions["federal_tax"]),
                "state_tax": float(deductions["state_tax"]),
                "fica": float(deductions["fica"]),
                "health_insurance": float(deductions["health_insurance"]),
                "retirement": float(deductions["retirement"]),
                "total_deductions": float(deductions["total"]),
                
                # Net
                "net_pay": float(net_pay),
                
                # Variance
                "variance_hours": float(variance_hours),
                "variance_percentage": float(variance_percentage),
                "variance_flag": "HIGH" if abs(variance_percentage) > 20 else "NORMAL"
            }
        
        except Exception as e:
            logger.error(f"Payroll calculation error for {employee.id}: {e}")
            return {
                "error": "calculation_failed",
                "message": str(e)
            }
