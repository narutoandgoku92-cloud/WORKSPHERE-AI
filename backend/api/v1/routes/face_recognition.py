# backend/api/v1/routes/face_recognition.py - Face recognition routes

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import base64

from core.database import get_db
from schemas import FaceEnrollmentRequest, FaceVerificationRequest, FaceVerificationResponse
from repositories import FaceEmbeddingRepository, EmployeeRepository
from api.v1.routes.auth import get_current_user

from services.face_recognition import FaceRecognitionService
import numpy as np
import cv2
import io

router = APIRouter(tags=["Face Recognition"])
face_service = FaceRecognitionService()

# ============================================================================
# FACE RECOGNITION ENDPOINTS
# ============================================================================

@router.post("/enroll")
async def enroll_face(
    request: FaceEnrollmentRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Enroll employee face for recognition"""
    
    # Get employee
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    try:
        # Decode base64 image
        image_data = base64.b64decode(request.face_image.split(",")[-1] if "," in request.face_image else request.face_image)
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image data")

        # Extract embedding
        embedding = face_service.extract_embedding(image)
        if embedding is None:
            raise HTTPException(status_code=400, detail="No face detected in image")

        # Convert embedding to string for storage
        embedding_str = ",".join(map(str, embedding.tolist()))
        
        face_emb = FaceEmbeddingRepository.create(
            db,
            employee_id=employee.id,
            embedding=embedding_str,
            quality_score=0.95
        )
        
        # Mark employee as verified
        EmployeeRepository.update(db, employee.id, is_verified=True)
        
        return {
            "message": "Face enrolled successfully",
            "quality_score": 0.95
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.post("/verify", response_model=FaceVerificationResponse)
async def verify_face(
    request: FaceVerificationRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Verify face for check-in"""
    
    # Get employee
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")

    # Get stored embedding
    stored_face = FaceEmbeddingRepository.get_primary(db, employee.id)
    if not stored_face:
        # Fallback to any face if primary not found
        stored_faces = FaceEmbeddingRepository.get_all_employee(db, employee.id)
        if not stored_faces:
            raise HTTPException(status_code=400, detail="No face enrolled for this employee")
        stored_face = stored_faces[0]

    try:
        # Decode captured image
        image_data = base64.b64decode(request.face_image.split(",")[-1] if "," in request.face_image else request.face_image)
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image data")

        # Extract current embedding
        current_embedding = face_service.extract_embedding(image)
        if current_embedding is None:
            raise HTTPException(status_code=400, detail="No face detected in captured image")

        # Parse stored embedding
        stored_embedding = np.array([float(x) for x in stored_face.embedding.split(",")])

        # Verify
        result = face_service.verify_face(current_embedding, stored_embedding)
        
        return FaceVerificationResponse(
            verified=result["is_match"],
            confidence=result["similarity_score"],
            match_id=employee.id,
            message="Face verified" if result["is_match"] else "Face mismatch"
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
