# backend/middleware/error_handler.py - Global Error Handler

from fastapi import Request, status
from starlette.responses import JSONResponse
import logging
import traceback

logger = logging.getLogger(__name__)

async def error_handler(request: Request, exc: Exception):
    """Global exception handler"""
    
    # Log error
    logger.error(f"Error: {str(exc)}\n{traceback.format_exc()}")
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal server error",
            "detail": str(exc) if str(exc) else "An unexpected error occurred",
            "path": str(request.url.path)
        }
    )
