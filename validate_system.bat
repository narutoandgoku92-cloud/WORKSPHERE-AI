@echo off
REM validate_system.bat - Complete system validation script for Windows

setlocal enabledelayedexpansion

cls
echo.
echo ================================================================
echo   WorkSphere AI - Complete System Validation
echo                 (All Components Test)
echo ================================================================
echo.

set PASSED=0
set FAILED=0

REM =====================================================================
REM SERVICE CHECKS
REM =====================================================================

echo === SERVICE HEALTH ===
echo.
echo Checking Services...

REM Check if ports are open
echo Checking PostgreSQL (5432)...
netstat -ano | findstr :5432 >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] PostgreSQL database (port 5432)
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] PostgreSQL - not responding on port 5432
    set /a FAILED=!FAILED!+1
)

echo Checking Redis (6379)...
netstat -ano | findstr :6379 >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Redis cache (port 6379)
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] Redis - not responding on port 6379
    set /a FAILED=!FAILED!+1
)

echo Checking Backend API (8000)...
netstat -ano | findstr :8000 >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Backend API (port 8000)
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] Backend API - not responding on port 8000
    set /a FAILED=!FAILED!+1
)

echo Checking PgAdmin (5050)...
netstat -ano | findstr :5050 >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] PgAdmin database UI (port 5050)
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] PgAdmin - not responding on port 5050
    set /a FAILED=!FAILED!+1
)

REM =====================================================================
REM FILE STRUCTURE CHECKS
REM =====================================================================

echo.
echo === PROJECT STRUCTURE CHECKS ===
echo.

echo Checking Backend Files...
if exist "backend\main.py" (
    echo [OK] backend\main.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\main.py - not found
    set /a FAILED=!FAILED!+1
)

if exist "backend\models.py" (
    echo [OK] backend\models.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\models.py - not found
    set /a FAILED=!FAILED!+1
)

if exist "backend\schemas.py" (
    echo [OK] backend\schemas.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\schemas.py - not found
    set /a FAILED=!FAILED!+1
)

if exist "backend\repositories.py" (
    echo [OK] backend\repositories.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\repositories.py - not found
    set /a FAILED=!FAILED!+1
)

echo.
echo Checking Frontend Files...
if exist "lib\main.dart" (
    echo [OK] lib\main.dart
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] lib\main.dart - not found
    set /a FAILED=!FAILED!+1
)

if exist "lib\pubspec.yaml" (
    echo [OK] lib\pubspec.yaml
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] lib\pubspec.yaml - not found
    set /a FAILED=!FAILED!+1
)

echo.
echo Checking Test Files...
if exist "backend\tests\test_auth.py" (
    echo [OK] backend\tests\test_auth.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\tests\test_auth.py - not found
    set /a FAILED=!FAILED!+1
)

if exist "backend\tests\test_attendance.py" (
    echo [OK] backend\tests\test_attendance.py
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] backend\tests\test_attendance.py - not found
    set /a FAILED=!FAILED!+1
)

echo.
echo Checking Documentation Files...
if exist "QUICK_START.md" (
    echo [OK] QUICK_START.md
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] QUICK_START.md - not found
    set /a FAILED=!FAILED!+1
)

if exist "README.md" (
    echo [OK] README.md
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] README.md - not found
    set /a FAILED=!FAILED!+1
)

if exist "API_TESTING_GUIDE.md" (
    echo [OK] API_TESTING_GUIDE.md
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] API_TESTING_GUIDE.md - not found
    set /a FAILED=!FAILED!+1
)

REM =====================================================================
REM API ENDPOINT CHECKS
REM =====================================================================

echo.
echo === API ENDPOINT CHECKS ===
echo.

echo Testing health endpoints...
for /f "tokens=*" %%i in ('curl -s -o nul -w "%%{http_code}" http://localhost:8000/health 2^>nul') do set HTTP_CODE=%%i
if "!HTTP_CODE!"=="200" (
    echo [OK] Health check endpoint
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] Health check endpoint - HTTP !HTTP_CODE!
    set /a FAILED=!FAILED!+1
)

echo Testing API documentation...
for /f "tokens=*" %%i in ('curl -s -o nul -w "%%{http_code}" http://localhost:8000/api/docs 2^>nul') do set HTTP_CODE=%%i
if "!HTTP_CODE!"=="200" (
    echo [OK] API documentation endpoint
    set /a PASSED=!PASSED!+1
) else (
    echo [FAIL] API documentation endpoint - HTTP !HTTP_CODE!
)

REM =====================================================================
REM SUMMARY
REM =====================================================================

echo.
echo ================================================================
echo                   VALIDATION SUMMARY
echo ================================================================
echo.

set /a TOTAL=!PASSED! + !FAILED!
if !TOTAL! gtr 0 (
    set /a PERCENTAGE=(!PASSED! * 100) / !TOTAL!
) else (
    set PERCENTAGE=0
)

echo   Passed:       !PASSED!/!TOTAL!
echo   Failed:       !FAILED!/!TOTAL!
echo   Success Rate: !PERCENTAGE!%%
echo.

if !FAILED! equ 0 (
    echo ================================================================
    echo [SUCCESS] ALL TESTS PASSED - SYSTEM IS READY!
    echo ================================================================
    echo.
    echo Next Steps:
    echo   1. API Docs:      http://localhost:8000/api/docs
    echo   2. Run Tests:     cd backend ^&^& pytest -v
    echo   3. Mobile App:    cd lib ^&^& flutter run
    echo.
    pause
    exit /b 0
) else (
    echo ================================================================
    echo [WARNING] SOME TESTS FAILED - PLEASE CHECK ERRORS ABOVE
    echo ================================================================
    echo.
    pause
    exit /b 1
)
