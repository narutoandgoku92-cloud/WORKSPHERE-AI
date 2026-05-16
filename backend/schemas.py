# backend/schemas.py - Pydantic models for request/response validation

from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum

# ============================================================================
# ENUMS
# ============================================================================

class UserRole(str, Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    HR = "hr"
    EMPLOYEE = "employee"
    VIEWER = "viewer"

class EmployeeStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    ON_LEAVE = "on_leave"

class CheckInMethod(str, Enum):
    FACE = "face"
    MANUAL = "manual"
    CARD = "card"

# ============================================================================
# AUTHENTICATION SCHEMAS
# ============================================================================

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict

class TokenRefreshRequest(BaseModel):
    refresh_token: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8, max_length=100)
    confirm_password: str

# ============================================================================
# USER SCHEMAS
# ============================================================================

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    full_name: str = Field(..., min_length=2, max_length=255)
    role: UserRole = UserRole.VIEWER

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None

class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    role: str
    is_active: bool
    last_login: Optional[datetime]
    created_at: datetime
    
    class Config:
        from_attributes = True

# ============================================================================
# ORGANIZATION SCHEMAS
# ============================================================================

class OrganizationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    phone: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None

class OrganizationResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: Optional[str]
    subscription_plan: str
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

# ============================================================================
# DEPARTMENT SCHEMAS
# ============================================================================

class DepartmentCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    description: Optional[str] = None

class DepartmentResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

# ============================================================================
# EMPLOYEE SCHEMAS
# ============================================================================

class EmployeeCreate(BaseModel):
    employee_id: str = Field(..., min_length=1, max_length=100)
    full_name: str = Field(..., min_length=2, max_length=255)
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    job_title: Optional[str] = None
    dept_id: Optional[str] = None
    salary_per_hour: float = Field(default=0.0, ge=0)
    hire_date: Optional[datetime] = None

class EmployeeUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    job_title: Optional[str] = None
    dept_id: Optional[str] = None
    salary_per_hour: Optional[float] = Field(None, ge=0)
    status: Optional[EmployeeStatus] = None

class EmployeeResponse(BaseModel):
    id: str
    employee_id: str
    full_name: str
    email: Optional[str]
    phone: Optional[str]
    job_title: Optional[str]
    salary_per_hour: float
    status: str
    is_verified: bool
    hire_date: Optional[datetime]
    created_at: datetime
    
    class Config:
        from_attributes = True

class EmployeeDetailResponse(EmployeeResponse):
    department: Optional[dict] = None
    total_hours_worked: float = 0.0
    attendance_rate: float = 0.0

# ============================================================================
# FACE RECOGNITION SCHEMAS
# ============================================================================

class FaceEnrollmentRequest(BaseModel):
    face_image: str  # Base64 encoded image
    
    @field_validator('face_image')
    def validate_image(cls, v):
        if not v:
            raise ValueError("Face image required")
        if len(v) < 100:
            raise ValueError("Invalid image data")
        return v

class FaceVerificationRequest(BaseModel):
    face_image: str  # Base64 encoded image
    threshold: float = Field(default=0.6, ge=0.3, le=0.9)

class FaceVerificationResponse(BaseModel):
    verified: bool
    confidence: float
    match_id: Optional[str]
    message: str

# ============================================================================
# ATTENDANCE SCHEMAS
# ============================================================================

class AttendanceCheckInRequest(BaseModel):
    face_image: Optional[str] = None  # Base64 encoded
    latitude: float
    longitude: float
    device_id: Optional[str] = None
    check_in_method: CheckInMethod = CheckInMethod.FACE

class AttendanceCheckOutRequest(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class AttendanceLogResponse(BaseModel):
    id: str
    employee_id: str
    check_in_time: datetime
    check_out_time: Optional[datetime]
    check_in_verified: bool
    gps_verified: bool
    check_in_method: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class AttendanceStatsResponse(BaseModel):
    total_employees: int
    present_today: int
    absent_today: int
    late_today: int
    checked_in_count: int
    checked_out_count: int

# ============================================================================
# GPS SCHEMAS
# ============================================================================

class GPSLocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy: Optional[float] = None
    altitude: Optional[float] = None
    speed: Optional[float] = None

class GeofenceCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_meters: float = Field(default=100.0, ge=10, le=5000)
    description: Optional[str] = None

class GeofenceResponse(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    radius_meters: float
    description: Optional[str]
    is_active: bool
    
    class Config:
        from_attributes = True

class GeofenceValidationResponse(BaseModel):
    is_inside: bool
    distance_meters: float
    verified: bool

# ============================================================================
# ANALYTICS SCHEMAS
# ============================================================================

class EmployeeAnalyticsResponse(BaseModel):
    employee_id: str
    date: datetime
    hours_worked: float
    attendance_count: int
    on_time_count: int
    late_count: int
    productivity_score: float
    
    class Config:
        from_attributes = True

class AttendanceChartData(BaseModel):
    date: str
    present: int
    absent: int
    late: int

class DepartmentAnalyticsResponse(BaseModel):
    department_name: str
    total_employees: int
    present_today: int
    average_hours: float
    productivity_score: float

# ============================================================================
# PAYROLL SCHEMAS
# ============================================================================

class PayrollRecordResponse(BaseModel):
    id: str
    employee_id: str
    period_start: datetime
    period_end: datetime
    regular_hours: float
    overtime_hours: float
    regular_pay: float
    overtime_pay: float
    bonus_pay: float
    total_pay: float
    deductions: float
    net_pay: float
    payment_status: str
    
    class Config:
        from_attributes = True

class PayrollSummaryResponse(BaseModel):
    employee_name: str
    regular_hours: float
    overtime_hours: float
    daily_rate: float
    estimated_salary: float
    last_payment_date: Optional[datetime]

class PayrollReportRequest(BaseModel):
    period_start: datetime
    period_end: datetime
    department_id: Optional[str] = None

class BankDetails(BaseModel):
    bank_name: str = Field(..., min_length=2, max_length=255)
    account_holder_name: str = Field(..., min_length=2, max_length=255)
    account_number: str = Field(..., min_length=6, max_length=34)
    routing_number: Optional[str] = Field(None, min_length=3, max_length=20)
    account_type: Optional[str] = None

class SalaryPayoutRequest(BaseModel):
    employee_id: str
    period_start: datetime
    period_end: datetime
    bank_details: BankDetails
    currency: Optional[str] = None
    description: Optional[str] = None

class BulkSalaryPayoutRequest(BaseModel):
    payouts: List[SalaryPayoutRequest]

class PaymentStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    SUCCEEDED = "succeeded"
    FAILED = "failed"

class SalaryPayoutResult(BaseModel):
    employee_id: str
    payroll_record_id: Optional[str] = None
    salary_disbursement_id: Optional[str] = None
    transaction_id: Optional[str] = None
    status: str
    amount: float
    currency: str
    message: str

class TransactionResponse(BaseModel):
    id: str
    org_id: str
    employee_id: str
    amount: float
    currency: str
    status: str
    provider: Optional[str] = None
    external_transaction_id: Optional[str] = None
    failure_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class PaymentStatusResponse(BaseModel):
    id: str
    status: str
    type: str
    message: str
    details: Optional[Dict[str, Any]] = None

# ============================================================================
# DASHBOARD SCHEMAS
# ============================================================================

class DashboardSummary(BaseModel):
    total_employees: int
    present_today: int
    absent_today: int
    late_today: int
    average_productivity: float
    pending_payroll: int

class AdminDashboardResponse(BaseModel):
    summary: DashboardSummary
    recent_attendance: List[AttendanceLogResponse]
    top_productive_employees: List[dict]
    attendance_trend: List[AttendanceChartData]

class EmployeeDashboardResponse(BaseModel):
    employee: EmployeeResponse
    today_status: str  # checked_in, checked_out, absent
    check_in_time: Optional[datetime]
    check_out_time: Optional[datetime]
    hours_worked_today: float
    hours_worked_week: float
    next_payroll: Optional[PayrollSummaryResponse]
