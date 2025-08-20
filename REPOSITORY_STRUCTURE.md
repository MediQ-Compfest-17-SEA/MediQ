# MediQ Repository Structure

This document describes the updated repository structure for the MediQ microservices architecture.

## Root Repository (MediQ)

The root repository now contains only shared infrastructure and cross-service components:

```
MediQ/
├── .github/
│   └── workflows/
│       ├── deploy-all.yml          # Deploy all services
│       ├── integration-tests.yml   # Cross-service integration tests
│       └── setup-environments.yml  # Environment setup
├── k8s/
│   ├── shared/
│   │   ├── infrastructure/         # MySQL, Redis, RabbitMQ
│   │   └── monitoring/            # Prometheus, Grafana
│   ├── namespaces/                # Kubernetes namespaces
│   ├── rbac/                      # Role-based access control
│   ├── network-policies/          # Network policies
│   ├── secrets/                   # Shared secrets
│   └── ingress.yaml              # Ingress configuration
├── test/                          # Integration tests
├── scripts/                       # Deployment and setup scripts
├── docker-compose.infrastructure.yml
└── Documentation files...
```

## Service Repositories

Each service now has its own repository with the following structure:

### User Service (MediQ-Backend-User-Service)
```
MediQ-Backend-User-Service/
├── .github/workflows/ci-cd.yml
├── src/
├── prisma/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── hpa.yaml (if applicable)
├── Dockerfile
├── docker-compose.yml
└── package.json
```

### API Gateway (MediQ-Backend-API-Gateway)
```
MediQ-Backend-API-Gateway/
├── .github/workflows/ci-cd.yml
├── src/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── hpa.yaml
├── Dockerfile
├── docker-compose.yml
└── package.json
```

### OCR Service (MediQ-Backend-OCR-Service)
```
MediQ-Backend-OCR-Service/
├── .github/workflows/ci-cd.yml
├── src/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── Dockerfile
├── docker-compose.yml
└── package.json
```

### Patient Queue Service (MediQ-Backend-Patient-Queue-Service)
```
MediQ-Backend-Patient-Queue-Service/
├── .github/workflows/ci-cd.yml
├── src/
├── prisma/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── Dockerfile
├── docker-compose.yml
└── package.json
```

### OCR Engine Service (MediQ-Backend-OCR-Engine-Service)
```
MediQ-Backend-OCR-Engine-Service/
├── .github/workflows/ci-cd.yml
├── src/
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── Dockerfile
├── docker-compose.yml
└── package.json
```

## Development Workflow

### 1. Infrastructure Setup
```bash
# Start shared infrastructure
docker-compose -f docker-compose.infrastructure.yml up -d
```

### 2. Service Development
```bash
# In each service repository
docker-compose up -d  # Start service with dependencies
npm run dev          # Or start in development mode
```

### 3. Integration Testing
```bash
# In root repository
cd test
npm run test:integration
```

### 4. Kubernetes Deployment
```bash
# Deploy infrastructure first
kubectl apply -f k8s/shared/

# Deploy each service (from their respective repositories)
kubectl apply -f k8s/

# Or deploy all from root
kubectl apply -f MediQ-Backend-*/k8s/
```

## Benefits of This Structure

1. **Service Independence**: Each service can be developed, tested, and deployed independently
2. **Clear Ownership**: Each service repository is owned by its respective team
3. **Simplified CI/CD**: Service-specific pipelines with focused testing
4. **Better Scaling**: Services can be scaled independently
5. **Reduced Coupling**: Changes in one service don't affect others
6. **Easier Maintenance**: Smaller, focused repositories are easier to maintain

## Migration Checklist

- [x] Move CI/CD workflows to service repositories
- [x] Move Kubernetes manifests to service repositories  
- [x] Create Docker configurations for each service
- [x] Create service-specific docker-compose files
- [x] Update root repository structure
- [x] Create shared infrastructure setup
- [x] Update documentation
- [ ] Update team access permissions for repositories
- [ ] Update CI/CD secrets in each repository
- [ ] Test deployment pipeline for each service
- [ ] Migrate existing deployments to new structure
