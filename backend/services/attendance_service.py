# CRITICAL FIX #3: Duplicate Check-in Prevention
# backend/services/attendance_service.py - Production-grade attendance service

from datetime import datetime, timedelta, date
from typing import Optional, Dict, Any, Tuple
from sqlalchemy import and_
from sqlalchemy.exc import IntegrityError
import logging
import numpy as np
import cv2
import base64

logger = logging.getLogger(__name__)

class AttendanceService:
    """Production-grade attendance tracking service"""
    
    @staticmethod
    def check_duplicate_checkin(db, employee_id: str) -> Tuple[bool, Optional[str]]:
        """
        Check if employee already checked in today (atomic operation)
        
        Returns: (is_duplicate: bool, existing_checkin_id: str or None)
        """
        from models import AttendanceLog
        
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        
        try:
            # Use row-level lock to prevent race condition
            existing = db.query(AttendanceLog).filter(
                and_(
                    AttendanceLog.employee_id == employee_id,
                    AttendanceLog.check_in_time >= today_start,
                    AttendanceLog.check_in_time < today_end,
                    AttendanceLog.check_out_time.is_(None)  # Still checked in
                )
            ).with_for_update().first()  # ✅ Database-level lock
            
            if existing:
                return (True, existing.id)
            
            return (False, None)
        
        except Exception as e:
            logger.error(f"Duplicate check-in detection error: {e}")
            return (False, None)
    
    @staticmethod
    def create_checkin(db, employee_id: str, org_id: str, **kwargs) -> Optional[Dict[str, Any]]:
        """
        Create check-in with duplicate prevention
        
        Returns: attendance record or None on failure
        """
        from models import AttendanceLog
        from repositories import EmployeeRepository
        import uuid
        
        try:
            # Verify employee exists and belongs to org
            employee = EmployeeRepository.get_by_id(db, employee_id)
            if not employee or employee.org_id != org_id:
                return None
            
            # Check for duplicate (atomic)
            is_duplicate, existing_id = AttendanceService.check_duplicate_checkin(db, employee_id)
            if is_duplicate:
                logger.warning(f"Duplicate check-in attempt for {employee_id}")
                return None
            
            # Create attendance record
            attendance = AttendanceLog(
                id=str(uuid.uuid4()),
                employee_id=employee_id,
                org_id=org_id,
                check_in_time=datetime.utcnow(),
                **kwargs
            )
            
            db.add(attendance)
            db.commit()
            db.refresh(attendance)
            
            logger.info(f"✅ Check-in created for {employee_id}: {attendance.id}")
            
            return {
                "id": attendance.id,
                "employee_id": attendance.employee_id,
                "check_in_time": attendance.check_in_time.isoformat(),
                "verified": kwargs.get("check_in_verified", False)
            }
        
        except IntegrityError as e:
            db.rollback()
            logger.error(f"IntegrityError creating check-in: {e}")
            return None
        
        except Exception as e:
            db.rollback()
            logger.error(f"Check-in creation error: {e}")
            return None
    
    @staticmethod
    def create_checkout(db, employee_id: str, **kwargs) -> Optional[Dict[str, Any]]:
        """Create check-out for existing check-in"""
        from models import AttendanceLog
        
        try:
            today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            today_end = today_start + timedelta(days=1)
            
            # Get today's check-in
            attendance = db.query(AttendanceLog).filter(
                and_(
                    AttendanceLog.employee_id == employee_id,
                    AttendanceLog.check_in_time >= today_start,
                    AttendanceLog.check_in_time < today_end,
                    AttendanceLog.check_out_time.is_(None)
                )
            ).first()
            
            if not attendance:
                return None
            
            # Update check-out
            attendance.check_out_time = datetime.utcnow()
            
            # Update other fields if provided
            for key, value in kwargs.items():
                if hasattr(attendance, key):
                    setattr(attendance, key, value)
            
            db.commit()
            db.refresh(attendance)
            
            # Calculate work hours
            duration = attendance.check_out_time - attendance.check_in_time
            hours_worked = duration.total_seconds() / 3600
            
            logger.info(f"✅ Check-out created for {employee_id}: {hours_worked:.2f} hours")
            
            return {
                "id": attendance.id,
                "employee_id": attendance.employee_id,
                "check_in_time": attendance.check_in_time.isoformat(),
                "check_out_time": attendance.check_out_time.isoformat(),
                "duration_hours": hours_worked
            }
        
        except Exception as e:
            db.rollback()
            logger.error(f"Check-out creation error: {e}")
            return None
    
    @staticmethod
    def validate_checkin_data(
        latitude: float,
        longitude: float,
        face_image: Optional[str] = None
    ) -> Tuple[bool, str]:
        """Validate check-in request data"""
        
        # Validate GPS coordinates
        if not (-90 <= latitude <= 90):
            return (False, "Invalid latitude")
        
        if not (-180 <= longitude <= 180):
            return (False, "Invalid longitude")
        
        # Validate face image if provided
        if face_image:
            if len(face_image) > 5000000:  # 5MB max
                return (False, "Face image too large")
            
            if len(face_image) < 1000:
                return (False, "Face image too small")
            
            # Try to decode to verify it's valid base64
            try:
                image_data_str = face_image
                if "," in face_image:
                    image_data_str = face_image.split(",")[1]
                
                image_data = base64.b64decode(image_data_str)
                nparr = np.frombuffer(image_data, np.uint8)
                image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                
                if image is None:
                    return (False, "Invalid face image data")
            
            except Exception as e:
                return (False, f"Face image decode error: {str(e)}")
        
        return (True, "Valid")
