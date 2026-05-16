# SETUP_GUIDE.md - OptiWork AI Complete Setup Instructions

## QUICK START (5 MINUTES)

```bash
# Prerequisites: Docker, Docker Compose installed

git clone https://github.com/optiwork/optiwork-ai.git
cd optiwork-ai

# Copy and edit environment files
cp .env.example .env
cp backend/.env.example backend/.env
cp web/.env.example web/.env

# Start development environment
docker-compose up -d

# Run database migrations
docker-compose exec backend alembic upgrade head

# Access services
# Backend API: http://localhost:8000/api/docs
# Web Dashboard: http://localhost:3000
# Database: http://localhost:5050 (pgadmin/admin)
```

---

## DETAILED SETUP

### 1. Environment Setup

#### System Requirements
- OS: Linux, macOS, or Windows 10+
- Docker: 20.10+
- Docker Compose: 1.29+
- Git: 2.30+
- RAM: 8GB minimum (16GB recommended)
- Disk Space: 20GB free

#### Installation

**macOS/Linux:**
```bash
# Install Homebrew (macOS)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker
brew install docker docker-compose

# Install Git
brew install git

# Verify installation
docker --version
docker-compose --version
git --version
```

**Windows:**
- Download and install Docker Desktop from https://www.docker.com/products/docker-desktop
- Docker Desktop includes Docker Compose

### 2. Repository Setup

```bash
# Clone repository
git clone https://github.com/optiwork/optiwork-ai.git
cd optiwork-ai

# Create feature branch
git checkout -b feature/your-feature-name

# Configure git
git config user.name "Your Name"
git config user.email "your@email.com"
```

### 3. Configuration Files

Create `.env` file in project root:

```env
# Environment
DEBUG=true
ENVIRONMENT=development

# Database
DATABASE_URL=postgresql://optiwork:optiwork_dev_password@postgres:5432/optiwork
DATABASE_ECHO=false
DATABASE_POOL_SIZE=20

# Redis
REDIS_URL=redis://:redis_dev_password@redis:6379/0

# Security
SECRET_KEY=your-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# AWS (for local development, use defaults)
AWS_REGION=us-east-1
AWS_S3_BUCKET=optiwork-dev

# Email (use Mailhog for local development)
SMTP_SERVER=mailhog
SMTP_PORT=1025
SMTP_USERNAME=dev
SMTP_PASSWORD=dev
SMTP_FROM_EMAIL=noreply@optiwork.local

# AI/ML
FACE_MATCH_THRESHOLD=0.6
FACE_LIVENESS_THRESHOLD=0.7
FACE_QUALITY_MIN_SCORE=0.7
USE_GPU=false

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8080

# Stripe (optional for development)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLIC_KEY=pk_test_...
```

### 4. Backend Setup

```bash
cd backend

# Create Python virtual environment (optional, Docker handles this)
python3.11 -m venv venv
source venv/bin/activate  # macOS/Linux
# or
venv\Scripts\activate  # Windows

# Install dependencies (if not using Docker)
pip install -r requirements.txt

# Configure environment
cp .env.example .env

# Run migrations
alembic upgrade head

# Seed test data (optional)
python scripts/seed.py
```

### 5. Web Dashboard Setup

```bash
cd web

# Copy environment file
cp .env.local.example .env.local

# Install dependencies
npm install

# Generate API types (from OpenAPI schema)
npm run generate:api

# Start development server
npm run dev

# Build for production
npm run build
```

### 6. Mobile App Setup

```bash
cd mobile

# Get dependencies
flutter pub get

# Generate code (Riverpod, JSON serialization)
flutter pub run build_runner build

# Run app
flutter run -d chrome  # Web
flutter run -d emulator-5554  # Android emulator
flutter run  # iOS (macOS only)
```

### 7. Database Setup

```bash
# Access PostgreSQL container
docker-compose exec postgres psql -U optiwork -d optiwork

# Create extensions (if not created by init script)
CREATE EXTENSION "uuid-ossp";
CREATE EXTENSION "pgvector";
CREATE EXTENSION "pg_trgm";

# Verify schema
\dt  # List tables
\d users  # Describe table

# Create test data
INSERT INTO organizations (name, email) VALUES ('Test Company', 'admin@test.com');
INSERT INTO users (organization_id, email, first_name, last_name, password_hash)
  VALUES ('...', 'user@test.com', 'Test', 'User', '...');
```

### 8. API Testing

```bash
# Interactive API documentation
open http://localhost:8000/api/docs

# Test health endpoint
curl http://localhost:8000/health

# Test login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"password"}'

# Test with JWT token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/v1/users/profile
```

### 9. Verify All Services

```bash
# Check services status
docker-compose ps

# Check Backend
curl http://localhost:8000/health
# Should return: {"status":"healthy",...}

# Check Database
docker-compose exec postgres psql -U optiwork -c "SELECT 1;"
# Should return: 1

# Check Redis
docker-compose exec redis redis-cli ping
# Should return: PONG

# Check Web Dashboard
open http://localhost:3000

# Check Email (Mailhog)
open http://localhost:8025
```

---

## DEVELOPMENT WORKFLOW

### Backend Development

```bash
# Start backend in watch mode
docker-compose up -d backend

# View logs
docker-compose logs -f backend

# Run tests
docker-compose exec backend pytest --cov=app

# Format code
docker-compose exec backend black .
docker-compose exec backend isort .

# Type checking
docker-compose exec backend mypy app

# Lint
docker-compose exec backend flake8 app
```

### Web Development

```bash
# Ensure backend is running
docker-compose up -d backend

# Start dev server with hot reload
npm run dev

# Build for production
npm run build

# Type checking
npm run typecheck

# Format code
npm run format

# Lint
npm run lint
```

### Mobile Development

```bash
# Get latest packages
flutter pub get

# Run in debug mode
flutter run

# Run with verbose logging
flutter run -v

# Build APK (Android)
flutter build apk

# Build IPA (iOS)
flutter build ios

# Format code
dart format .

# Analyze
dart analyze

# Run tests
flutter test
```

---

## COMMON TASKS

### Run Database Migrations

```bash
# Create new migration
docker-compose exec backend alembic revision --autogenerate -m "Add new column"

# Apply migrations
docker-compose exec backend alembic upgrade head

# Rollback migration
docker-compose exec backend alembic downgrade -1
```

### Reset Database

```bash
# Stop and remove containers
docker-compose down -v

# Start fresh
docker-compose up -d postgres
docker-compose up -d backend

# Run migrations
docker-compose exec backend alembic upgrade head
```

### View Logs

```bash
# Backend logs
docker-compose logs -f backend --tail=50

# Database logs
docker-compose logs -f postgres

# Redis logs
docker-compose logs -f redis

# All logs
docker-compose logs -f

# Export logs
docker-compose logs > logs.txt
```

### Access Services

```bash
# Backend API
http://localhost:8000/api/docs

# Web Dashboard
http://localhost:3000

# Database GUI (PgAdmin)
http://localhost:5050 (admin/admin)

# Redis GUI
http://localhost:8081

# Email (Mailhog)
http://localhost:8025

# Celery Flower (Task Monitor)
http://localhost:5555
```

---

## TROUBLESHOOTING

### Port Already in Use

```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process (macOS/Linux)
kill -9 <PID>

# Or use different port
docker-compose -f docker-compose.yml -p optiwork up -d
```

### Database Connection Error

```bash
# Check database logs
docker-compose logs postgres

# Check connection string in .env
# Ensure postgres container is healthy
docker-compose ps postgres

# Restart database
docker-compose restart postgres
```

### Redis Connection Issues

```bash
# Test Redis connection
docker-compose exec redis redis-cli ping

# Check Redis logs
docker-compose logs redis

# Restart Redis
docker-compose restart redis
```

### Build Failures

```bash
# Clear Docker cache
docker system prune -a

# Rebuild images
docker-compose build --no-cache

# Pull latest base images
docker-compose pull
```

### Out of Memory

```bash
# Increase Docker memory allocation
# Settings > Resources > Memory (Docker Desktop)

# Set to at least 8GB for comfortable development
```

### API Key Issues

```bash
# Generate new Secret Key
python -c "import secrets; print(secrets.token_hex(32))"

# Update .env
SECRET_KEY=your_new_secret_key

# Restart backend
docker-compose restart backend
```

---

## NEXT STEPS

1. **Read Documentation**: Review [ARCHITECTURE.md](ARCHITECTURE.md)
2. **API Integration**: Review [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
3. **Database Schema**: Review [DATABASE_SCHEMA.sql](DATABASE_SCHEMA.sql)
4. **Start Development**: Create a feature branch and start coding
5. **Testing**: Write tests for new features
6. **Code Review**: Submit PR for review
7. **Deployment**: Follow [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

---

## SUPPORT

For issues or questions:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review existing GitHub issues
3. Create a new issue with details
4. Ask on Slack #optiwork-dev

---

**Last Updated**: May 2026  
**Version**: 1.0.0
