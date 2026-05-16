# backend/models.py - SQLAlchemy ORM Models
# Complete database schema for OptiWork AI

from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, ForeignKey, Text, LargeBinary, Index, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import uuid

from core.config import settings
from core.database import Base

# ============================================================================
# ORGANIZATION MODEL
# ============================================================================

class Organization(Base):
    """Organization/Company model"""
    __tablename__ = "organizations"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False, index=True)
    email = Column(String(255), nullable=False, unique=True)
    phone = Column(String(20), nullable=True)
    address = Column(Text, nullable=True)
    city = Column(String(100), nullable=True)
    country = Column(String(100), nullable=True)
    subscription_plan = Column(String(50), default="free")  # free, pro, enterprise
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    users = relationship("User", back_populates="organization", cascade="all, delete-orphan")
    employees = relationship("Employee", back_populates="organization", cascade="all, delete-orphan")
    departments = relationship("Department", back_populates="organization", cascade="all, delete-orphan")
    geofences = relationship("Geofence", back_populates="organization", cascade="all, delete-orphan")

# ============================================================================
# DEPARTMENT MODEL
# ============================================================================

class Department(Base):
    """Department model"""
    __tablename__ = "departments"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    manager_id = Column(String(36), ForeignKey("employees.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    organization = relationship("Organization", back_populates="departments")
    employees = relationship("Employee", back_populates="department", foreign_keys="Employee.dept_id")
    
    __table_args__ = (UniqueConstraint('org_id', 'name', name='uq_org_department_name'),)

# ============================================================================
# USER MODEL (Staff/Admin)
# ============================================================================

class User(Base):
    """User/Admin model"""
    __tablename__ = "users"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    email = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(String(50), default="admin")  # admin, manager, hr, viewer
    is_active = Column(Boolean, default=True)
    last_login = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    organization = relationship("Organization", back_populates="users")
    
    __table_args__ = (UniqueConstraint('org_id', 'email', name='uq_org_user_email'),)

# ============================================================================
# EMPLOYEE MODEL
# ============================================================================

class Employee(Base):
    """Employee model"""
    __tablename__ = "employees"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    dept_id = Column(String(36), ForeignKey("departments.id"), nullable=True)
    employee_id = Column(String(100), nullable=False)  # Employee ID/Badge number
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=True)
    phone = Column(String(20), nullable=True)
    job_title = Column(String(255), nullable=True)
    salary_per_hour = Column(Float, default=0.0)  # Hourly wage for payroll
    hire_date = Column(DateTime, nullable=True)
    status = Column(String(50), default="active")  # active, inactive, on_leave
    is_verified = Column(Boolean, default=False)  # Face recognition enrollment complete
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    organization = relationship("Organization", back_populates="employees")
    department = relationship("Department", back_populates="employees", foreign_keys=[dept_id])
    face_embeddings = relationship("FaceEmbedding", back_populates="employee", cascade="all, delete-orphan")
    attendance_logs = relationship("AttendanceLog", back_populates="employee", cascade="all, delete-orphan")
    gps_logs = relationship("GPSLog", back_populates="employee", cascade="all, delete-orphan")
    payroll_records = relationship("PayrollRecord", back_populates="employee", cascade="all, delete-orphan")
    
    __table_args__ = (UniqueConstraint('org_id', 'employee_id', name='uq_org_employee_id'),)

# ============================================================================
# FACE EMBEDDING MODEL
# ============================================================================

class FaceEmbedding(Base):
    """Face embedding for face recognition"""
    __tablename__ = "face_embeddings"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    embedding = Column(Text, nullable=False)  # JSON array of embeddings
    face_image_url = Column(String(500), nullable=True)  # S3 URL
    quality_score = Column(Float, default=0.0)  # 0-1 score
    enrollment_count = Column(Integer, default=1)  # Number of images used for enrollment
    is_primary = Column(Boolean, default=True)  # Primary enrollment
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    employee = relationship("Employee", back_populates="face_embeddings")

# ============================================================================
# ATTENDANCE LOG MODEL
# ============================================================================

class AttendanceLog(Base):
    """Attendance check-in/out logs"""
    __tablename__ = "attendance_logs"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    check_in_time = Column(DateTime, nullable=False)
    check_out_time = Column(DateTime, nullable=True)
    check_in_latitude = Column(Float, nullable=True)
    check_in_longitude = Column(Float, nullable=True)
    check_in_method = Column(String(50), default="face")  # face, manual, card
    check_in_verified = Column(Boolean, default=False)  # Face verification passed
    check_in_device_id = Column(String(100), nullable=True)
    gps_verified = Column(Boolean, default=False)  # GPS location verified
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    employee = relationship("Employee", back_populates="attendance_logs")
    organization = relationship("Organization")
    
    __table_args__ = (Index('idx_employee_checkin_date', 'employee_id', 'check_in_time'),)

# ============================================================================
# GPS LOG MODEL
# ============================================================================

class GPSLog(Base):
    """GPS location logs for tracking"""
    __tablename__ = "gps_logs"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)
    altitude = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    bearing = Column(Float, nullable=True)
    is_geofence_inside = Column(Boolean, default=False)
    distance_from_geofence = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    employee = relationship("Employee", back_populates="gps_logs")
    organization = relationship("Organization")

# ============================================================================
# GEOFENCE MODEL
# ============================================================================

class Geofence(Base):
    """Workplace geofence boundaries"""
    __tablename__ = "geofences"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Float, default=100.0)  # 100m radius by default
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    organization = relationship("Organization", back_populates="geofences")

# ============================================================================
# PAYROLL RECORD MODEL
# ============================================================================

class PayrollRecord(Base):
    """Employee payroll and compensation"""
    __tablename__ = "payroll_records"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False)
    period_start = Column(DateTime, nullable=False)
    period_end = Column(DateTime, nullable=False)
    regular_hours = Column(Float, default=0.0)
    overtime_hours = Column(Float, default=0.0)
    daily_rate = Column(Float, nullable=False)
    overtime_multiplier = Column(Float, default=1.5)  # 1.5x overtime
    regular_pay = Column(Float, default=0.0)
    overtime_pay = Column(Float, default=0.0)
    bonus_pay = Column(Float, default=0.0)
    total_pay = Column(Float, default=0.0)
    deductions = Column(Float, default=0.0)
    net_pay = Column(Float, default=0.0)
    payment_status = Column(String(50), default="pending")  # pending, processing, paid, failed
    payment_date = Column(DateTime, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    employee = relationship("Employee", back_populates="payroll_records")
    organization = relationship("Organization")

# ============================================================================
# PAYMENT TRANSACTION MODEL
# ============================================================================

class PaymentTransaction(Base):
    """External Squad payment transaction history"""
    __tablename__ = "payment_transactions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    payroll_record_id = Column(String(36), ForeignKey("payroll_records.id"), nullable=True, index=True)
    external_transaction_id = Column(String(255), nullable=True, index=True)
    provider = Column(String(100), default="squad")
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default=settings.PAYROLL_DEFAULT_CURRENCY)
    status = Column(String(50), default="pending")
    failure_reason = Column(Text, nullable=True)
    provider_response = Column(Text, nullable=True)
    provider_metadata = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    organization = relationship("Organization")
    employee = relationship("Employee")
    disbursement = relationship("SalaryDisbursement", back_populates="transaction", uselist=False)

# ============================================================================
# SALARY DISBURSEMENT MODEL
# ============================================================================

class SalaryDisbursement(Base):
    """Salary payout details for payroll processing"""
    __tablename__ = "salary_disbursements"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    payroll_record_id = Column(String(36), ForeignKey("payroll_records.id"), nullable=True, index=True)
    transaction_id = Column(String(36), ForeignKey("payment_transactions.id"), nullable=True, index=True)
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default=settings.PAYROLL_DEFAULT_CURRENCY)
    status = Column(String(50), default="pending")  # pending, succeeded, failed
    bank_name = Column(String(255), nullable=True)
    bank_account_mask = Column(String(50), nullable=True)
    account_holder_name = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    initiated_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    failure_reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    organization = relationship("Organization")
    employee = relationship("Employee")
    transaction = relationship("PaymentTransaction", back_populates="disbursement")

# ============================================================================
# ANALYTICS MODEL
# ============================================================================

class EmployeeAnalytics(Base):
    """Daily analytics for employees"""
    __tablename__ = "employee_analytics"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    employee_id = Column(String(36), ForeignKey("employees.id"), nullable=False, index=True)
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False)
    date = Column(DateTime, nullable=False)
    hours_worked = Column(Float, default=0.0)
    attendance_count = Column(Integer, default=0)
    on_time_count = Column(Integer, default=0)
    late_count = Column(Integer, default=0)
    productivity_score = Column(Float, default=0.0)  # 0-100
    average_gps_accuracy = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    __table_args__ = (UniqueConstraint('employee_id', 'date', name='uq_employee_analytics_date'),)

# ============================================================================
# AUDIT LOG MODEL
# ============================================================================

class AuditLog(Base):
    """Audit trail for security and compliance"""
    __tablename__ = "audit_logs"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    org_id = Column(String(36), ForeignKey("organizations.id"), nullable=False, index=True)
    user_id = Column(String(36), nullable=True)  # Who performed the action
    action = Column(String(255), nullable=False)
    resource_type = Column(String(100), nullable=False)  # employee, attendance, payroll
    resource_id = Column(String(36), nullable=False)
    old_value = Column(Text, nullable=True)  # JSON
    new_value = Column(Text, nullable=True)  # JSON
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(String(500), nullable=True)
    status = Column(String(50), default="success")
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    
    __table_args__ = (Index('idx_org_action_date', 'org_id', 'action', 'created_at'),)
