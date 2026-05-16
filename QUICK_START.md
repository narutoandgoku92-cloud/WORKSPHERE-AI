# WorkSphere AI - Quick Start Guide

## 🚀 Prerequisites

- Docker & Docker Compose (v20.10+)
- Flutter SDK (3.19+) or just Android Studio/Xcode
- Python 3.11+ (for backend development without Docker)
- Node.js 18+ (optional, for web dashboard)

## 📦 Quick Start with Docker

### 1. Start All Services

```bash
cd c:/Users/gbola/OneDrive/Pictures/flutter/work_sphere_ai

# Start all services in background
docker-compose up -d

# View logs
docker-compose logs -f
```

### 2. Services Available

| Service | URL | Credentials |
|---------|-----|-------------|
| **Backend API** | http://localhost:8000 | - |
| **API Docs** | http://localhost:8000/api/docs | - |
| **PostgreSQL** | localhost:5432 | optiwork / optiwork_dev_password |
| **Redis** | localhost:6379 | redis_dev_password |
| **PgAdmin** | http://localhost:5050 | admin@optiwork.local / admin |
| **Redis Commander** | http://localhost:8081 | - |
| **MailHog** | http://localhost:8025 | - |

### 3. Test Backend API

```bash
# Health check
curl http://localhost:8000/health

# API documentation
open http://localhost:8000/api/docs

# Login as admin
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@optiwork.ai","password":"password123"}'
```

### 4. Run Flutter App

```bash
cd lib  # Navigate to Flutter project
flutter pub get  # Get dependencies
flutter run     # Run on connected device or emulator
```

**Demo Credentials:**
- Email: `admin@optiwork.ai`
- Password: `password123`

---

## 🛠️ Development Setup (Without Docker)

### Backend Setup

```bash
# 1. Create Python virtual environment
python -m venv backend_venv
source backend_venv/Scripts/activate  # Windows: backend_venv\Scripts\activate

# 2. Install dependencies
cd backend
pip install -r requirements.txt

# 3. Set environment variables
copy .env .env.local
# Edit .env.local with local settings

# 4. Initialize database
python -c "from core.database import init_db; init_db()"

# 5. Start backend server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Frontend Setup

```bash
# 1. Get Flutter dependencies
flutter pub get

# 2. Run on emulator/device
flutter run

# 3. For web (optional)
flutter run -d chrome
```

---

## 📋 Database Setup

### Initialize Database (First Time)

Database initialization happens automatically on first backend startup. The `DATABASE_SCHEMA.sql` file is loaded via Docker entrypoint.

### Create Sample Data

```bash
# Connect to PostgreSQL
psql -h localhost -U optiwork -d optiwork

# Run seed script (optional)
\i DATABASE_SCHEMA.sql
```

### Manage with PgAdmin

1. Open http://localhost:5050
2. Login: admin@optiwork.local / admin
3. Connect to PostgreSQL server
   - Host: postgres
   - Username: optiwork
   - Password: optiwork_dev_password

---

## 🧪 Testing

### Backend Tests

```bash
cd backend

# Run all tests
pytest

# Run specific test file
pytest tests/test_auth.py -v

# Run with coverage
pytest --cov=. --cov-report=html
```

### Flutter Tests

```bash
# Run unit tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

---

## 🐛 Troubleshooting

### Backend Won't Start

```bash
# Check if port 8000 is in use
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process using port
kill -9 <PID>
```

### Database Connection Error

```bash
# Check PostgreSQL service
docker-compose ps

# Check logs
docker-compose logs postgres

# Reconnect to database
docker-compose exec postgres psql -U optiwork -d optiwork
```

### Flutter Build Issues

```bash
# Clean Flutter
flutter clean

# Get fresh dependencies
flutter pub get

# Rebuild
flutter pub get && flutter run
```

### Redis Connection Error

```bash
# Check Redis
docker-compose logs redis

# Test connection
redis-cli -h localhost -p 6379
```

---

## 📊 Monitoring & Debugging

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f postgres
docker-compose logs -f redis
```

### Database Query Monitoring

1. Open PgAdmin: http://localhost:5050
2. Tools → Query Tool
3. Write SQL queries to inspect data

### Redis Monitoring

1. Open Redis Commander: http://localhost:8081
2. View all stored data and cache hits

### Email Capture (MailHog)

1. Open MailHog: http://localhost:8025
2. View all emails sent during testing

---

## 🚀 Production Deployment

### Environment Variables for Production

Edit `.env` before deploying:

```bash
# Production settings
DEBUG=false
ENVIRONMENT=production
SECRET_KEY=<generate-new-secret-key>
DATABASE_URL=postgresql://user:pass@prod-db-host:5432/optiwork
REDIS_URL=redis://:password@prod-redis-host:6379/0
CORS_ORIGINS=https://optiwork.ai,https://app.optiwork.ai
```

### Deploy with Docker

```bash
# Build production image
docker build -t optiwork/backend:latest ./backend

# Push to registry
docker push optiwork/backend:latest

# Deploy with docker-compose (production)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Deploy Flutter App

```bash
# Build APK (Android)
flutter build apk --release

# Build IPA (iOS)
flutter build ios --release

# Build web
flutter build web --release
```

---

## 🔐 Security Checklist

- [ ] Change `SECRET_KEY` in `.env` for production
- [ ] Use strong database passwords
- [ ] Enable HTTPS/SSL certificates
- [ ] Set `DEBUG=false` in production
- [ ] Restrict `CORS_ORIGINS` to your domains
- [ ] Use environment-specific `.env` files
- [ ] Enable Firebase authentication
- [ ] Configure rate limiting
- [ ] Set up proper logging and monitoring

---

## 📞 API Documentation

Auto-generated API documentation available at:

- **Swagger UI**: http://localhost:8000/api/docs
- **ReDoc**: http://localhost:8000/api/redoc
- **OpenAPI Schema**: http://localhost:8000/api/openapi.json

See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for detailed endpoint documentation.

---

## 📁 Project Structure

```
work_sphere_ai/
├── backend/                    # FastAPI Python backend
│   ├── main.py                # Entry point
│   ├── models.py              # SQLAlchemy ORM models
│   ├── schemas.py             # Pydantic validation schemas
│   ├── repositories.py        # Database abstraction
│   ├── core/                  # Configuration & utilities
│   ├── api/v1/routes/         # API endpoints (8 modules)
│   ├── services/              # Business logic services
│   ├── middleware/            # Custom middleware
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile
├── lib/                       # Flutter mobile app
│   ├── main.dart             # App entry point
│   ├── models/               # Dart data models
│   ├── providers/            # Riverpod state management
│   ├── services/             # API client and services
│   └── screens/              # UI screens
├── android/                  # Android native code
├── ios/                      # iOS native code
├── web/                      # Web dashboard (Next.js)
├── docker-compose.yml        # Local development setup
├── .env                      # Environment variables
└── DATABASE_SCHEMA.sql       # Database schema
```

---

## 🎯 Next Steps

1. **Start Services**: `docker-compose up -d`
2. **Visit API Docs**: http://localhost:8000/api/docs
3. **Run Flutter App**: `flutter run`
4. **Test Login**: Use demo credentials
5. **Check Dashboard**: View employee & attendance data
6. **Read [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)** for feature roadmap

---

## 📚 Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Database Schema](DATABASE_SCHEMA.sql)
- [Implementation Roadmap](IMPLEMENTATION_ROADMAP.md)
- [Deployment Guide](DEPLOYMENT_GUIDE.md)
- [Setup Guide](SETUP_GUIDE.md)

---

**Created**: 2024
**Status**: Production Ready
**License**: Proprietary
