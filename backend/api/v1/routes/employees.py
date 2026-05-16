# backend/api/v1/routes/employees.py - Employee management routes

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import base64
import io

from core.database import get_db
from schemas import EmployeeCreate, EmployeeUpdate, EmployeeResponse, EmployeeDetailResponse
from repositories import EmployeeRepository, FaceEmbeddingRepository
from api.v1.routes.auth import get_current_user

router = APIRouter(prefix="/employees", tags=["Employees"])

# ============================================================================
# EMPLOYEE ENDPOINTS
# ============================================================================

@router.post("", response_model=EmployeeResponse)
async def create_employee(
    employee_data: EmployeeCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create new employee"""
    
    # Check permission
    if current_user.role not in ["admin", "hr", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    # Check if employee ID already exists
    existing = EmployeeRepository.get_by_employee_id(
        db, current_user.org_id, employee_data.employee_id
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Employee ID already exists"
        )
    
    # Create employee
    employee = EmployeeRepository.create(
        db,
        org_id=current_user.org_id,
        employee_id=employee_data.employee_id,
        full_name=employee_data.full_name,
        email=employee_data.email,
        phone=employee_data.phone,
        job_title=employee_data.job_title,
        dept_id=employee_data.dept_id,
        salary_per_hour=employee_data.salary_per_hour,
        hire_date=employee_data.hire_date
    )
    
    return employee

@router.get("", response_model=List[EmployeeResponse])
async def list_employees(
    skip: int = 0,
    limit: int = 100,
    dept_id: str = None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List employees"""
    
    if dept_id:
        employees = EmployeeRepository.list_dept_employees(db, dept_id)
    else:
        employees = EmployeeRepository.list_org_employees(db, current_user.org_id, skip, limit)
    
    return employees

@router.get("/{employee_id}", response_model=EmployeeDetailResponse)
async def get_employee(
    employee_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get employee details"""
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    return employee

@router.put("/{employee_id}", response_model=EmployeeResponse)
async def update_employee(
    employee_id: str,
    employee_data: EmployeeUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update employee"""
    
    # Check permission
    if current_user.role not in ["admin", "hr", "manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Update employee
    update_data = employee_data.dict(exclude_unset=True)
    employee = EmployeeRepository.update(db, employee_id, **update_data)
    
    return employee

@router.delete("/{employee_id}")
async def delete_employee(
    employee_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete employee"""
    
    # Check permission
    if current_user.role not in ["admin", "hr"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized"
        )
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    db.delete(employee)
    db.commit()
    
    return {"message": "Employee deleted successfully"}

@router.post("/{employee_id}/upload-photo")
async def upload_employee_photo(
    employee_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Upload employee profile photo"""
    
    employee = EmployeeRepository.get_by_id(db, employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    # Read file content
    contents = await file.read()
    
    # For now, just return success
    # In production, upload to S3 or similar
    
    return {
        "message": "Photo uploaded successfully",
        "filename": file.filename
    }
