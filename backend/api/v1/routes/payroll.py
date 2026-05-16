# backend/api/v1/routes/payroll.py - Payroll and compensation routes

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List, Optional
from datetime import datetime
import logging
import json
import re

from core.config import settings
from core.database import get_db
from services.squad import SquadService, SquadPaymentError
from schemas import (
    PayrollRecordResponse,
    PayrollSummaryResponse,
    PayrollReportRequest,
    BankDetails,
    SalaryPayoutRequest,
    BulkSalaryPayoutRequest,
    SalaryPayoutResult,
    TransactionResponse,
    PaymentStatusResponse,
    PaymentStatus,
)
from repositories import (
    PayrollRepository,
    EmployeeRepository,
    AttendanceRepository,
    PaymentTransactionRepository,
    SalaryDisbursementRepository,
    AuditLogRepository,
)
from models import AttendanceLog
from api.v1.routes.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Payroll"])

# ============================================================================
# UTILITY HELPERS
# ============================================================================

def _mask_account_number(account_number: str) -> str:
    digits = re.sub(r"\D", "", account_number)
    if len(digits) >= 4:
        return f"****{digits[-4:]}"
    return "****"


def _calculate_payroll(employee, logs: List[AttendanceLog]):
    total_hours = 0.0
    for log in logs:
        if log.check_out_time:
            delta = log.check_out_time - log.check_in_time
            total_hours += delta.total_seconds() / 3600

    regular_hours = min(total_hours, len(logs) * 8)
    overtime_hours = max(0.0, total_hours - regular_hours)
    regular_pay = regular_hours * employee.salary_per_hour
    overtime_pay = overtime_hours * employee.salary_per_hour * settings.OVERTIME_MULTIPLIER
    gross_pay = round(regular_pay + overtime_pay, 2)
    deductions = round(gross_pay * settings.PAYROLL_TAX_PERCENTAGE, 2)
    net_pay = round(gross_pay - deductions, 2)

    return {
        "regular_hours": round(regular_hours, 2),
        "overtime_hours": round(overtime_hours, 2),
        "regular_pay": round(regular_pay, 2),
        "overtime_pay": round(overtime_pay, 2),
        "total_pay": gross_pay,
        "deductions": deductions,
        "net_pay": net_pay,
    }


def _verify_admin(current_user) -> None:
    if current_user.role not in ["admin", "hr"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to perform payroll operations"
        )


async def _create_payroll_record(db: Session, employee, period_start: datetime, period_end: datetime, payroll_data: dict):
    return PayrollRepository.create(
        db,
        employee_id=employee.id,
        org_id=employee.org_id,
        period_start=period_start,
        period_end=period_end,
        daily_rate=employee.salary_per_hour * 8,
        regular_hours=payroll_data["regular_hours"],
        overtime_hours=payroll_data["overtime_hours"],
        regular_pay=payroll_data["regular_pay"],
        overtime_pay=payroll_data["overtime_pay"],
        bonus_pay=0.0,
        total_pay=payroll_data["total_pay"],
        deductions=payroll_data["deductions"],
        net_pay=payroll_data["net_pay"],
        payment_status="pending",
    )


# ============================================================================
# PAYROLL ENDPOINTS
# ============================================================================

@router.get("/current", response_model=PayrollSummaryResponse)
async def get_current_payroll(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get current payroll estimation for logged-in employee."""
    employee = EmployeeRepository.get_by_id(db, current_user.id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found")

    month_start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    today = datetime.utcnow()
    logs = AttendanceRepository.get_employee_logs(db, employee.id, days=(today - month_start).days + 1)

    payroll_data = _calculate_payroll(employee, logs)

    return PayrollSummaryResponse(
        employee_name=employee.full_name,
        regular_hours=payroll_data["regular_hours"],
        overtime_hours=payroll_data["overtime_hours"],
        daily_rate=employee.salary_per_hour * 8,
        estimated_salary=payroll_data["total_pay"],
        last_payment_date=None,
    )


@router.post("/process-salary", response_model=SalaryPayoutResult)
async def process_salary_payout(
    request: SalaryPayoutRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Process salary payout for a single employee using Squad."""
    _verify_admin(current_user)

    employee = EmployeeRepository.get_by_id(db, request.employee_id)
    if not employee or employee.org_id != current_user.org_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found")

    if employee.status != "active":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Employee is not eligible for payout")

    if request.period_end < request.period_start:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid payroll period")

    logs = db.query(AttendanceLog).filter(
        and_(
            AttendanceLog.employee_id == employee.id,
            AttendanceLog.check_in_time >= request.period_start,
            AttendanceLog.check_in_time <= request.period_end,
        )
    ).all()

    payroll_data = _calculate_payroll(employee, logs)
    if payroll_data["net_pay"] <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Calculated salary must be greater than zero")

    duplicate = SalaryDisbursementRepository.get_duplicate(
        db,
        employee_id=employee.id,
        period_start=request.period_start,
        period_end=request.period_end,
    )
    if duplicate:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Payroll payout already exists for this period")

    payroll_record = await _create_payroll_record(db, employee, request.period_start, request.period_end, payroll_data)
    disbursement = SalaryDisbursementRepository.create(
        db,
        org_id=current_user.org_id,
        employee_id=employee.id,
        payroll_record_id=payroll_record.id,
        amount=payroll_data["net_pay"],
        currency=request.currency or settings.PAYROLL_DEFAULT_CURRENCY,
        bank_name=request.bank_details.bank_name,
        bank_account_mask=_mask_account_number(request.bank_details.account_number),
        account_holder_name=request.bank_details.account_holder_name,
        description=request.description,
        status="processing",
    )

    squad = SquadService()
    payment_response = None
    transaction = None
    try:
        payment_response = await squad.initiate_payout(
            employee_id=employee.id,
            amount=payroll_data["net_pay"],
            currency=request.currency or settings.PAYROLL_DEFAULT_CURRENCY,
            bank_name=request.bank_details.bank_name,
            account_holder_name=request.bank_details.account_holder_name,
            account_number=request.bank_details.account_number,
            routing_number=request.bank_details.routing_number,
            description=request.description,
            metadata={
                "employee_id": employee.id,
                "org_id": employee.org_id,
                "payroll_period": f"{request.period_start.date()}_{request.period_end.date()}",
            },
        )

        transaction = PaymentTransactionRepository.create(
            db,
            org_id=current_user.org_id,
            employee_id=employee.id,
            payroll_record_id=payroll_record.id,
            amount=payroll_data["net_pay"],
            currency=request.currency or settings.PAYROLL_DEFAULT_CURRENCY,
            external_transaction_id=payment_response.get("id") or payment_response.get("transaction_id"),
            status=payment_response.get("status", "processing"),
            provider_response=json.dumps(payment_response),
            provider_metadata=json.dumps({
                "employee_id": employee.id,
                "org_id": employee.org_id,
                "payroll_period": f"{request.period_start.date()}_{request.period_end.date()}",
            }),
        )

        AuditLogRepository.create(
            db,
            org_id=current_user.org_id,
            user_id=current_user.id,
            action="salary_payout",
            resource_type="payment_transaction",
            resource_id=transaction.id,
            new_value=json.dumps({
                "transaction_id": transaction.id,
                "employee_id": employee.id,
                "amount": transaction.amount,
                "status": transaction.status,
            }),
        )

        SalaryDisbursementRepository.update_status(
            db,
            disbursement_id=disbursement.id,
            status="succeeded" if payment_response.get("status") == "success" else "processing",
            transaction_id=transaction.id,
            completed_at=datetime.utcnow(),
        )

        return SalaryPayoutResult(
            employee_id=employee.id,
            payroll_record_id=payroll_record.id,
            salary_disbursement_id=disbursement.id,
            transaction_id=transaction.id,
            status=transaction.status,
            amount=payroll_data["net_pay"],
            currency=request.currency or settings.PAYROLL_DEFAULT_CURRENCY,
            message="Salary payout initiated successfully",
        )
    except SquadPaymentError as exc:
        failure_reason = str(exc)
        transaction = PaymentTransactionRepository.create(
            db,
            org_id=current_user.org_id,
            employee_id=employee.id,
            payroll_record_id=payroll_record.id,
            amount=payroll_data["net_pay"],
            currency=request.currency or settings.PAYROLL_DEFAULT_CURRENCY,
            status=PaymentStatus.FAILED.value,
            failure_reason=failure_reason,
            provider_response=json.dumps(payment_response or {}),
        )
        AuditLogRepository.create(
            db,
            org_id=current_user.org_id,
            user_id=current_user.id,
            action="salary_payout_failure",
            resource_type="payment_transaction",
            resource_id=transaction.id,
            new_value=json.dumps({
                "transaction_id": transaction.id,
                "employee_id": employee.id,
                "amount": transaction.amount,
                "status": transaction.status,
                "failure_reason": failure_reason,
            }),
            status="failed",
            error_message=failure_reason,
        )
        SalaryDisbursementRepository.update_status(
            db,
            disbursement_id=disbursement.id,
            status="failed",
            failure_reason=failure_reason,
            transaction_id=transaction.id,
            completed_at=datetime.utcnow(),
        )
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Payment provider error: {failure_reason}")


@router.post("/bulk-pay", response_model=List[SalaryPayoutResult])
async def bulk_salary_payout(
    request: BulkSalaryPayoutRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Process salary payouts for multiple employees."""
    _verify_admin(current_user)

    results: List[SalaryPayoutResult] = []
    squad = SquadService()

    for item in request.payouts:
        try:
            employee = EmployeeRepository.get_by_id(db, item.employee_id)
            if not employee or employee.org_id != current_user.org_id:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found")
            if employee.status != "active":
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Employee is not eligible for payout")
            if item.period_end < item.period_start:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid payroll period")

            logs = db.query(AttendanceLog).filter(
                and_(
                    AttendanceLog.employee_id == employee.id,
                    AttendanceLog.check_in_time >= item.period_start,
                    AttendanceLog.check_in_time <= item.period_end,
                )
            ).all()
            payroll_data = _calculate_payroll(employee, logs)
            if payroll_data["net_pay"] <= 0:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Calculated salary must be greater than zero")

            duplicate = SalaryDisbursementRepository.get_duplicate(
                db,
                employee_id=employee.id,
                period_start=item.period_start,
                period_end=item.period_end,
            )
            if duplicate:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Payroll payout already exists for this period")

            payroll_record = await _create_payroll_record(db, employee, item.period_start, item.period_end, payroll_data)
            disbursement = SalaryDisbursementRepository.create(
                db,
                org_id=current_user.org_id,
                employee_id=employee.id,
                payroll_record_id=payroll_record.id,
                amount=payroll_data["net_pay"],
                currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                bank_name=item.bank_details.bank_name,
                bank_account_mask=_mask_account_number(item.bank_details.account_number),
                account_holder_name=item.bank_details.account_holder_name,
                description=item.description,
                status="processing",
            )
            payment_response = await squad.initiate_payout(
                employee_id=employee.id,
                amount=payroll_data["net_pay"],
                currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                bank_name=item.bank_details.bank_name,
                account_holder_name=item.bank_details.account_holder_name,
                account_number=item.bank_details.account_number,
                routing_number=item.bank_details.routing_number,
                description=item.description,
                metadata={
                    "employee_id": employee.id,
                    "org_id": employee.org_id,
                    "payroll_period": f"{item.period_start.date()}_{item.period_end.date()}",
                },
            )
            transaction = PaymentTransactionRepository.create(
                db,
                org_id=current_user.org_id,
                employee_id=employee.id,
                payroll_record_id=payroll_record.id,
                amount=payroll_data["net_pay"],
                currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                external_transaction_id=payment_response.get("id") or payment_response.get("transaction_id"),
                status=payment_response.get("status", "processing"),
                provider_response=json.dumps(payment_response),
                provider_metadata=json.dumps({
                    "employee_id": employee.id,
                    "org_id": employee.org_id,
                    "payroll_period": f"{item.period_start.date()}_{item.period_end.date()}",
                }),
            )
            AuditLogRepository.create(
                db,
                org_id=current_user.org_id,
                user_id=current_user.id,
                action="bulk_salary_payout",
                resource_type="payment_transaction",
                resource_id=transaction.id,
                new_value=json.dumps({
                    "transaction_id": transaction.id,
                    "employee_id": employee.id,
                    "amount": transaction.amount,
                    "status": transaction.status,
                }),
            )
            SalaryDisbursementRepository.update_status(
                db,
                disbursement_id=disbursement.id,
                status="succeeded" if payment_response.get("status") == "success" else "processing",
                transaction_id=transaction.id,
                completed_at=datetime.utcnow(),
            )
            results.append(
                SalaryPayoutResult(
                    employee_id=employee.id,
                    payroll_record_id=payroll_record.id,
                    salary_disbursement_id=disbursement.id,
                    transaction_id=transaction.id,
                    status=transaction.status,
                    amount=payroll_data["net_pay"],
                    currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                    message="Salary payout initiated",
                )
            )
        except HTTPException as exc:
            results.append(
                SalaryPayoutResult(
                    employee_id=item.employee_id,
                    payroll_record_id="",
                    salary_disbursement_id="",
                    transaction_id="",
                    status=PaymentStatus.FAILED.value,
                    amount=0.0,
                    currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                    message=str(exc.detail),
                )
            )
        except SquadPaymentError as exc:
            results.append(
                SalaryPayoutResult(
                    employee_id=item.employee_id,
                    payroll_record_id="",
                    salary_disbursement_id="",
                    transaction_id="",
                    status=PaymentStatus.FAILED.value,
                    amount=0.0,
                    currency=item.currency or settings.PAYROLL_DEFAULT_CURRENCY,
                    message=f"Payment provider error: {str(exc)}",
                )
            )
            AuditLogRepository.create(
                db,
                org_id=current_user.org_id,
                user_id=current_user.id,
                action="bulk_salary_payout_failure",
                resource_type="payroll_request",
                resource_id=item.employee_id,
                status="failed",
                error_message=str(exc),
                new_value=json.dumps({
                    "employee_id": item.employee_id,
                    "amount": 0,
                    "error": str(exc),
                }),
            )

    return results


@router.get("/transactions", response_model=List[TransactionResponse])
async def list_payroll_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List payroll payment transactions for the current organization."""
    _verify_admin(current_user)
    transactions = PaymentTransactionRepository.list_org_transactions(db, current_user.org_id, skip=skip, limit=limit)
    return transactions


@router.get("/status/{transaction_id}", response_model=PaymentStatusResponse)
async def get_transaction_status(
    transaction_id: str,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get payment transaction status by transaction ID."""
    _verify_admin(current_user)
    transaction = PaymentTransactionRepository.get_by_id(db, transaction_id)
    if not transaction or transaction.org_id != current_user.org_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    return PaymentStatusResponse(
        id=transaction.id,
        status=transaction.status,
        type="transaction",
        message="Payment transaction status retrieved successfully",
        details={
            "external_transaction_id": transaction.external_transaction_id,
            "amount": transaction.amount,
            "currency": transaction.currency,
            "provider": transaction.provider,
            "failure_reason": transaction.failure_reason,
            "payroll_record_id": transaction.payroll_record_id,
        },
    )


@router.post("/calculate")
async def calculate_payroll(
    request: PayrollReportRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Calculate payroll for period."""
    _verify_admin(current_user)

    employees = (
        EmployeeRepository.list_org_employees(db, current_user.org_id, skip=0, limit=10000)
        if not request.department_id
        else EmployeeRepository.list_dept_employees(db, request.department_id)
    )

    payroll_records = []
    total_payroll = 0.0

    for employee in employees:
        logs = db.query(AttendanceLog).filter(
            and_(
                AttendanceLog.employee_id == employee.id,
                AttendanceLog.check_in_time >= request.period_start,
                AttendanceLog.check_in_time <= request.period_end,
            )
        ).all()
        payroll_data = _calculate_payroll(employee, logs)
        payroll_records.append({
            "employee_id": employee.id,
            "employee_name": employee.full_name,
            "regular_hours": payroll_data["regular_hours"],
            "overtime_hours": payroll_data["overtime_hours"],
            "regular_pay": payroll_data["regular_pay"],
            "overtime_pay": payroll_data["overtime_pay"],
            "total_pay": payroll_data["total_pay"],
            "deductions": payroll_data["deductions"],
            "net_pay": payroll_data["net_pay"],
        })
        total_payroll += payroll_data["total_pay"]

    return {
        "period_start": request.period_start,
        "period_end": request.period_end,
        "employee_count": len(employees),
        "payroll_records": payroll_records,
        "total_payroll": round(total_payroll, 2),
    }
