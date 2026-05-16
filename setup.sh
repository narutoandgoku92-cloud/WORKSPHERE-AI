#!/bin/bash
# setup.sh - WorkSphere AI Development Environment Setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WorkSphere AI - Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if Docker is installed
echo -e "\n${YELLOW}Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker Desktop.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# Check if docker-compose is installed
echo -e "\n${YELLOW}Checking Docker Compose installation...${NC}"
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose found${NC}"

# Check if Flutter is installed (optional)
echo -e "\n${YELLOW}Checking Flutter installation (optional)...${NC}"
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✓ Flutter found${NC}"
else
    echo -e "${YELLOW}⚠ Flutter not found. Please install Flutter to run mobile app.${NC}"
fi

# Create .env if it doesn't exist
echo -e "\n${YELLOW}Checking .env file...${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp .env .env
    echo -e "${GREEN}✓ .env file created${NC}"
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi

# Start Docker services
echo -e "\n${YELLOW}Starting Docker services...${NC}"
docker-compose down  # Clean up any existing containers
docker-compose up -d

# Wait for services to be healthy
echo -e "\n${YELLOW}Waiting for services to be healthy...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T postgres pg_isready -U optiwork &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -e "${YELLOW}Waiting for PostgreSQL... ($attempt/$max_attempts)${NC}"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
    exit 1
fi

# Wait for Redis
echo -e "\n${YELLOW}Waiting for Redis...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T redis redis-cli ping &> /dev/null; then
        echo -e "${GREEN}✓ Redis is ready${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -e "${YELLOW}Waiting for Redis... ($attempt/$max_attempts)${NC}"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ Redis failed to start${NC}"
    exit 1
fi

# Wait for Backend
echo -e "\n${YELLOW}Waiting for Backend API...${NC}"
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend API is ready${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -e "${YELLOW}Waiting for Backend API... ($attempt/$max_attempts)${NC}"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${YELLOW}⚠ Backend API may still be starting...${NC}"
fi

# Display service URLs
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${YELLOW}Available Services:${NC}"
echo -e "  ${GREEN}Backend API${NC}      : http://localhost:8000"
echo -e "  ${GREEN}API Docs${NC}         : http://localhost:8000/api/docs"
echo -e "  ${GREEN}PgAdmin${NC}          : http://localhost:5050"
echo -e "  ${GREEN}Redis Commander${NC}  : http://localhost:8081"
echo -e "  ${GREEN}MailHog${NC}          : http://localhost:8025"
echo -e "\n${YELLOW}Database Credentials:${NC}"
echo -e "  ${GREEN}Username${NC}         : optiwork"
echo -e "  ${GREEN}Password${NC}         : optiwork_dev_password"
echo -e "  ${GREEN}Database${NC}         : optiwork"
echo -e "  ${GREEN}Port${NC}             : 5432"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  1. Open http://localhost:8000/api/docs to view API endpoints"
echo -e "  2. Run 'flutter run' to start the mobile app"
echo -e "  3. Use demo credentials: admin@optiwork.ai / password123"
echo -e "\n${YELLOW}View Logs:${NC}"
echo -e "  docker-compose logs -f [service]"
echo -e "  docker-compose logs -f backend"
echo -e "  docker-compose logs -f postgres"
echo -e "\n${YELLOW}Stop Services:${NC}"
echo -e "  docker-compose down"
echo -e "\n${BLUE}========================================${NC}"
