# DEPLOYMENT_GUIDE.md - OptiWork AI Production Deployment

## TABLE OF CONTENTS

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Local Development Setup](#local-development-setup)
3. [AWS Deployment](#aws-deployment)
4. [Kubernetes Deployment](#kubernetes-deployment)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Scaling](#scaling)
8. [Disaster Recovery](#disaster-recovery)

---

## PRE-DEPLOYMENT CHECKLIST

### Code Quality
- [ ] All tests passing (90%+ coverage)
- [ ] No security vulnerabilities (run: `snyk test`)
- [ ] Code linted (Black, Flake8)
- [ ] Type checking passing (MyPy)
- [ ] Documentation complete

### Security
- [ ] SSL/TLS certificates acquired
- [ ] Environment variables configured
- [ ] Database credentials secured (AWS Secrets Manager)
- [ ] API keys rotated
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] WAF rules configured

### Infrastructure
- [ ] Database backups configured
- [ ] Monitoring alerts set up
- [ ] Logging aggregation configured
- [ ] CDN configured
- [ ] Load balancer configured
- [ ] Auto-scaling policies defined

### Testing
- [ ] Load testing completed (10k concurrent users)
- [ ] Security penetration testing done
- [ ] Mobile app tested on real devices
- [ ] API endpoints tested
- [ ] Database migration tested

---

## LOCAL DEVELOPMENT SETUP

### Prerequisites
- Docker & Docker Compose 20.10+
- Python 3.11+
- Node.js 18+
- Flutter 3.19+
- Git

### Quick Start

```bash
# Clone repository
git clone https://github.com/optiwork/optiwork-ai.git
cd optiwork-ai

# Copy environment files
cp .env.example .env
cp backend/.env.example backend/.env
cp web/.env.example web/.env
cp mobile/.env.example mobile/.env

# Start all services
docker-compose up -d

# Run database migrations
docker-compose exec backend alembic upgrade head

# Initialize test data (optional)
docker-compose exec backend python -c "from scripts.seed import seed_data; seed_data()"

# Access services
# Backend: http://localhost:8000
# API Docs: http://localhost:8000/api/docs
# Web Dashboard: http://localhost:3000
# PgAdmin: http://localhost:5050 (admin/admin)
# Redis Commander: http://localhost:8081
```

### Verification

```bash
# Check backend
curl http://localhost:8000/health

# Check database
docker-compose exec postgres psql -U optiwork -d optiwork -c "SELECT version();"

# Check Redis
docker-compose exec redis redis-cli ping

# View logs
docker-compose logs -f backend
docker-compose logs -f postgres
```

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (full reset)
docker-compose down -v

# Stop specific service
docker-compose stop backend
```

---

## AWS DEPLOYMENT

### Architecture

```
┌─────────────────────────────────────────┐
│  CloudFront (CDN)                       │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│  Application Load Balancer              │
└──────────────────┬──────────────────────┘
                   │
      ┌────────────┴────────────┐
      │                         │
┌─────▼──────┐        ┌────────▼───────┐
│ Backend    │        │ Web Dashboard  │
│ (ECS)      │        │ (CloudFront)   │
└─────┬──────┘        └────────────────┘
      │
┌─────▼──────────────────────┐
│ RDS PostgreSQL             │
│ (Multi-AZ)                 │
└──────────────────────────────┘
      │
┌─────▼──────────────────────┐
│ ElastiCache Redis          │
│ (Cluster mode)             │
└──────────────────────────────┘
      │
┌─────▼──────────────────────┐
│ S3 (Media Storage)         │
└──────────────────────────────┘
```

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI v2 installed and configured
- Terraform 1.0+ (optional)

### Step 1: Create RDS Database

```bash
# Using AWS Console or AWS CLI
aws rds create-db-instance \
  --db-instance-identifier optiwork-prod \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 15.3 \
  --allocated-storage 100 \
  --storage-type gp3 \
  --master-username admin \
  --master-user-password $(aws secretsmanager get-random-password --query RandomPassword --output text) \
  --multi-az \
  --publicly-accessible false \
  --vpc-security-group-ids sg-xxxxxxxx \
  --db-subnet-group-name optiwork-subnet-group \
  --backup-retention-period 30 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "sun:04:00-sun:05:00"
```

### Step 2: Create ElastiCache Cluster

```bash
aws elasticache create-cache-cluster \
  --cache-cluster-id optiwork-redis \
  --cache-node-type cache.t3.medium \
  --engine redis \
  --engine-version 7.0 \
  --num-cache-nodes 1 \
  --vpc-security-group-ids sg-xxxxxxxx \
  --cache-subnet-group-name optiwork-subnet-group
```

### Step 3: Create ECR Repositories

```bash
# Backend repository
aws ecr create-repository --repository-name optiwork/backend

# Web repository
aws ecr create-repository --repository-name optiwork/web

# AI services repository
aws ecr create-repository --repository-name optiwork/ai-services
```

### Step 4: Build and Push Images

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# Build backend
cd backend
docker build -t optiwork/backend:latest .
docker tag optiwork/backend:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/optiwork/backend:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/optiwork/backend:latest
cd ..

# Build web
cd web
docker build -t optiwork/web:latest .
docker tag optiwork/web:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/optiwork/web:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/optiwork/web:latest
cd ..
```

### Step 5: Create ECS Cluster

```bash
aws ecs create-cluster --cluster-name optiwork-prod
aws ecs create-service \
  --cluster optiwork-prod \
  --service-name backend \
  --task-definition backend-task:1 \
  --desired-count 3 \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=backend,containerPort=8000
```

### Step 6: Configure S3 for Media Storage

```bash
aws s3api create-bucket \
  --bucket optiwork-media-prod \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket optiwork-media-prod \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket optiwork-media-prod \
  --server-side-encryption-configuration '{...}'

# Configure lifecycle policy (optional)
aws s3api put-bucket-lifecycle-configuration \
  --bucket optiwork-media-prod \
  --lifecycle-configuration '{...}'
```

### Step 7: Configure CloudFront

```bash
# Create CloudFront distribution pointing to ALB
# Set origin: backend ALB
# Set cache behaviors
# Enable HTTPS/TLS
```

---

## KUBERNETES DEPLOYMENT

### Prerequisites

- Kubernetes cluster (AWS EKS, GKE, or on-premises)
- kubectl configured
- Helm 3.0+ (optional)

### Deploy to EKS

```bash
# Create EKS cluster
eksctl create cluster \
  --name optiwork-prod \
  --region us-east-1 \
  --nodegroup-name standard-nodes \
  --node-type t3.medium \
  --nodes 3

# Create namespaces
kubectl create namespace optiwork-production
kubectl create namespace optiwork-monitoring

# Create secrets
kubectl create secret generic optiwork-secrets \
  --from-literal=database-url="postgresql://user:pass@host/db" \
  --from-literal=redis-url="redis://:pass@host:6379" \
  --from-literal=secret-key="your-secret-key" \
  -n optiwork-production

# Deploy PostgreSQL (optional - use AWS RDS instead)
kubectl apply -f infrastructure/kubernetes/postgres-deployment.yaml -n optiwork-production

# Deploy Redis (optional - use AWS ElastiCache instead)
kubectl apply -f infrastructure/kubernetes/redis-deployment.yaml -n optiwork-production

# Deploy backend
kubectl apply -f infrastructure/kubernetes/backend-deployment.yaml -n optiwork-production
kubectl apply -f infrastructure/kubernetes/service-backend.yaml -n optiwork-production

# Deploy web dashboard
kubectl apply -f infrastructure/kubernetes/web-deployment.yaml -n optiwork-production

# Setup ingress
kubectl apply -f infrastructure/kubernetes/ingress.yaml -n optiwork-production

# Setup auto-scaling
kubectl apply -f infrastructure/kubernetes/hpa.yaml -n optiwork-production

# Verify deployment
kubectl get deployments -n optiwork-production
kubectl get services -n optiwork-production
kubectl get pods -n optiwork-production
```

---

## CI/CD PIPELINE

### GitHub Actions

See `.github/workflows/` for pipeline definitions:

- `backend-test.yml` - Run tests, lint, type check
- `backend-build.yml` - Build Docker image
- `deploy.yml` - Deploy to production

### Manual Trigger

```bash
# Deploy to production
git tag v1.0.0
git push origin v1.0.0
# GitHub Actions automatically deploys
```

---

## MONITORING & MAINTENANCE

### CloudWatch Monitoring

```bash
# View backend metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=backend \
  --start-time 2024-05-10T00:00:00Z \
  --end-time 2024-05-11T00:00:00Z \
  --period 300 \
  --statistics Average,Maximum
```

### Health Checks

```bash
# Backend health
curl https://api.optiwork.ai/health

# Database connection
psql postgresql://user:pass@host/db -c "SELECT 1;"

# Redis connection
redis-cli -u redis://user:pass@host ping
```

### Backup & Recovery

```bash
# Database backup
aws rds create-db-snapshot \
  --db-instance-identifier optiwork-prod \
  --db-snapshot-identifier optiwork-prod-backup-$(date +%Y%m%d)

# S3 backup
aws s3 sync s3://optiwork-media-prod ./backup/media/

# Database restore
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier optiwork-prod-restored \
  --db-snapshot-identifier optiwork-prod-backup-20240510
```

---

## SCALING

### Horizontal Scaling

```bash
# Scale ECS service
aws ecs update-service \
  --cluster optiwork-prod \
  --service backend \
  --desired-count 10

# Scale RDS (read replicas)
aws rds create-db-instance-read-replica \
  --db-instance-identifier optiwork-prod-replica-1 \
  --source-db-instance-identifier optiwork-prod
```

### Vertical Scaling

```bash
# Increase instance type
aws ecs update-service \
  --cluster optiwork-prod \
  --service backend \
  --task-definition backend-task:2  # New task with larger resources
```

---

## DISASTER RECOVERY

### RTO/RPO Targets

- **RTO (Recovery Time Objective)**: 1 hour
- **RPO (Recovery Point Objective)**: 15 minutes

### Failover Procedure

```bash
# 1. Promote read replica to master
aws rds promote-read-replica \
  --db-instance-identifier optiwork-prod-replica-1

# 2. Update connection strings
# Update secrets in AWS Secrets Manager

# 3. Verify application connectivity
curl https://api.optiwork.ai/health/ready

# 4. Monitor for data consistency
aws rds describe-db-instances \
  --db-instance-identifier optiwork-prod-replica-1
```

---

**Deployment Status**: Ready for Production  
**Last Updated**: May 2026  
**Maintained By**: DevOps Team
