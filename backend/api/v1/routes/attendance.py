# backend/api/v1/routes/attendance.py - Attendance tracking routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from core.database import get_db
from schemas import (
    AttendanceCheckInRequest, AttendanceCheckOutRequest, 
    AttendanceLogResponse, AttendanceStatsResponse
)
from repositories import AttendanceRepository, EmployeeRepository, GeofenceRepository
from api.v1.routes.auth import get_current_user

router = APIRouter(tags=["Attendance"])

# ============================================================================
# ATTENDANCE ENDPOINTS
# ============================================================================

@router.post("/check-in", response_model=AttendanceLogResponse)
async def check_in(
    request: AttendanceCheckInRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Employee check-in"""
    
    # Get employee
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Check if already checked in today
    today_checkin = AttendanceRepository.get_today_check_in(db, employee.id)
    if today_checkin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already checked in today"
        )
    
    # Verify geofence if available
    gps_verified = False
    geofences = GeofenceRepository.get_org_geofences(db, employee.org_id)
    if geofences:
        geofence = geofences[0]  # Use first geofence
        # Calculate distance (simplified)
        distance = calculate_distance(
            request.latitude, request.longitude,
            geofence.latitude, geofence.longitude
        )
        gps_verified = distance <= geofence.radius_meters
    
    # Create check-in
    attendance = AttendanceRepository.create_check_in(
        db,
        employee_id=employee.id,
        org_id=employee.org_id,
        latitude=request.latitude,
        longitude=request.longitude,
        method=request.check_in_method,
        verified=True  # In production, verify face here
    )
    
    attendance.gps_verified = gps_verified
    db.commit()
    db.refresh(attendance)
    
    return attendance

@router.post("/check-out", response_model=AttendanceLogResponse)
async def check_out(
    request: AttendanceCheckOutRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Employee check-out"""
    
    # Get employee
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Get today's check-in
    attendance = AttendanceRepository.get_today_check_in(db, employee.id)
    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active check-in found"
        )
    
    # Create check-out
    attendance.check_out_time = datetime.utcnow()
    if request.latitude and request.longitude:
        attendance.check_out_latitude = request.latitude
        attendance.check_out_longitude = request.longitude
    
    db.commit()
    db.refresh(attendance)
    
    return attendance

@router.get("/today", response_model=AttendanceStatsResponse)
async def get_today_stats(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get today's attendance statistics"""
    
    stats = AttendanceRepository.get_today_stats(db, current_user.org_id)
    
    # Get total employees
    employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
    total_employees = len(employees)
    
    return AttendanceStatsResponse(
        total_employees=total_employees,
        present_today=stats["present_today"],
        absent_today=total_employees - stats["present_today"],
        late_today=0,
        checked_in_count=stats["checked_in_count"],
        checked_out_count=stats["checked_out_count"]
    )

@router.get("/employee/{employee_id}", response_model=List[AttendanceLogResponse])
async def get_employee_attendance(
    employee_id: str,
    days: int = 30,
    skip: int = 0,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get employee attendance logs"""
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    logs = AttendanceRepository.get_employee_logs(db, employee_id, days, skip, limit)
    return logs

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two coordinates in meters"""
    from math import radians, sin, cos, sqrt, atan2
    
    R = 6371000  # Earth's radius in meters
    
    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)
    
    a = sin(delta_lat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    distance = R * c
    
    return distance
