#!/bin/bash
# validate_system.sh - Complete system validation script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     WorkSphere AI - Complete System Validation               ║"
echo "║                 (All Components Test)                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

PASSED=0
FAILED=0

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

test_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000$endpoint")
    else
        response=$(curl -s -X POST -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d '{}' "http://localhost:8000$endpoint")
    fi
    
    if [ "$response" == "200" ] || [ "$response" == "201" ] || [ "$response" == "401" ] || [ "$response" == "403" ] || [ "$response" == "422" ]; then
        echo -e "${GREEN}✓${NC} $description (HTTP $response)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description (HTTP $response)"
        ((FAILED++))
        return 1
    fi
}

test_service() {
    local service=$1
    local port=$2
    local description=$3
    
    if nc -z localhost $port 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description - Service not responding on port $port"
        ((FAILED++))
        return 1
    fi
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

echo -e "\n${BLUE}=== SERVICE HEALTH ===${NC}"

# Check Docker services
echo -e "\n${YELLOW}Checking Docker Services...${NC}"
test_service "PostgreSQL" "5432" "PostgreSQL database (port 5432)"
test_service "Redis" "6379" "Redis cache (port 6379)"
test_service "Backend API" "8000" "Backend API (port 8000)"
test_service "PgAdmin" "5050" "PgAdmin database UI (port 5050)"
test_service "Redis Commander" "8081" "Redis Commander (port 8081)"

# ============================================================================
# BACKEND API CHECKS
# ============================================================================

echo -e "\n${BLUE}=== BACKEND API ENDPOINTS ===${NC}"

echo -e "\n${YELLOW}Health Checks...${NC}"
test_endpoint "GET" "/" "Root endpoint"
test_endpoint "GET" "/health" "Health check"
test_endpoint "GET" "/health/live" "Live probe"
test_endpoint "GET" "/health/ready" "Ready probe"

echo -e "\n${YELLOW}Authentication Endpoints...${NC}"
test_endpoint "POST" "/api/v1/auth/register" "User registration"
test_endpoint "POST" "/api/v1/auth/login" "User login"
test_endpoint "POST" "/api/v1/auth/refresh" "Token refresh"
test_endpoint "POST" "/api/v1/auth/change-password" "Change password"

echo -e "\n${YELLOW}User Management Endpoints...${NC}"
test_endpoint "GET" "/api/v1/users" "List users"
test_endpoint "POST" "/api/v1/users" "Create user"

echo -e "\n${YELLOW}Employee Management Endpoints...${NC}"
test_endpoint "GET" "/api/v1/employees" "List employees"
test_endpoint "POST" "/api/v1/employees" "Create employee"

echo -e "\n${YELLOW}Attendance Endpoints...${NC}"
test_endpoint "POST" "/api/v1/attendance/check-in" "Employee check-in"
test_endpoint "POST" "/api/v1/attendance/check-out" "Employee check-out"
test_endpoint "GET" "/api/v1/attendance/today" "Today's attendance"

echo -e "\n${YELLOW}Face Recognition Endpoints...${NC}"
test_endpoint "POST" "/api/v1/face-recognition/enroll" "Enroll face"
test_endpoint "POST" "/api/v1/face-recognition/verify" "Verify face"

echo -e "\n${YELLOW}GPS & Geofence Endpoints...${NC}"
test_endpoint "POST" "/api/v1/gps/location" "Log location"
test_endpoint "GET" "/api/v1/gps/location/latest" "Get latest location"
test_endpoint "POST" "/api/v1/gps/geofence" "Create geofence"
test_endpoint "GET" "/api/v1/gps/geofences" "List geofences"

echo -e "\n${YELLOW}Analytics Endpoints...${NC}"
test_endpoint "GET" "/api/v1/analytics/summary" "Analytics summary"

echo -e "\n${YELLOW}Payroll Endpoints...${NC}"
test_endpoint "GET" "/api/v1/payroll/current" "Current payroll"

echo -e "\n${YELLOW}Admin Endpoints...${NC}"
test_endpoint "GET" "/api/v1/admin/dashboard" "Admin dashboard"

# ============================================================================
# DATABASE CHECKS
# ============================================================================

echo -e "\n${BLUE}=== DATABASE CHECKS ===${NC}"

echo -e "\n${YELLOW}PostgreSQL Connection...${NC}"
if psql -h localhost -U optiwork -d optiwork -c "SELECT 1" 2>/dev/null >/dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL connection successful"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} PostgreSQL connection failed"
    ((FAILED++))
fi

echo -e "\n${YELLOW}PostgreSQL Tables...${NC}"
if psql -h localhost -U optiwork -d optiwork -c "\dt" 2>/dev/null >/dev/null; then
    table_count=$(psql -h localhost -U optiwork -d optiwork -c "\dt" 2>/dev/null | grep -c "public")
    echo -e "${GREEN}✓${NC} Database tables exist ($table_count tables)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Could not verify tables"
fi

# ============================================================================
# REDIS CHECKS
# ============================================================================

echo -e "\n${BLUE}=== REDIS CACHE CHECKS ===${NC}"

echo -e "\n${YELLOW}Redis Connection...${NC}"
if redis-cli -h localhost ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓${NC} Redis connection successful"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Redis connection failed"
    ((FAILED++))
fi

# ============================================================================
# FILE STRUCTURE CHECKS
# ============================================================================

echo -e "\n${BLUE}=== PROJECT STRUCTURE CHECKS ===${NC}"

echo -e "\n${YELLOW}Backend Files...${NC}"
[ -f "backend/main.py" ] && echo -e "${GREEN}✓${NC} backend/main.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/main.py" && ((FAILED++)))
[ -f "backend/models.py" ] && echo -e "${GREEN}✓${NC} backend/models.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/models.py" && ((FAILED++)))
[ -f "backend/schemas.py" ] && echo -e "${GREEN}✓${NC} backend/schemas.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/schemas.py" && ((FAILED++)))
[ -f "backend/repositories.py" ] && echo -e "${GREEN}✓${NC} backend/repositories.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/repositories.py" && ((FAILED++)))

echo -e "\n${YELLOW}Frontend Files...${NC}"
[ -f "lib/main.dart" ] && echo -e "${GREEN}✓${NC} lib/main.dart" && ((PASSED++)) || (echo -e "${RED}✗${NC} lib/main.dart" && ((FAILED++)))
[ -f "lib/pubspec.yaml" ] && echo -e "${GREEN}✓${NC} lib/pubspec.yaml" && ((PASSED++)) || (echo -e "${RED}✗${NC} lib/pubspec.yaml" && ((FAILED++)))

echo -e "\n${YELLOW}Test Files...${NC}"
[ -f "backend/tests/test_auth.py" ] && echo -e "${GREEN}✓${NC} backend/tests/test_auth.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/tests/test_auth.py" && ((FAILED++)))
[ -f "backend/tests/test_attendance.py" ] && echo -e "${GREEN}✓${NC} backend/tests/test_attendance.py" && ((PASSED++)) || (echo -e "${RED}✗${NC} backend/tests/test_attendance.py" && ((FAILED++)))

echo -e "\n${YELLOW}Documentation Files...${NC}"
[ -f "QUICK_START.md" ] && echo -e "${GREEN}✓${NC} QUICK_START.md" && ((PASSED++)) || (echo -e "${RED}✗${NC} QUICK_START.md" && ((FAILED++)))
[ -f "README.md" ] && echo -e "${GREEN}✓${NC} README.md" && ((PASSED++)) || (echo -e "${RED}✗${NC} README.md" && ((FAILED++)))
[ -f "API_TESTING_GUIDE.md" ] && echo -e "${GREEN}✓${NC} API_TESTING_GUIDE.md" && ((PASSED++)) || (echo -e "${RED}✗${NC} API_TESTING_GUIDE.md" && ((FAILED++)))

# ============================================================================
# API FUNCTIONALITY TESTS
# ============================================================================

echo -e "\n${BLUE}=== BASIC FUNCTIONALITY TESTS ===${NC}"

echo -e "\n${YELLOW}Testing Demo Login...${NC}"
login_response=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@optiwork.ai","password":"password123"}')

if echo "$login_response" | grep -q "access_token"; then
    echo -e "${GREEN}✓${NC} Login returns access token"
    ((PASSED++))
    
    token=$(echo "$login_response" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
    
    echo -e "\n${YELLOW}Testing Protected Endpoint...${NC}"
    protected=$(curl -s http://localhost:8000/api/v1/attendance/today \
      -H "Authorization: Bearer $token")
    
    if echo "$protected" | grep -q "date\|status\|check_in"; then
        echo -e "${GREEN}✓${NC} Protected endpoint accessible with token"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Protected endpoint test failed"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Login failed"
    ((FAILED++))
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                   VALIDATION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

total=$((PASSED + FAILED))
percentage=$((PASSED * 100 / total))

echo -e "  ${GREEN}Passed:${NC} $PASSED/$total"
echo -e "  ${RED}Failed:${NC} $FAILED/$total"
echo -e "  ${YELLOW}Success Rate:${NC} $percentage%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED - SYSTEM IS READY!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. API Docs:      http://localhost:8000/api/docs"
    echo "  2. Run Tests:     cd backend && pytest -v"
    echo "  3. Mobile App:    cd lib && flutter run"
    echo ""
    exit 0
else
    echo -e "${RED}⚠ SOME TESTS FAILED - PLEASE CHECK THE ERRORS ABOVE${NC}"
    echo ""
    exit 1
fi
