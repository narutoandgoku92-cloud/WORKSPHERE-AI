@echo off
REM setup.bat - WorkSphere AI Development Environment Setup (Windows)

setlocal enabledelayedexpansion

echo.
echo ========================================
echo WorkSphere AI - Setup Script (Windows)
echo ========================================

REM Check if Docker is installed
echo.
echo Checking Docker installation...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker not found. Please install Docker Desktop.
    pause
    exit /b 1
)
echo OK - Docker found

REM Check if docker-compose is installed
echo.
echo Checking Docker Compose installation...
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose not found. Please install Docker Compose.
    pause
    exit /b 1
)
echo OK - Docker Compose found

REM Check if Flutter is installed (optional)
echo.
echo Checking Flutter installation (optional)...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo WARNING: Flutter not found. Please install Flutter to run mobile app.
) else (
    echo OK - Flutter found
)

REM Create .env if it doesn't exist
echo.
echo Checking .env file...
if not exist .env (
    echo Creating .env file...
    copy .env .env >nul
    echo OK - .env file created
) else (
    echo OK - .env file exists
)

REM Start Docker services
echo.
echo Starting Docker services...
docker-compose down
docker-compose up -d

REM Wait for services to be healthy
echo.
echo Waiting for services to be healthy...

REM Wait for PostgreSQL
set attempt=0
:wait_postgres
if %attempt% geq 30 (
    echo ERROR: PostgreSQL failed to start
    pause
    exit /b 1
)

docker-compose exec -T postgres pg_isready -U optiwork >nul 2>&1
if errorlevel 1 (
    set /a attempt=!attempt!+1
    echo Waiting for PostgreSQL... (!attempt!/30)
    timeout /t 2 /nobreak
    goto wait_postgres
)
echo OK - PostgreSQL is ready

REM Wait for Redis
set attempt=0
:wait_redis
if %attempt% geq 30 (
    echo ERROR: Redis failed to start
    pause
    exit /b 1
)

docker-compose exec -T redis redis-cli ping >nul 2>&1
if errorlevel 1 (
    set /a attempt=!attempt!+1
    echo Waiting for Redis... (!attempt!/30)
    timeout /t 2 /nobreak
    goto wait_redis
)
echo OK - Redis is ready

REM Wait for Backend API
set attempt=0
:wait_backend
if %attempt% geq 30 (
    echo WARNING: Backend API may still be starting...
    goto backend_done
)

curl -s http://localhost:8000/health >nul 2>&1
if errorlevel 1 (
    set /a attempt=!attempt!+1
    echo Waiting for Backend API... (!attempt!/30)
    timeout /t 2 /nobreak
    goto wait_backend
)
echo OK - Backend API is ready

:backend_done

REM Display service URLs
echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Available Services:
echo   Backend API      : http://localhost:8000
echo   API Docs         : http://localhost:8000/api/docs
echo   PgAdmin          : http://localhost:5050
echo   Redis Commander  : http://localhost:8081
echo   MailHog          : http://localhost:8025
echo.
echo Database Credentials:
echo   Username         : optiwork
echo   Password         : optiwork_dev_password
echo   Database         : optiwork
echo   Port             : 5432
echo.
echo Next Steps:
echo   1. Open http://localhost:8000/api/docs to view API endpoints
echo   2. Run 'flutter run' to start the mobile app
echo   3. Use demo credentials: admin@optiwork.ai / password123
echo.
echo View Logs:
echo   docker-compose logs -f [service]
echo   docker-compose logs -f backend
echo   docker-compose logs -f postgres
echo.
echo Stop Services:
echo   docker-compose down
echo.
echo ========================================
echo.
pause
