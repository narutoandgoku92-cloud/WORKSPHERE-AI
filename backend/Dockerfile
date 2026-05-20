FROM python:3.11-slim

WORKDIR /app

# Prevent Python from writing pyc files + better logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies (IMPORTANT for OpenCV + ML libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    postgresql-client \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (better caching)
COPY requirements.txt .

# Upgrade pip tools
RUN pip install --upgrade pip setuptools wheel

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user (safer)
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

ENV PORT=8000

# Expose FastAPI port (from env)
EXPOSE ${PORT}

# HEALTHCHECK - valid syntax with /bin/sh -c wrapper for environment variable expansion
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD /bin/sh -c "python -c \"import requests, os; requests.get(f'http://127.0.0.1:{os.getenv(\\\"PORT\\\",\\\"8000\\\")}/health', timeout=3)\""

# Run FastAPI using the PORT env variable (shell form to expand env)
CMD sh -c "exec uvicorn main:app --host 0.0.0.0 --port ${PORT}"