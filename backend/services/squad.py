# backend/services/squad.py - Secure Squad payment gateway integration

import asyncio
import json
import logging
import re
from typing import Any, Dict, Optional

import httpx

from core.config import settings

logger = logging.getLogger(__name__)

class SquadPaymentError(Exception):
    """Raised when a Squad payout attempt fails."""

class SquadService:
    """Service layer for Squad payment integration."""

    def __init__(self):
        self.base_url = settings.SQUAD_API_BASE_URL.rstrip("/")
        self.api_key = settings.SQUAD_API_KEY
        self.api_secret = settings.SQUAD_API_SECRET
        self.payout_path = settings.SQUAD_PAYOUT_PATH
        self.timeout = settings.SQUAD_REQUEST_TIMEOUT
        self.max_retries = settings.SQUAD_RETRY_LIMIT
        self.backoff_seconds = settings.SQUAD_RETRY_BACKOFF_SECONDS

        if not self.api_key or not self.api_secret:
            logger.warning("Squad API key/secret missing - payout calls will fail until configured.")

    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "X-Squad-Api-Secret": self.api_secret,
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    @staticmethod
    def _sanitize_amount(amount: float) -> float:
        return round(max(amount, 0.0), 2)

    async def _post(self, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        last_exception: Optional[Exception] = None

        for attempt in range(1, self.max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, json=payload, headers=self._headers())
                    if response.status_code >= 500:
                        raise httpx.HTTPStatusError(
                            message="Server error",
                            request=response.request,
                            response=response
                        )
                    response_data = response.json()
                    if response.status_code not in (200, 201, 202):
                        message = response_data.get("message") or response_data.get("error") or response.text
                        raise SquadPaymentError(f"Squad API failure ({response.status_code}): {message}")
                    return response_data
            except (httpx.TimeoutException, httpx.NetworkError, httpx.HTTPStatusError) as exc:
                last_exception = exc
                if attempt >= self.max_retries:
                    break
                delay = self.backoff_seconds * attempt
                logger.warning(
                    "Squad request failed on attempt %s/%s: %s. Retrying in %s seconds",
                    attempt,
                    self.max_retries,
                    str(exc),
                    delay,
                )
                await asyncio.sleep(delay)
            except json.JSONDecodeError as exc:
                raise SquadPaymentError("Invalid JSON response from Squad API") from exc
            except Exception as exc:
                raise SquadPaymentError(f"Unexpected Squad request failure: {exc}") from exc

        raise SquadPaymentError(f"Squad request failed after {self.max_retries} attempts: {last_exception}")

    async def initiate_payout(
        self,
        employee_id: str,
        amount: float,
        currency: str,
        bank_name: str,
        account_holder_name: str,
        account_number: str,
        routing_number: str,
        description: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Initiate a Squad payout without exposing secrets to the client."""
        if amount <= 0:
            raise SquadPaymentError("Payout amount must be greater than zero")

        payload = {
            "employee_id": employee_id,
            "amount": self._sanitize_amount(amount),
            "currency": currency.upper(),
            "destination": {
                "bank_name": bank_name,
                "account_holder_name": account_holder_name,
                "account_number": account_number,
                "routing_number": routing_number,
            },
            "description": description or f"Salary payout for employee {employee_id}",
            "metadata": metadata or {},
        }

        logger.info("Initiating Squad payout for employee=%s amount=%s %s", employee_id, amount, currency)
        response = await self._post(self.payout_path, payload)

        logger.info(
            "Squad payout response for employee=%s status=%s external_id=%s",
            employee_id,
            response.get("status"),
            response.get("id") or response.get("transaction_id"),
        )

        return response
