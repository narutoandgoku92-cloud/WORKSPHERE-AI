
# backend/api/v1/routes/attendance.py
# Attendance tracking routes

from datetime import datetime
from math import radians, sin, cos, sqrt, atan2
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from core.database import get_db
from schemas import (
    AttendanceCheckInRequest,
    AttendanceCheckOutRequest,
    AttendanceLogResponse,
    AttendanceStatsResponse,
    UserRole,
)
from repositories import (
    AttendanceRepository,
    EmployeeRepository,
    GeofenceRepository,
)
from api.v1.routes.auth import (
    get_current_user,
    get_current_employee,
)

router = APIRouter(tags=["Attendance"])


# ============================================================================
# CHECK-IN
# ============================================================================

@router.post(
    "/check-in",
    response_model=AttendanceLogResponse,
    status_code=status.HTTP_201_CREATED,
)
async def check_in(
    request: AttendanceCheckInRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Check in the authenticated employee."""

    # Find the employee associated with the authenticated user.
    employee = EmployeeRepository.get_by_user_id(
        db,
        current_user.id,
    )

    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee record not found",
        )

    # Validate coordinates regardless of geofence configuration.
    if not (
        -90 <= request.latitude <= 90
        and -180 <= request.longitude <= 180
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid GPS coordinates",
        )

    # Prevent duplicate check-ins for the same day.
    today_checkin = AttendanceRepository.get_today_check_in(
        db,
        employee.id,
    )

    if today_checkin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already checked in today",
        )

    # Verify the employee's location when a geofence is configured.
    gps_verified = False

    geofences = GeofenceRepository.get_org_geofences(
        db,
        employee.org_id,
    )

    if geofences:
        geofence = geofences[0]

        distance = calculate_distance(
            request.latitude,
            request.longitude,
            geofence.latitude,
            geofence.longitude,
        )

        gps_verified = distance <= geofence.radius_meters

    # Create the attendance record.
    attendance = AttendanceRepository.create_check_in(
        db,
        employee_id=employee.id,
        org_id=employee.org_id,
        latitude=request.latitude,
        longitude=request.longitude,
        method=request.check_in_method,
        verified=True,
    )

    attendance.gps_verified = gps_verified

    db.commit()
    db.refresh(attendance)

    return attendance


# ============================================================================
# CHECK-OUT
# ============================================================================

@router.post(
    "/check-out",
    response_model=AttendanceLogResponse,
)
async def check_out(
    request: AttendanceCheckOutRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Check out the authenticated employee."""

    employee = EmployeeRepository.get_by_user_id(
        db,
        current_user.id,
    )

    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found",
        )

    attendance = AttendanceRepository.get_today_check_in(
        db,
        employee.id,
    )

    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active check-in found",
        )

    attendance.check_out_time = datetime.utcnow()

    db.commit()
    db.refresh(attendance)

    return attendance


# ============================================================================
# COMPANY-WIDE ATTENDANCE STATISTICS
# ============================================================================

@router.get(
    "/today",
    response_model=AttendanceStatsResponse,
)
async def get_today_stats(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get company-wide attendance statistics. Admins only."""

    role = getattr(current_user.role, "value", current_user.role)

    if role != UserRole.ADMIN.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required",
        )

    stats = AttendanceRepository.get_today_stats(
        db,
        current_user.org_id,
    )

    employees = EmployeeRepository.list_org_employees(
        db,
        current_user.org_id,
        skip=0,
        limit=10000,
    )

    total_employees = len(employees)

    return AttendanceStatsResponse(
        total_employees=total_employees,
        present_today=stats["present_today"],
        absent_today=total_employees - stats["present_today"],
        late_today=0,
        checked_in_count=stats["checked_in_count"],
        checked_out_count=stats["checked_out_count"],
    )


# ============================================================================
# PERSONAL ATTENDANCE
# ============================================================================

@router.get(
    "/me",
    response_model=List[AttendanceLogResponse],
)
async def get_my_attendance(
    days: int = 30,
    skip: int = 0,
    limit: int = 100,
    employee=Depends(get_current_employee),
    db: Session = Depends(get_db),
):
    """Get attendance records belonging to the authenticated employee."""

    validate_pagination(days, skip, limit)

    return AttendanceRepository.get_employee_logs(
        db,
        employee.id,
        days,
        skip,
        limit,
    )


# ============================================================================
# INDIVIDUAL EMPLOYEE ATTENDANCE
# ============================================================================

@router.get(
    "/employee/{employee_id}",
    response_model=List[AttendanceLogResponse],
)
async def get_employee_attendance(
    employee_id: str,
    days: int = 30,
    skip: int = 0,
    limit: int = 100,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get an employee's attendance with role-based access control."""

    validate_pagination(days, skip, limit)

    employee = EmployeeRepository.get_by_id(
        db,
        employee_id,
    )

    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found",
        )

    role = getattr(current_user.role, "value", current_user.role)

    if role != UserRole.ADMIN.value:
        own_employee = EmployeeRepository.get_by_user_id(
            db,
            current_user.id,
        )

        if not own_employee or own_employee.id != employee.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot access another employee's attendance",
            )

    return AttendanceRepository.get_employee_logs(
        db,
        employee.id,
        days,
        skip,
        limit,
    )


# ============================================================================
# VALIDATION HELPERS
# ============================================================================

def validate_pagination(
    days: int,
    skip: int,
    limit: int,
) -> None:
    """Validate attendance history query parameters."""

    if days < 1 or days > 365:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Days must be between 1 and 365",
        )

    if skip < 0 or limit < 1 or limit > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid pagination parameters",
        )


# ============================================================================
# GPS HELPER
# ============================================================================

def calculate_distance(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    """Calculate distance between two GPS coordinates in meters."""

    earth_radius = 6_371_000

    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)

    a = (
        sin(delta_lat / 2) ** 2
        + cos(lat1_rad)
        * cos(lat2_rad)
        * sin(delta_lon / 2) ** 2
    )

    # Protect against floating-point rounding errors.
    a = max(0.0, min(1.0, a))

    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return earth_radius * c
