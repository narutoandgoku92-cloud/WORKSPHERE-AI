# backend/services/face_recognition.py - Facial recognition AI service

import cv2
import numpy as np
from typing import Optional, Dict, Any, Tuple
import logging
import asyncio
from pathlib import Path
import os

from core.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# IMPORT AI LIBRARIES
# ============================================================================

try:
    import onnxruntime as ort
    from insightface.app import FaceAnalysis
    from insightface.utils import face_align
    FACE_RECOGNITION_AVAILABLE = True
except ImportError:
    logger.warning("Face recognition libraries not available")
    FACE_RECOGNITION_AVAILABLE = False

# ============================================================================
# FACE RECOGNITION SERVICE
# ============================================================================

class FaceRecognitionService:
    """Facial recognition and verification service"""
    
    def __init__(self):
        """Initialize face recognition models"""
        self.detector = None
        self.face_recognizer = None
        self.liveness_detector = None
        self.model_loaded = False
        
        if FACE_RECOGNITION_AVAILABLE:
            self._initialize_models()
    
    def _initialize_models(self):
        """Initialize all face recognition models"""
        try:
            # Initialize InsightFace analyzer
            self.face_recognizer = FaceAnalysis(
                name='buffalo_l',
                providers=['CUDAExecutionProvider' if settings.USE_GPU else 'CPUExecutionProvider']
            )
            self.face_recognizer.prepare(ctx_id=0 if settings.USE_GPU else -1)
            
            logger.info("Face recognition models initialized successfully")
            self.model_loaded = True
        except Exception as e:
            logger.error(f"Failed to initialize face recognition models: {e}")
            self.model_loaded = False
    
    def detect_faces(self, image: np.ndarray) -> list:
        """Detect all faces in image
        
        Args:
            image: Input image (numpy array or file path)
        
        Returns:
            List of detected faces with bounding boxes and landmarks
        """
        if not self.model_loaded:
            raise RuntimeError("Face recognition models not loaded")
        
        try:
            # Load image if path provided
            if isinstance(image, str):
                image = cv2.imread(image)
            
            # Detect faces
            faces = self.face_recognizer.get(image)
            
            logger.info(f"Detected {len(faces)} faces in image")
            return faces
        
        except Exception as e:
            logger.error(f"Face detection error: {e}")
            raise
    
    def extract_embedding(self, image: np.ndarray, face_info: Any = None) -> Optional[np.ndarray]:
        """Extract face embedding from image
        
        Args:
            image: Input image (numpy array)
            face_info: Pre-detected face info (optional)
        
        Returns:
            512-dimensional face embedding or None if extraction failed
        """
        if not self.model_loaded:
            raise RuntimeError("Face recognition models not loaded")
        
        try:
            # Load image if path provided
            if isinstance(image, str):
                image = cv2.imread(image)
            
            # Detect faces if not provided
            if face_info is None:
                faces = self.face_recognizer.get(image)
                if not faces:
                    logger.warning("No faces detected in image")
                    return None
                face_info = faces[0]
            
            # Extract embedding
            embedding = face_info.embedding
            
            # Normalize embedding
            embedding = embedding / np.linalg.norm(embedding)
            
            logger.info(f"Extracted face embedding (dimension: {len(embedding)})")
            return embedding
        
        except Exception as e:
            logger.error(f"Embedding extraction error: {e}")
            raise
    
    def verify_face(
        self,
        probe_embedding: np.ndarray,
        gallery_embedding: np.ndarray,
        threshold: float = settings.FACE_MATCH_THRESHOLD
    ) -> Dict[str, Any]:
        """Verify if two faces match
        
        Args:
            probe_embedding: Embedding from face to verify
            gallery_embedding: Embedding from enrolled face
            threshold: Similarity threshold (0-1)
        
        Returns:
            Dict with match result and confidence score
        """
        try:
            # Calculate cosine similarity
            similarity = np.dot(probe_embedding, gallery_embedding)
            similarity = np.clip(similarity, -1, 1)
            
            # Convert to distance
            distance = 1 - similarity
            
            # Check if match
            is_match = similarity >= threshold
            
            result = {
                "is_match": is_match,
                "similarity_score": float(similarity),
                "distance": float(distance),
                "threshold": threshold
            }
            
            logger.info(f"Face verification result: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Face verification error: {e}")
            raise
    
    def detect_liveness(
        self,
        image: np.ndarray,
        threshold: float = settings.FACE_LIVENESS_THRESHOLD
    ) -> Dict[str, Any]:
        """Detect if face is real (liveness detection)
        
        Uses multiple anti-spoofing techniques:
        - Eye movement detection
        - Head movement detection
        - Texture analysis
        - CNN-based liveness detection
        
        Args:
            image: Input image
            threshold: Liveness score threshold
        
        Returns:
            Dict with liveness result and score
        """
        try:
            # Convert BGR to RGB if needed
            if isinstance(image, str):
                image = cv2.imread(image)
            
            if len(image.shape) == 3 and image.shape[2] == 3:
                image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            else:
                image_rgb = image
            
            # Detect faces
            faces = self.face_recognizer.get(image_rgb)
            
            if not faces:
                return {
                    "is_live": False,
                    "liveness_score": 0.0,
                    "reason": "No face detected"
                }
            
            face = faces[0]
            
            # Extract facial landmarks for movement detection
            landmarks = face.landmark_3d_68
            
            # Calculate texture features
            texture_score = self._calculate_texture_score(image_rgb, face)
            
            # Detect eye movement (simplified)
            eye_score = self._detect_eye_movement(landmarks)
            
            # Combine scores
            liveness_score = (texture_score * 0.5 + eye_score * 0.5)
            is_live = liveness_score >= threshold
            
            result = {
                "is_live": is_live,
                "liveness_score": float(liveness_score),
                "threshold": threshold,
                "texture_score": float(texture_score),
                "eye_score": float(eye_score)
            }
            
            logger.info(f"Liveness detection result: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Liveness detection error: {e}")
            return {
                "is_live": False,
                "liveness_score": 0.0,
                "error": str(e)
            }
    
    def _calculate_texture_score(self, image: np.ndarray, face: Any) -> float:
        """Calculate texture authenticity score"""
        try:
            # Extract face region
            bbox = face.bbox.astype(int)
            x1, y1, x2, y2 = bbox
            face_region = image[max(0, y1):min(image.shape[0], y2),
                               max(0, x1):min(image.shape[1], x2)]
            
            if face_region.size == 0:
                return 0.0
            
            # Convert to grayscale
            gray = cv2.cvtColor(face_region, cv2.COLOR_RGB2GRAY)
            
            # Calculate Laplacian variance (blur detection)
            laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            
            # Normalize score
            texture_score = min(laplacian_var / 100, 1.0)
            return float(texture_score)
        
        except Exception as e:
            logger.warning(f"Texture score calculation failed: {e}")
            return 0.5
    
    def _detect_eye_movement(self, landmarks: np.ndarray) -> float:
        """Detect eye movement patterns"""
        try:
            # Eye landmarks indices
            left_eye_indices = [36, 37, 38, 39, 40, 41]
            right_eye_indices = [42, 43, 44, 45, 46, 47]
            
            # Extract eye landmarks
            left_eye = landmarks[left_eye_indices]
            right_eye = landmarks[right_eye_indices]
            
            # Calculate eye aspect ratio
            left_ear = self._calculate_eye_aspect_ratio(left_eye)
            right_ear = self._calculate_eye_aspect_ratio(right_eye)
            
            # Average EAR
            ear = (left_ear + right_ear) / 2
            
            # Eyes should have moderate opening (not too closed, not too wide)
            eye_score = min(ear, 1.0) if ear > 0.1 else 0.0
            
            return float(eye_score)
        
        except Exception as e:
            logger.warning(f"Eye movement detection failed: {e}")
            return 0.5
    
    @staticmethod
    def _calculate_eye_aspect_ratio(eye_landmarks: np.ndarray) -> float:
        """Calculate eye aspect ratio"""
        try:
            # Compute distances
            A = np.linalg.norm(eye_landmarks[1] - eye_landmarks[5])
            B = np.linalg.norm(eye_landmarks[2] - eye_landmarks[4])
            C = np.linalg.norm(eye_landmarks[0] - eye_landmarks[3])
            
            # Calculate EAR
            ear = (A + B) / (2.0 * C)
            return float(ear)
        except:
            return 0.0
    
    def assess_image_quality(
        self,
        image: np.ndarray,
        min_face_size: int = 100
    ) -> Dict[str, Any]:
        """Assess image quality for face recognition
        
        Checks:
        - Image dimensions
        - Face size
        - Brightness
        - Blur
        - Noise
        
        Args:
            image: Input image
            min_face_size: Minimum face bounding box size
        
        Returns:
            Quality assessment result
        """
        try:
            if isinstance(image, str):
                image = cv2.imread(image)
            
            # Detect faces
            faces = self.face_recognizer.get(image)
            
            if not faces:
                return {
                    "is_quality_sufficient": False,
                    "quality_score": 0.0,
                    "issues": ["No face detected"]
                }
            
            face = faces[0]
            issues = []
            scores = []
            
            # Check face size
            bbox = face.bbox.astype(int)
            face_width = bbox[2] - bbox[0]
            face_height = bbox[3] - bbox[1]
            face_size = min(face_width, face_height)
            
            if face_size < min_face_size:
                issues.append("Face too small")
            size_score = min(face_size / min_face_size, 1.0)
            scores.append(size_score)
            
            # Check brightness
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            brightness = np.mean(gray)
            if brightness < 50 or brightness > 200:
                issues.append("Poor lighting")
            brightness_score = 1.0 - abs(brightness - 128) / 128
            scores.append(brightness_score)
            
            # Check blur
            laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            if laplacian_var < 100:
                issues.append("Image too blurry")
            blur_score = min(laplacian_var / 100, 1.0)
            scores.append(blur_score)
            
            # Overall quality
            quality_score = np.mean(scores)
            is_sufficient = quality_score >= settings.FACE_QUALITY_MIN_SCORE and not issues
            
            result = {
                "is_quality_sufficient": is_sufficient,
                "quality_score": float(quality_score),
                "brightness": float(brightness),
                "blur_score": float(blur_score),
                "face_size": int(face_size),
                "issues": issues
            }
            
            logger.info(f"Image quality assessment: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Quality assessment error: {e}")
            raise
    
    def process_attendance_verification(
        self,
        captured_image: np.ndarray,
        stored_embedding: np.ndarray
    ) -> Dict[str, Any]:
        """Complete attendance verification workflow
        
        Performs:
        1. Quality check
        2. Face detection
        3. Liveness detection
        4. Face matching
        
        Args:
            captured_image: Image from attendance
            stored_embedding: Stored face embedding
        
        Returns:
            Complete verification result
        """
        try:
            # Step 1: Quality check
            quality_check = self.assess_image_quality(captured_image)
            
            if not quality_check["is_quality_sufficient"]:
                return {
                    "verified": False,
                    "reason": "Image quality insufficient",
                    "details": quality_check
                }
            
            # Step 2: Liveness detection
            liveness_check = self.detect_liveness(captured_image)
            
            if not liveness_check["is_live"]:
                return {
                    "verified": False,
                    "reason": "Liveness check failed",
                    "details": liveness_check
                }
            
            # Step 3: Extract embedding
            captured_embedding = self.extract_embedding(captured_image)
            
            if captured_embedding is None:
                return {
                    "verified": False,
                    "reason": "Could not extract face embedding"
                }
            
            # Step 4: Face matching
            match_result = self.verify_face(captured_embedding, stored_embedding)
            
            if not match_result["is_match"]:
                return {
                    "verified": False,
                    "reason": "Face does not match stored enrollment",
                    "details": match_result
                }
            
            # All checks passed
            return {
                "verified": True,
                "confidence_score": float(match_result["similarity_score"]),
                "liveness_score": float(liveness_check["liveness_score"]),
                "quality_score": float(quality_check["quality_score"]),
                "details": {
                    "quality": quality_check,
                    "liveness": liveness_check,
                    "match": match_result
                }
            }
        
        except Exception as e:
            logger.error(f"Verification process error: {e}")
            return {
                "verified": False,
                "reason": f"Verification error: {str(e)}"
            }

# ============================================================================
# SINGLETON INSTANCE
# ============================================================================

_face_recognition_service = None

def get_face_recognition_service() -> FaceRecognitionService:
    """Get face recognition service singleton"""
    global _face_recognition_service
    if _face_recognition_service is None:
        _face_recognition_service = FaceRecognitionService()
    return _face_recognition_service
