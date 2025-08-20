# MediQ Backend - Kubernetes Deployment Guide

## 🚀 **Overview**

Comprehensive guide untuk deploy MediQ Backend microservices ke Kubernetes cluster dengan production-ready configuration, monitoring, dan auto-scaling.

## 📋 **Prerequisites**

### System Requirements
- **Kubernetes Cluster**: v1.24+ (AKS, EKS, GKE, atau on-premise)
- **kubectl**: v1.24+ configured dengan cluster access
- **Helm**: v3.10+ (optional, untuk infrastructure components)
- **Docker Registry**: Docker Hub, ACR, ECR, atau private registry
- **TLS Certificates**: Untuk production HTTPS endpoints

### Resource Requirements
- **Minimum**: 8 CPU cores, 16GB RAM, 100GB storage
- **Recommended**: 16 CPU cores, 32GB RAM, 200GB SSD storage  
- **Production**: 24+ CPU cores, 64GB+ RAM, 500GB+ SSD storage

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                  │
├─────────────────────────────────────────────────────┤
│  Ingress Controller (NGINX)                        │
│  ├─── TLS Termination                              │
│  ├─── Rate Limiting                                │
│  └─── Load Balancing                               │
├─────────────────────────────────────────────────────┤
│  Application Services                               │
│  ├─── API Gateway (Port 8601)                      │
│  ├─── User Service (Port 8602)                     │
│  ├─── OCR Service (Port 8603)                      │
│  ├─── OCR Engine Service (Port 8604)               │
│  └─── Patient Queue Service (Port 8605)            │
├─────────────────────────────────────────────────────┤
│  Infrastructure Services                            │
│  ├─── MySQL (StatefulSet)                          │
│  ├─── Redis (Cluster)                              │
│  └─── RabbitMQ (HA Configuration)                  │
├─────────────────────────────────────────────────────┤
│  Monitoring & Logging                              │
│  ├─── Prometheus (Metrics)                         │
│  ├─── Grafana (Dashboards)                         │
│  └─── ELK Stack (Logs)                            │
└─────────────────────────────────────────────────────┘
```

## 📁 **Kubernetes Manifests Structure**

```
k8s/
├── namespaces/
│   ├── mediq-staging.yaml           # Staging environment
│   └── mediq-production.yaml        # Production environment
├── configmaps/
│   ├── api-gateway-config.yaml      # Service configurations
│   ├── user-service-config.yaml
│   ├── ocr-service-config.yaml
│   ├── patient-queue-service-config.yaml
│   └── ktp-templates-config.yaml    # OCR templates
├── secrets/
│   ├── database-secrets.yaml        # Database credentials
│   ├── jwt-secrets.yaml             # JWT signing keys
│   ├── redis-secrets.yaml           # Redis authentication
│   └── rabbitmq-secrets.yaml        # Message broker credentials
├── services/
│   ├── api-gateway-service.yaml     # Service definitions
│   ├── user-service-service.yaml
│   ├── ocr-service-service.yaml
│   └── patient-queue-service-service.yaml
├── deployments/
│   ├── api-gateway-deployment.yaml  # Application deployments
│   ├── user-service-deployment.yaml
│   ├── ocr-service-deployment.yaml
│   └── patient-queue-service-deployment.yaml
├── infrastructure/
│   ├── mysql-statefulset.yaml       # Database cluster
│   ├── redis-deployment.yaml        # Cache cluster
│   ├── rabbitmq-deployment.yaml     # Message broker
│   └── ingress.yaml                 # External access
├── hpa/
│   ├── api-gateway-hpa.yaml         # Auto-scaling rules
│   ├── user-service-hpa.yaml
│   ├── ocr-service-hpa.yaml
│   └── patient-queue-service-hpa.yaml
├── monitoring/
│   ├── prometheus.yaml              # Metrics collection
│   ├── grafana.yaml                 # Dashboards
│   └── service-monitors.yaml        # Service monitoring
├── rbac/
│   ├── service-accounts.yaml        # Security accounts
│   ├── cluster-roles.yaml           # Permissions
│   └── role-bindings.yaml           # Access control
├── network-policies/
│   ├── default-deny.yaml            # Network isolation
│   ├── api-gateway-netpol.yaml      # Service-specific rules
│   └── database-netpol.yaml         # Database access control
└── scripts/
    ├── deploy.sh                    # Deployment automation
    ├── rollback.sh                  # Rollback procedures
    ├── scale.sh                     # Scaling management
    └── health-check.sh              # Health monitoring
```

## 🚀 **Quick Deployment**

### 1. Clone dan Setup
```bash
# Clone repository
git clone https://github.com/your-org/mediq-backend.git
cd mediq-backend

# Setup kubectl context
kubectl config current-context
kubectl config set-context --current --namespace=mediq-staging
```

### 2. Deploy Infrastructure
```bash
# Create namespaces
kubectl apply -f k8s/namespaces/

# Deploy infrastructure services
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s  
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s
```

### 3. Deploy Applications
```bash
# Deploy application services
kubectl apply -f k8s/services/
kubectl apply -f k8s/deployments/

# Setup auto-scaling
kubectl apply -f k8s/hpa/

# Configure external access
kubectl apply -f k8s/infrastructure/ingress.yaml
```

### 4. Verify Deployment
```bash
# Check all pods are running
kubectl get pods -n mediq-staging

# Check services
kubectl get svc -n mediq-staging

# Check ingress
kubectl get ingress -n mediq-staging

# Run health checks
cd k8s/scripts
./health-check.sh staging
```

## 🎯 **Automated Deployment Scripts**

### Deploy Script Usage
```bash
cd k8s/scripts

# Deploy to staging (automatic)
./deploy.sh staging

# Deploy to production (with confirmation)  
./deploy.sh production

# Deploy specific service
./deploy.sh staging api-gateway

# Deploy all services
./deploy.sh production all
```

### Scaling Operations
```bash
# Scale specific service
./scale.sh api-gateway 5 production

# Scale all services
./scale.sh all default staging

# Get current scale status
kubectl get hpa -n mediq-production
```

### Rollback Procedures
```bash
# Rollback specific service
./rollback.sh api-gateway production

# Rollback all services
./rollback.sh all staging

# Check rollback history
kubectl rollout history deployment/api-gateway -n mediq-production
```

## 🔒 **Security Configuration**

### RBAC Setup
```bash
# Apply service accounts and roles
kubectl apply -f k8s/rbac/

# Verify RBAC configuration
kubectl auth can-i create pods --as=system:serviceaccount:mediq-production:api-gateway
```

### Network Policies
```bash
# Apply network isolation
kubectl apply -f k8s/network-policies/

# Test network connectivity
kubectl run test-pod --rm -it --image=busybox -- /bin/sh
```

### Secrets Management
```bash
# Create secrets from environment files
kubectl create secret generic jwt-secrets \
  --from-literal=jwt-secret="your-production-jwt-secret" \
  --from-literal=jwt-refresh-secret="your-refresh-secret" \
  -n mediq-production

# Update existing secrets
kubectl patch secret jwt-secrets \
  -p='{"data":{"jwt-secret":"bmV3LWp3dC1zZWNyZXQ="}}' \
  -n mediq-production
```

## 📊 **Monitoring Setup**

### Prometheus Configuration
```bash
# Deploy monitoring stack
kubectl apply -f k8s/monitoring/prometheus.yaml
kubectl apply -f k8s/monitoring/service-monitors.yaml

# Access Prometheus UI
kubectl port-forward svc/prometheus 9090:9090 -n mediq-monitoring
# Open http://localhost:9090
```

### Grafana Dashboards
```bash
# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana.yaml

# Get Grafana admin password
kubectl get secret grafana-admin -o jsonpath="{.data.password}" | base64 -d

# Access Grafana UI
kubectl port-forward svc/grafana 3000:3000 -n mediq-monitoring
# Open http://localhost:3000
```

### Health Monitoring
```bash
# Continuous health monitoring
watch './health-check.sh production'

# Check specific service health
kubectl logs -f deployment/api-gateway -n mediq-production
kubectl describe pod <pod-name> -n mediq-production
```

## ⚡ **Auto-scaling Configuration**

### HPA Metrics
```yaml
# Example HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Custom Metrics Scaling
```bash
# Install metrics server (if not available)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check HPA status
kubectl get hpa -n mediq-production --watch

# Describe HPA for detailed info
kubectl describe hpa api-gateway-hpa -n mediq-production
```

## 🔄 **CI/CD Integration**

### GitHub Actions Integration
```bash
# Setup kubectl in GitHub Actions
- name: Setup kubectl
  uses: azure/setup-kubectl@v3
  with:
    version: '1.24.0'

- name: Deploy to Kubernetes
  run: |
    echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
    export KUBECONFIG=kubeconfig
    cd k8s/scripts
    ./deploy.sh production
```

### ArgoCD Integration
```yaml
# ArgoCD Application manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mediq-backend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/mediq-backend
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: mediq-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🚨 **Troubleshooting**

### Common Issues

**Pods Not Starting**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n mediq-production

# Check logs
kubectl logs <pod-name> -n mediq-production --previous

# Check events
kubectl get events -n mediq-production --sort-by='.lastTimestamp'
```

**Database Connection Issues**:
```bash
# Test MySQL connectivity
kubectl run mysql-test --rm -it --image=mysql:8.0 -- mysql -h mysql -u mediq_user -p

# Check MySQL logs
kubectl logs statefulset/mysql -n mediq-production

# Verify secrets
kubectl get secret database-secrets -o yaml -n mediq-production
```

**Service Discovery Issues**:
```bash
# Check service endpoints
kubectl get endpoints -n mediq-production

# Test service connectivity
kubectl run test-pod --rm -it --image=busybox -- nslookup api-gateway.mediq-production.svc.cluster.local

# Check DNS resolution
kubectl exec -it <pod-name> -- nslookup kubernetes.default.svc.cluster.local
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pods -n mediq-production
kubectl top nodes

# Check HPA status
kubectl get hpa -n mediq-production

# Analyze Prometheus metrics
kubectl port-forward svc/prometheus 9090:9090 -n mediq-monitoring
```

### Recovery Procedures

**Complete System Recovery**:
```bash
# 1. Save current state
kubectl get all -n mediq-production -o yaml > backup-$(date +%Y%m%d).yaml

# 2. Clean deployment
kubectl delete -f k8s/deployments/ -n mediq-production

# 3. Re-deploy infrastructure
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/secrets/

# 4. Re-deploy applications  
kubectl apply -f k8s/services/
kubectl apply -f k8s/deployments/

# 5. Verify recovery
./health-check.sh production
```

**Database Recovery**:
```bash
# Restore from backup
kubectl exec -it mysql-0 -n mediq-production -- mysql -u root -p < backup.sql

# Restart dependent services
kubectl rollout restart deployment/user-service -n mediq-production
kubectl rollout restart deployment/patient-queue-service -n mediq-production
```

## 📈 **Production Considerations**

### Performance Optimization
- **Resource limits**: Set appropriate CPU/memory limits
- **JVM tuning**: Optimize Node.js garbage collection  
- **Connection pooling**: Configure database connection pools
- **Caching**: Implement Redis caching strategies
- **CDN**: Use CDN untuk static assets

### Security Hardening  
- **Pod Security Standards**: Enforce restricted security contexts
- **Network Policies**: Implement zero-trust networking
- **RBAC**: Minimal privilege access control
- **Image scanning**: Scan container images for vulnerabilities
- **Secrets rotation**: Implement automatic secret rotation

### Backup & Disaster Recovery
- **Database backups**: Automated daily backups
- **Configuration backups**: GitOps for configuration management
- **Cross-region replication**: Multi-region deployment
- **RTO/RPO targets**: 15-minute recovery objectives

### Monitoring & Alerting
- **SLA monitoring**: 99.9% uptime target
- **Performance metrics**: Response time < 200ms
- **Error rate alerts**: Error rate > 1% triggers alerts
- **Resource usage**: CPU > 80%, Memory > 85% alerts

---

**Status: ✅ Production-ready Kubernetes deployment dengan comprehensive monitoring, security, dan auto-scaling**
