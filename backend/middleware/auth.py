# backend/middleware/auth.py - JWT Authentication Middleware

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import logging
from typing import Optional

logger = logging.getLogger(__name__)

class JWTMiddleware(BaseHTTPMiddleware):
    """JWT token validation middleware"""
    
    async def dispatch(self, request: Request, call_next):
        # Skip middleware for public endpoints
        public_endpoints = [
            "/api/docs",
            "/api/redoc",
            "/api/openapi.json",
            "/health",
            "/health/live",
            "/health/ready",
            "/api/v1/auth/login",
            "/api/v1/auth/register",
            "/api/v1/auth/refresh"
        ]
        
        if any(request.url.path.startswith(endpoint) for endpoint in public_endpoints):
            return await call_next(request)
        
        # For now, pass all requests through
        # Full JWT validation will be handled in route decorators
        response = await call_next(request)
        return response
