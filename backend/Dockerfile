# backend/Dockerfile - Multi-stage Docker build for OptiWork AI Backend

# ============================================================================
# STAGE 1: Builder
# ============================================================================

FROM python:3.11-slim as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Create wheels for dependencies
RUN pip install --no-cache-dir --upgrade pip wheel setuptools && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

# ============================================================================
# STAGE 2: Runtime
# ============================================================================

FROM python:3.11-slim

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl3 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels from builder
COPY --from=builder /wheels /wheels

# Copy requirements
COPY --from=builder /app/requirements.txt .

# Install dependencies from wheels
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt && \
    rm -rf /wheels

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=2)"

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

# ============================================================================
# DOCKER BUILD COMMANDS
# ============================================================================
# 
# Development Build:
# docker build -t optiwork/backend:dev .
#
# Production Build with tag:
# docker build -t optiwork/backend:latest -t optiwork/backend:1.0.0 .
#
# Run locally:
# docker run -p 8000:8000 \
#   -e DATABASE_URL="postgresql://user:pass@db:5432/optiwork" \
#   -e REDIS_URL="redis://redis:6379/0" \
#   optiwork/backend:latest
