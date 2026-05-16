# backend/repositories.py - Database access layer

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
from datetime import datetime, timedelta
from typing import List, Optional
import logging

from models import (
    User, Employee, Organization, Department, AttendanceLog, 
    FaceEmbedding, GPSLog, PayrollRecord, PaymentTransaction,
    SalaryDisbursement, EmployeeAnalytics, Geofence, AuditLog
)
from schemas import EmployeeStatus

logger = logging.getLogger(__name__)

# ============================================================================
# ORGANIZATION REPOSITORY
# ============================================================================

class OrganizationRepository:
    """Organization database operations"""
    
    @staticmethod
    def create(db: Session, name: str, email: str, **kwargs):
        """Create new organization"""
        org = Organization(
            name=name,
            email=email,
            **kwargs
        )
        db.add(org)
        db.commit()
        db.refresh(org)
        return org
    
    @staticmethod
    def get_by_id(db: Session, org_id: str) -> Optional[Organization]:
        """Get organization by ID"""
        return db.query(Organization).filter(Organization.id == org_id).first()

# ============================================================================
# USER REPOSITORY
# ============================================================================

class UserRepository:
    """User/Admin database operations"""
    
    @staticmethod
    def create(db: Session, org_id: str, email: str, password_hash: str, full_name: str, role: str = "admin"):
        """Create new user"""
        user = User(
            org_id=org_id,
            email=email,
            password_hash=password_hash,
            full_name=full_name,
            role=role
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    
    @staticmethod
    def get_by_email(db: Session, org_id: str, email: str) -> Optional[User]:
        """Get user by email"""
        return db.query(User).filter(
            and_(User.org_id == org_id, User.email == email)
        ).first()
    
    @staticmethod
    def get_by_email_any_org(db: Session, email: str) -> Optional[User]:
        """Get user by email across all organizations"""
        return db.query(User).filter(User.email == email).first()
    
    @staticmethod
    def get_by_id(db: Session, user_id: str) -> Optional[User]:
        """Get user by ID"""
        return db.query(User).filter(User.id == user_id).first()
    
    @staticmethod
    def list_org_users(db: Session, org_id: str, skip: int = 0, limit: int = 100) -> List[User]:
        """List organization users"""
        return db.query(User).filter(User.org_id == org_id).offset(skip).limit(limit).all()
    
    @staticmethod
    def update_last_login(db: Session, user_id: str):
        """Update user's last login time"""
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.last_login = datetime.utcnow()
            db.commit()

# ============================================================================
# EMPLOYEE REPOSITORY
# ============================================================================

class EmployeeRepository:
    """Employee database operations"""
    
    @staticmethod
    def create(db: Session, org_id: str, employee_id: str, full_name: str, **kwargs):
        """Create new employee"""
        employee = Employee(
            org_id=org_id,
            employee_id=employee_id,
            full_name=full_name,
            **kwargs
        )
        db.add(employee)
        db.commit()
        db.refresh(employee)
        return employee
    
    @staticmethod
    def get_by_id(db: Session, employee_id: str) -> Optional[Employee]:
        """Get employee by ID"""
        return db.query(Employee).filter(Employee.id == employee_id).first()
    
    @staticmethod
    def get_by_employee_id(db: Session, org_id: str, employee_id: str) -> Optional[Employee]:
        """Get employee by employee ID (badge number)"""
        return db.query(Employee).filter(
            and_(Employee.org_id == org_id, Employee.employee_id == employee_id)
        ).first()
    
    @staticmethod
    def list_org_employees(db: Session, org_id: str, skip: int = 0, limit: int = 100) -> List[Employee]:
        """List organization employees"""
        return db.query(Employee).filter(
            Employee.org_id == org_id
        ).offset(skip).limit(limit).all()
    
    @staticmethod
    def list_dept_employees(db: Session, dept_id: str) -> List[Employee]:
        """List department employees"""
        return db.query(Employee).filter(Employee.dept_id == dept_id).all()
    
    @staticmethod
    def update(db: Session, employee_id: str, **kwargs):
        """Update employee"""
        employee = db.query(Employee).filter(Employee.id == employee_id).first()
        if employee:
            for key, value in kwargs.items():
                if value is not None:
                    setattr(employee, key, value)
            employee.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(employee)
        return employee

# ============================================================================
# ATTENDANCE REPOSITORY
# ============================================================================

class AttendanceRepository:
    """Attendance log database operations"""
    
    @staticmethod
    def create_check_in(db: Session, employee_id: str, org_id: str, latitude: float, 
                       longitude: float, method: str = "face", verified: bool = False):
        """Create check-in log"""
        attendance = AttendanceLog(
            employee_id=employee_id,
            org_id=org_id,
            check_in_time=datetime.utcnow(),
            check_in_latitude=latitude,
            check_in_longitude=longitude,
            check_in_method=method,
            check_in_verified=verified
        )
        db.add(attendance)
        db.commit()
        db.refresh(attendance)
        return attendance
    
    @staticmethod
    def create_check_out(db: Session, attendance_id: str):
        """Create check-out log"""
        attendance = db.query(AttendanceLog).filter(AttendanceLog.id == attendance_id).first()
        if attendance:
            attendance.check_out_time = datetime.utcnow()
            db.commit()
            db.refresh(attendance)
        return attendance
    
    @staticmethod
    def get_today_check_in(db: Session, employee_id: str) -> Optional[AttendanceLog]:
        """Get today's check-in"""
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        return db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.employee_id == employee_id,
                AttendanceLog.check_in_time >= today_start,
                AttendanceLog.check_out_time.is_(None)
            )
        ).first()
    
    @staticmethod
    def get_employee_logs(db: Session, employee_id: str, days: int = 30, skip: int = 0, limit: int = 100) -> List[AttendanceLog]:
        """Get employee attendance logs"""
        date_from = datetime.utcnow() - timedelta(days=days)
        return db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.employee_id == employee_id,
                AttendanceLog.check_in_time >= date_from
            )
        ).order_by(desc(AttendanceLog.check_in_time)).offset(skip).limit(limit).all()
    
    @staticmethod
    def get_today_stats(db: Session, org_id: str):
        """Get today's attendance statistics"""
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        
        query = db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.org_id == org_id,
                AttendanceLog.check_in_time >= today_start
            )
        )
        
        present = query.count()
        checked_out = query.filter(AttendanceLog.check_out_time.isnot(None)).count()
        
        return {
            "present_today": present,
            "checked_out_count": checked_out,
            "checked_in_count": present - checked_out
        }

# ============================================================================
# FACE EMBEDDING REPOSITORY
# ============================================================================

class FaceEmbeddingRepository:
    """Face embedding database operations"""
    
    @staticmethod
    def create(db: Session, employee_id: str, embedding: str, quality_score: float = 0.0, face_image_url: str = None):
        """Store face embedding"""
        face_emb = FaceEmbedding(
            employee_id=employee_id,
            embedding=embedding,
            quality_score=quality_score,
            face_image_url=face_image_url
        )
        db.add(face_emb)
        db.commit()
        db.refresh(face_emb)
        return face_emb
    
    @staticmethod
    def get_primary(db: Session, employee_id: str) -> Optional[FaceEmbedding]:
        """Get primary face embedding"""
        return db.query(FaceEmbedding).filter(
            and_(
                FaceEmbedding.employee_id == employee_id,
                FaceEmbedding.is_primary == True
            )
        ).first()
    
    @staticmethod
    def get_all_employee(db: Session, employee_id: str) -> List[FaceEmbedding]:
        """Get all embeddings for employee"""
        return db.query(FaceEmbedding).filter(FaceEmbedding.employee_id == employee_id).all()

# ============================================================================
# GPS REPOSITORY
# ============================================================================

class GPSRepository:
    """GPS log database operations"""
    
    @staticmethod
    def create(db: Session, employee_id: str, org_id: str, latitude: float, 
              longitude: float, accuracy: float = None, inside_geofence: bool = False):
        """Log GPS location"""
        gps_log = GPSLog(
            employee_id=employee_id,
            org_id=org_id,
            latitude=latitude,
            longitude=longitude,
            accuracy=accuracy,
            is_geofence_inside=inside_geofence
        )
        db.add(gps_log)
        db.commit()
        db.refresh(gps_log)
        return gps_log
    
    @staticmethod
    def get_latest_location(db: Session, employee_id: str) -> Optional[GPSLog]:
        """Get latest GPS location"""
        return db.query(GPSLog).filter(
            GPSLog.employee_id == employee_id
        ).order_by(desc(GPSLog.created_at)).first()

# ============================================================================
# GEOFENCE REPOSITORY
# ============================================================================

class GeofenceRepository:
    """Geofence database operations"""
    
    @staticmethod
    def create(db: Session, org_id: str, name: str, latitude: float, 
              longitude: float, radius_meters: float = 100.0):
        """Create geofence"""
        geofence = Geofence(
            org_id=org_id,
            name=name,
            latitude=latitude,
            longitude=longitude,
            radius_meters=radius_meters
        )
        db.add(geofence)
        db.commit()
        db.refresh(geofence)
        return geofence
    
    @staticmethod
    def get_org_geofences(db: Session, org_id: str) -> List[Geofence]:
        """Get organization geofences"""
        return db.query(Geofence).filter(
            and_(Geofence.org_id == org_id, Geofence.is_active == True)
        ).all()
    
    @staticmethod
    def get_by_id(db: Session, geofence_id: str) -> Optional[Geofence]:
        """Get geofence by ID"""
        return db.query(Geofence).filter(Geofence.id == geofence_id).first()

# ============================================================================
# PAYROLL REPOSITORY
# ============================================================================

class PayrollRepository:
    """Payroll database operations"""
    
    @staticmethod
    def create(
        db: Session,
        employee_id: str,
        org_id: str,
        period_start: datetime,
        period_end: datetime,
        daily_rate: float,
        regular_hours: float = 0.0,
        overtime_hours: float = 0.0,
        regular_pay: float = 0.0,
        overtime_pay: float = 0.0,
        bonus_pay: float = 0.0,
        total_pay: float = 0.0,
        deductions: float = 0.0,
        net_pay: float = 0.0,
        payment_status: str = "pending",
        payment_date: datetime | None = None,
        notes: str | None = None,
    ):
        """Create payroll record"""
        payroll = PayrollRecord(
            employee_id=employee_id,
            org_id=org_id,
            period_start=period_start,
            period_end=period_end,
            daily_rate=daily_rate,
            regular_hours=regular_hours,
            overtime_hours=overtime_hours,
            regular_pay=regular_pay,
            overtime_pay=overtime_pay,
            bonus_pay=bonus_pay,
            total_pay=total_pay,
            deductions=deductions,
            net_pay=net_pay,
            payment_status=payment_status,
            payment_date=payment_date,
            notes=notes,
        )
        db.add(payroll)
        db.commit()
        db.refresh(payroll)
        return payroll
    
    @staticmethod
    def get_employee_current_payroll(db: Session, employee_id: str) -> Optional[PayrollRecord]:
        """Get current payroll period"""
        today = datetime.utcnow()
        return db.query(PayrollRecord).filter(
            and_(
                PayrollRecord.employee_id == employee_id,
                PayrollRecord.period_start <= today,
                PayrollRecord.period_end >= today
            )
        ).first()

# ============================================================================
# PAYMENT TRANSACTION REPOSITORY
# ============================================================================

class PaymentTransactionRepository:
    """Payment transaction history database operations"""

    @staticmethod
    def create(
        db: Session,
        org_id: str,
        employee_id: str,
        payroll_record_id: str | None,
        amount: float,
        currency: str,
        provider: str = "squad",
        external_transaction_id: str | None = None,
        status: str = "pending",
        failure_reason: str | None = None,
        provider_response: str | None = None,
        provider_metadata: str | None = None,
    ) -> PaymentTransaction:
        transaction = PaymentTransaction(
            org_id=org_id,
            employee_id=employee_id,
            payroll_record_id=payroll_record_id,
            external_transaction_id=external_transaction_id,
            provider=provider,
            amount=amount,
            currency=currency,
            status=status,
            failure_reason=failure_reason,
            provider_response=provider_response,
            provider_metadata=provider_metadata,
        )
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        return transaction

    @staticmethod
    def get_by_id(db: Session, transaction_id: str) -> Optional[PaymentTransaction]:
        return db.query(PaymentTransaction).filter(PaymentTransaction.id == transaction_id).first()

    @staticmethod
    def list_org_transactions(db: Session, org_id: str, skip: int = 0, limit: int = 50) -> List[PaymentTransaction]:
        return db.query(PaymentTransaction).filter(
            PaymentTransaction.org_id == org_id
        ).order_by(desc(PaymentTransaction.created_at)).offset(skip).limit(limit).all()

    @staticmethod
    def update_status(
        db: Session,
        transaction_id: str,
        status: str,
        external_transaction_id: str | None = None,
        failure_reason: str | None = None,
        provider_response: str | None = None,
        provider_metadata: str | None = None,
    ) -> Optional[PaymentTransaction]:
        transaction = db.query(PaymentTransaction).filter(PaymentTransaction.id == transaction_id).first()
        if not transaction:
            return None
        transaction.status = status
        if external_transaction_id is not None:
            transaction.external_transaction_id = external_transaction_id
        if failure_reason is not None:
            transaction.failure_reason = failure_reason
        if provider_response is not None:
            transaction.provider_response = provider_response
        if provider_metadata is not None:
            transaction.provider_metadata = provider_metadata
        transaction.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(transaction)
        return transaction

# ============================================================================
# SALARY DISBURSEMENT REPOSITORY
# ============================================================================

class SalaryDisbursementRepository:
    """Salary disbursement database operations"""

    @staticmethod
    def create(
        db: Session,
        org_id: str,
        employee_id: str,
        payroll_record_id: str | None,
        amount: float,
        currency: str,
        bank_name: str,
        bank_account_mask: str,
        account_holder_name: str,
        description: str | None = None,
        status: str = "pending",
        failure_reason: str | None = None,
    ) -> SalaryDisbursement:
        disbursement = SalaryDisbursement(
            org_id=org_id,
            employee_id=employee_id,
            payroll_record_id=payroll_record_id,
            amount=amount,
            currency=currency,
            bank_name=bank_name,
            bank_account_mask=bank_account_mask,
            account_holder_name=account_holder_name,
            description=description,
            status=status,
            failure_reason=failure_reason,
        )
        db.add(disbursement)
        db.commit()
        db.refresh(disbursement)
        return disbursement

    @staticmethod
    def get_by_id(db: Session, disbursement_id: str) -> Optional[SalaryDisbursement]:
        return db.query(SalaryDisbursement).filter(SalaryDisbursement.id == disbursement_id).first()

    @staticmethod
    def get_duplicate(
        db: Session,
        employee_id: str,
        period_start: datetime,
        period_end: datetime,
    ) -> Optional[SalaryDisbursement]:
        return db.query(SalaryDisbursement).join(PayrollRecord).filter(
            and_(
                SalaryDisbursement.employee_id == employee_id,
                PayrollRecord.period_start == period_start,
                PayrollRecord.period_end == period_end,
                SalaryDisbursement.status.in_(["pending", "processing", "succeeded"])
            )
        ).first()

    @staticmethod
    def list_org_disbursements(db: Session, org_id: str, skip: int = 0, limit: int = 50) -> List[SalaryDisbursement]:
        return db.query(SalaryDisbursement).filter(
            SalaryDisbursement.org_id == org_id
        ).order_by(desc(SalaryDisbursement.created_at)).offset(skip).limit(limit).all()

    @staticmethod
    def update_status(
        db: Session,
        disbursement_id: str,
        status: str,
        failure_reason: str | None = None,
        completed_at: datetime | None = None,
        transaction_id: str | None = None,
    ) -> Optional[SalaryDisbursement]:
        disbursement = db.query(SalaryDisbursement).filter(SalaryDisbursement.id == disbursement_id).first()
        if not disbursement:
            return None
        disbursement.status = status
        if failure_reason is not None:
            disbursement.failure_reason = failure_reason
        if completed_at is not None:
            disbursement.completed_at = completed_at
        if transaction_id is not None:
            disbursement.transaction_id = transaction_id
        disbursement.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(disbursement)
        return disbursement

# ============================================================================
# AUDIT LOG REPOSITORY
# ============================================================================

class AuditLogRepository:
    """Audit log database operations"""

    @staticmethod
    def create(
        db: Session,
        org_id: str,
        user_id: str | None,
        action: str,
        resource_type: str,
        resource_id: str,
        old_value: str | None = None,
        new_value: str | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        status: str = "success",
        error_message: str | None = None,
    ):
        audit = AuditLog(
            org_id=org_id,
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            old_value=old_value,
            new_value=new_value,
            ip_address=ip_address,
            user_agent=user_agent,
            status=status,
            error_message=error_message,
        )
        db.add(audit)
        db.commit()
        db.refresh(audit)
        return audit

    @staticmethod
    def list_org_logs(db: Session, org_id: str, skip: int = 0, limit: int = 100):
        return db.query(AuditLog).filter(AuditLog.org_id == org_id).order_by(desc(AuditLog.created_at)).offset(skip).limit(limit).all()

# ============================================================================
# ANALYTICS REPOSITORY
# ============================================================================

class AnalyticsRepository:
    """Analytics database operations"""
    
    @staticmethod
    def create_daily(db: Session, employee_id: str, org_id: str, date: datetime, 
                    hours_worked: float, productivity_score: float):
        """Create daily analytics"""
        analytics = EmployeeAnalytics(
            employee_id=employee_id,
            org_id=org_id,
            date=date,
            hours_worked=hours_worked,
            productivity_score=productivity_score
        )
        db.add(analytics)
        db.commit()
        db.refresh(analytics)
        return analytics
    
    @staticmethod
    def get_employee_weekly(db: Session, employee_id: str, days: int = 7):
        """Get employee weekly analytics"""
        date_from = datetime.utcnow() - timedelta(days=days)
        return db.query(EmployeeAnalytics).filter(
            and_(
                EmployeeAnalytics.employee_id == employee_id,
                EmployeeAnalytics.date >= date_from
            )
        ).order_by(EmployeeAnalytics.date).all()
