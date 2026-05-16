# backend/api/v1/routes/gps.py - GPS tracking routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from core.database import get_db
from schemas import (
    GPSLocationUpdate, GeofenceCreate, GeofenceResponse, 
    GeofenceValidationResponse
)
from repositories import GPSRepository, GeofenceRepository, EmployeeRepository
from api.v1.routes.auth import get_current_user
from api.v1.routes.attendance import calculate_distance

router = APIRouter(tags=["GPS"])

# ============================================================================
# GPS ENDPOINTS
# ============================================================================

@router.post("/location")
async def update_location(
    request: GPSLocationUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update employee GPS location"""
    
    # Get employee
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Check geofence
    inside_geofence = False
    geofences = GeofenceRepository.get_org_geofences(db, employee.org_id)
    if geofences:
        geofence = geofences[0]
        distance = calculate_distance(
            request.latitude, request.longitude,
            geofence.latitude, geofence.longitude
        )
        inside_geofence = distance <= geofence.radius_meters
    
    # Log GPS
    gps_log = GPSRepository.create(
        db,
        employee_id=employee.id,
        org_id=employee.org_id,
        latitude=request.latitude,
        longitude=request.longitude,
        accuracy=request.accuracy,
        inside_geofence=inside_geofence
    )
    
    return {
        "message": "Location updated",
        "inside_geofence": inside_geofence
    }

@router.get("/location/latest")
async def get_latest_location(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get latest GPS location"""
    
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    location = GPSRepository.get_latest_location(db, employee.id)
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No location data available"
        )
    
    return {
        "latitude": location.latitude,
        "longitude": location.longitude,
        "accuracy": location.accuracy,
        "inside_geofence": location.is_geofence_inside,
        "timestamp": location.created_at
    }

@router.post("/validate", response_model=GeofenceValidationResponse)
async def validate_geofence(
    request: GPSLocationUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Validate if location is inside geofence"""
    
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    geofences = GeofenceRepository.get_org_geofences(db, employee.org_id)
    if not geofences:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No geofence configured"
        )
    
    geofence = geofences[0]
    distance = calculate_distance(
        request.latitude, request.longitude,
        geofence.latitude, geofence.longitude
    )
    
    inside = distance <= geofence.radius_meters
    
    return GeofenceValidationResponse(
        is_inside=inside,
        distance_meters=distance,
        verified=inside
    )

@router.post("/geofence", response_model=GeofenceResponse)
async def create_geofence(
    request: GeofenceCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create geofence (admin only)"""
    
    if current_user.role not in ["admin", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    geofence = GeofenceRepository.create(
        db,
        org_id=current_user.org_id,
        name=request.name,
        latitude=request.latitude,
        longitude=request.longitude,
        radius_meters=request.radius_meters
    )
    
    return geofence

@router.get("/geofences", response_model=List[GeofenceResponse])
async def list_geofences(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List organization geofences"""
    
    geofences = GeofenceRepository.get_org_geofences(db, current_user.org_id)
    return geofences
