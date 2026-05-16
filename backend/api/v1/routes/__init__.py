# backend/api/v1/routes/__init__.py
from fastapi import APIRouter
from . import auth, users, attendance, face_recognition, gps, analytics, payroll, admin

router = APIRouter()
