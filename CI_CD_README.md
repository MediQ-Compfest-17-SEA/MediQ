# MediQ Backend - CI/CD Setup Guide

## Overview

Comprehensive CI/CD pipeline menggunakan GitHub Actions untuk semua MediQ backend services dengan automated testing, security scanning, Docker builds, dan multi-environment deployments.

## 🚀 Features

- **Automated Testing**: Unit tests, integration tests, coverage reports
- **Security Scanning**: Dependency vulnerability scanning dengan Trivy
- **Docker Build**: Multi-stage builds dengan optimization
- **Multi-Environment**: Staging (auto) dan Production (manual approval)
- **Service Matrix**: Deploy individual services atau semua sekaligus
- **Health Checks**: Automated health checks post-deployment

## 📁 Structure

```
.github/
├── workflows/
│   ├── api-gateway.yml              # API Gateway CI/CD
│   ├── user-service.yml             # User Service CI/CD
│   ├── ocr-service.yml              # OCR Service CI/CD
│   ├── patient-queue-service.yml    # Patient Queue Service CI/CD
│   ├── deploy-all.yml               # Deploy all services
│   └── setup-environments.yml      # Environment setup instructions
└── templates/
    └── service-workflow.template.yml # Reusable workflow template
```

## 🔧 Updated Port Configuration

| Service | Old Port | New Port | Docker Image |
|---------|----------|----------|--------------|
| API Gateway | 3001 | **8601** | `mediq/api-gateway` |
| User Service | 3000 | **8602** | `mediq/user-service` |
| OCR Service | 3002 | **8603** | `mediq/ocr-service` |
| Patient Queue Service | 3003 | **8605** | `mediq/patient-queue-service` |
| OCR Engine Service | - | **8604** | `mediq/ocr-engine-service` |

## 🏗️ Workflow Triggers

### Individual Service Workflows
- **Push**: `main` dan `develop` branches (hanya jika ada perubahan di service path)
- **Pull Request**: ke `main` branch

### Deploy All Workflow  
- **Manual**: Via workflow dispatch dengan pilihan environment dan services

## 📋 Prerequisites

### 1. GitHub Environments

Buat dua environments di **Repository Settings → Environments**:

#### Staging Environment
- **Name**: `staging`
- **Protection rules**: 
  - Restrict to `main` branch
  - No approval required

#### Production Environment  
- **Name**: `production`
- **URL**: `https://api.mediq.id`
- **Protection rules**:
  - Restrict to `main` branch
  - Required reviewers: minimum 1
  - Deployment timeout: 30 minutes

### 2. Required Secrets

Tambahkan secrets berikut di **Repository Settings → Secrets and variables → Actions**:

```bash
# Docker Registry
DOCKER_HUB_USERNAME=your-dockerhub-username
DOCKER_HUB_TOKEN=your-dockerhub-token

# Database & Services
DATABASE_URL=mysql://user:password@host:port/database
RABBITMQ_URL=amqp://user:password@host:port
REDIS_URL=redis://host:port

# Authentication
JWT_SECRET=your-jwt-secret-key
JWT_REFRESH_SECRET=your-jwt-refresh-secret-key

# OCR Service
OCR_API_URL=http://ocr-engine-host:8604
```

### 3. Database Services (untuk CI)

Workflows menggunakan service containers:
- **MySQL 8.0** (untuk User Service dan Patient Queue Service)
- **RabbitMQ 3.13** (untuk semua services)
- **Redis 7** (untuk Patient Queue Service)

## 🔄 Workflow Stages

### Stage 1: Test & Build
- **Checkout code** dan setup Node.js 20
- **Install dependencies** dengan npm ci
- **Generate Prisma client** (jika applicable)
- **Run ESLint** dan Prettier checks
- **Run unit tests** dengan coverage
- **Run integration tests**
- **Build application**
- **Upload coverage** ke Codecov

### Stage 2: Security Scan
- **Dependency check** dengan OWASP
- **npm audit** untuk vulnerability scanning
- **Upload security reports**

### Stage 3: Docker Build & Push
- **Multi-stage Docker build**
- **Push ke Docker Hub** dengan tags:
  - `latest` (untuk main branch)
  - `branch-name` (untuk branch lain)
  - `branch-sha` (untuk commit-specific)
- **Trivy vulnerability scan** pada Docker image
- **Upload SARIF results**

### Stage 4: Deploy Staging
- **Auto-deployment** untuk main branch
- **Environment**: `staging`
- **Conditional**: hanya jika Docker build sukses

### Stage 5: Deploy Production
- **Manual approval** required
- **Environment**: `production`
- **Health checks** post-deployment
- **Rollback** capability

## 📊 Usage Examples

### Individual Service Deployment
```bash
# Otomatis trigger saat push ke main/develop
git push origin main
```

### Manual All Services Deployment
1. Go to **Actions** tab
2. Select **"Deploy All Services"** workflow
3. Click **"Run workflow"**
4. Choose:
   - **Environment**: `staging` or `production`
   - **Services**: `all` atau `api-gateway,user-service`

### Selective Service Deployment
```yaml
# Untuk deploy hanya specific services
Services: "api-gateway,user-service"
```

## 🐳 Docker Optimization

### Multi-stage Builds
```dockerfile
# Build stage - menggunakan full dependencies
FROM node:20-alpine AS builder

# Production stage - hanya runtime dependencies
FROM node:20-alpine AS production
```

### Security Features
- **Non-root user**: `nestjs` user dengan UID 1001
- **Security updates**: `apk update && apk upgrade`
- **Signal handling**: `dumb-init` untuk proper signal handling
- **Minimal attack surface**: Alpine Linux base

### Cache Strategy
- **Layer caching**: Docker build cache di GitHub Actions
- **npm cache**: Cached dependencies untuk faster builds
- **Multi-arch support**: Ready untuk ARM64 (Apple Silicon)

## 🔍 Monitoring & Debugging

### Build Logs
- Semua logs tersedia di **Actions** tab
- **Artifacts**: Coverage reports, security scan results
- **SARIF uploads**: Security findings di **Security** tab

### Health Checks
```bash
# API Gateway health check
curl -f https://api.mediq.com:8601/api/health

# Service-specific health endpoints  
curl -f https://api.mediq.com:8602/api/health # User Service
curl -f https://api.mediq.com:8603/api/health # OCR Service
curl -f https://api.mediq.com:8605/api/health # Patient Queue Service
```

### Deployment Status
- **GitHub Deployments**: Track di **Environments** section
- **Job summaries**: Detailed reports di workflow runs
- **Notifications**: Optional integration dengan Slack/Teams

## 🚨 Troubleshooting

### Common Issues

1. **Test Failures**
   - Check service dependencies (MySQL, RabbitMQ, Redis)
   - Verify environment variables
   - Review test logs dalam workflow

2. **Docker Build Failures**
   - Check Dockerfile syntax
   - Verify build context
   - Review dependency installation

3. **Deployment Failures**
   - Verify environment secrets
   - Check network connectivity
   - Review deployment logs

### Recovery Procedures

1. **Rollback Production**
   ```bash
   # Deploy previous known-good version
   kubectl set image deployment/api-gateway api-gateway=mediq/api-gateway:previous-tag
   ```

2. **Hotfix Deployment**
   ```bash
   # Create hotfix branch, push, manual approve for production
   git checkout -b hotfix/critical-fix
   git push origin hotfix/critical-fix
   ```

## 📈 Best Practices

### Development Workflow
1. **Feature branch** → **develop** → **main**
2. **Pull request** triggers tests
3. **Main branch** triggers staging deployment
4. **Manual approval** untuk production

### Security
- **Secrets rotation**: Regular rotation of tokens dan keys
- **Dependency updates**: Automated via Dependabot
- **Vulnerability scanning**: Integrated dalam CI pipeline

### Performance
- **Parallel jobs**: Matrix strategy untuk multiple services
- **Cache optimization**: Docker layer cache dan npm cache
- **Resource limits**: CPU dan memory limits untuk containers

## 🔗 Related Documentation

- [AGENT.md](./AGENT.md) - Service architecture dan development guide
- [TESTING_DOCUMENTATION.md](./TESTING_DOCUMENTATION.md) - Testing strategy
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Manual deployment guide
- [SWAGGER_DOCUMENTATION.md](./SWAGGER_DOCUMENTATION.md) - API documentation

---

## ⚡ Quick Start

1. **Setup environments dan secrets** (lihat Prerequisites)
2. **Push ke main branch** untuk trigger staging deployment
3. **Manual approve** untuk production deployment
4. **Monitor** di GitHub Actions dan environment status

**Happy Deploying! 🚀**
