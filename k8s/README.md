# MediQ Kubernetes Manifests

Production-ready Kubernetes manifests for deploying the complete MediQ backend microservices architecture.

## 📋 Overview

This directory contains comprehensive Kubernetes manifests to deploy:
- **API Gateway** (Port 8601) - Central HTTP entry point
- **User Service** (Port 8602) - Authentication & user management  
- **OCR Service** (Port 8603) - Document processing orchestration
- **OCR Engine Service** (Port 8604) - Core OCR processing engine
- **Patient Queue Service** (Port 8605) - Queue management with Redis

### Infrastructure Components
- **MySQL** - Persistent database with replicas
- **Redis** - Cache with clustering support
- **RabbitMQ** - Message broker with HA configuration
- **Ingress Controller** - NGINX-based external access
- **Monitoring Stack** - Prometheus, Grafana, Jaeger

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet/LoadBalancer                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                     Ingress Controller                         │
│                    (NGINX/cert-manager)                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                    API Gateway (8601)                          │
│                 Circuit Breaker + Rate Limiting                │
└─────┬───────────┬───────────┬───────────┬───────────────────────┘
      │           │           │           │
      ▼           ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│  User   │ │   OCR   │ │OCR Engine│ │  Queue  │
│Service  │ │Service  │ │ Service │ │ Service │
│ (8602)  │ │ (8603)  │ │ (8604)  │ │ (8605)  │
└────┬────┘ └────┬────┘ └─────────┘ └────┬────┘
     │           │                       │
     ▼           ▼                       ▼
┌─────────┐ ┌─────────┐             ┌─────────┐
│  MySQL  │ │RabbitMQ │             │  Redis  │
│ (3306)  │ │ (5672)  │             │ (6379)  │
└─────────┘ └─────────┘             └─────────┘
```

## 📁 Directory Structure

```
k8s/
├── namespaces/           # Namespace definitions for staging/production
├── configmaps/          # Configuration for each service
├── secrets/             # Encrypted secrets (JWT, DB passwords, etc.)
├── services/            # Kubernetes services with proper selectors
├── deployments/         # Main application deployments
├── infrastructure/      # MySQL, Redis, RabbitMQ, Ingress
├── hpa/                # Horizontal Pod Autoscalers
├── monitoring/          # Prometheus, Grafana, Jaeger
├── rbac/               # Service accounts, roles, bindings
├── network-policies/    # Network isolation and security
└── scripts/            # Deployment automation scripts
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (v1.24+)
- `kubectl` configured with cluster access
- NGINX Ingress Controller installed
- cert-manager for TLS certificates (optional)

### 1. Deploy to Staging
```bash
cd k8s/scripts
./deploy.sh staging
```

### 2. Deploy to Production
```bash
cd k8s/scripts
./deploy.sh production
```

### 3. Check Health Status
```bash
./health-check.sh production
```

## 🛠️ Management Scripts

### Deployment Script
```bash
./deploy.sh [staging|production]
```
- Deploys all services in correct order
- Waits for readiness probes
- Applies security policies
- Configures monitoring

### Scaling Script
```bash
./scale.sh [service] [replicas] [environment]
```
Examples:
```bash
./scale.sh api-gateway 5 production    # Scale API Gateway to 5 replicas
./scale.sh all default staging         # Reset all to default replicas
./scale.sh status production           # Show current scaling status
```

### Rollback Script
```bash
./rollback.sh [service] [environment] [revision]
```
Examples:
```bash
./rollback.sh api-gateway production    # Rollback to previous version
./rollback.sh user-service staging 3    # Rollback to specific revision
./rollback.sh all production            # Rollback all services
```

### Health Check Script
```bash
./health-check.sh [environment]
```
- Comprehensive health monitoring
- Pod, service, and infrastructure status
- Resource usage analysis
- HPA and PVC status

## ⚙️ Configuration

### Environment Variables
Each service uses ConfigMaps for environment-specific settings:
- **Database connections** - MySQL hostnames and settings
- **Message broker** - RabbitMQ configuration
- **Cache settings** - Redis configuration
- **API endpoints** - Service discovery URLs
- **Performance tuning** - Timeouts, pools, limits

### Secrets Management
All sensitive data is stored in Kubernetes secrets:
- JWT signing keys
- Database passwords
- Redis authentication
- RabbitMQ credentials
- External API keys

**⚠️ Important**: Update all secrets with production values!

### Resource Requirements

| Service | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---------|-------------|----------------|-----------|--------------|
| API Gateway | 500m | 1Gi | 2 | 4Gi |
| User Service | 500m | 1Gi | 2 | 4Gi |
| OCR Service | 500m | 1Gi | 2 | 4Gi |
| OCR Engine | 1 | 2Gi | 4 | 8Gi |
| Queue Service | 500m | 1Gi | 2 | 4Gi |
| MySQL | 500m | 1Gi | 2 | 4Gi |
| Redis | 200m | 512Mi | 1 | 2Gi |
| RabbitMQ | 300m | 1Gi | 2 | 4Gi |

## 🔒 Security Features

### Network Policies
- **Default deny-all** - Blocks all traffic by default
- **Service-specific rules** - Only allows required communication
- **Infrastructure isolation** - Database access restricted to authorized services
- **Monitoring access** - Dedicated rules for Prometheus scraping

### RBAC (Role-Based Access Control)
- **Service accounts** - Each service runs with minimal privileges
- **Pod Security Policies** - Enforces security constraints
- **Monitoring permissions** - Separate RBAC for monitoring stack

### Pod Security
- **Non-root execution** - All containers run as non-root users
- **Read-only root filesystem** - Prevents runtime file system modifications
- **Capability dropping** - Removes unnecessary Linux capabilities
- **Security contexts** - Proper user/group ID management

## 📈 Auto-scaling Configuration

### Horizontal Pod Autoscaler (HPA)
- **CPU-based scaling** - Scales based on CPU utilization (70-80%)
- **Memory-based scaling** - Scales based on memory usage (80-90%)
- **Custom metrics** - Queue length, request rate scaling
- **Scale-down protection** - Prevents rapid scaling oscillations

### Scaling Behavior
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # 5-minute cooldown
    policies:
    - type: Percent
      value: 10                      # Max 10% pods removed at once
  scaleUp:
    stabilizationWindowSeconds: 60   # 1-minute cooldown
    policies:
    - type: Percent
      value: 25                      # Max 25% pods added at once
```

## 🔍 Monitoring & Observability

### Prometheus Metrics
- **Application metrics** - Custom business metrics
- **Infrastructure metrics** - Node, pod, and resource usage
- **Service metrics** - Request rate, error rate, duration
- **Database metrics** - Connection pools, query performance

### Health Checks
- **Liveness probes** - Detects and restarts unhealthy containers
- **Readiness probes** - Controls traffic routing to healthy pods
- **Startup probes** - Handles slow-starting services

### Alerting Rules
- High CPU/memory usage
- Pod restart loops
- Service downtime
- Database connection issues
- High HTTP error rates

## 🌐 Ingress Configuration

### TLS Termination
```yaml
tls:
- hosts:
  - api.mediq.com
  - mediq.com
  secretName: mediq-tls-secret
```

### Rate Limiting
- **100 RPS** per IP for API endpoints
- **10 concurrent connections** per IP
- **Circuit breaker** for upstream failures

### Security Headers
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- Content-Security-Policy: Strict CSP rules

## 💾 Storage Configuration

### Persistent Volumes
- **MySQL**: 20Gi SSD storage with retention
- **Redis**: 10Gi SSD storage for persistence
- **RabbitMQ**: 10Gi SSD storage for message durability
- **Prometheus**: 50Gi SSD storage for metrics retention

### Backup Strategy
```bash
# Database backups (implement with CronJob)
kubectl create cronjob mysql-backup \
  --schedule="0 2 * * *" \
  --image=mysql:8.0 \
  -- mysqldump --all-databases
```

## 🔄 Deployment Strategies

### Rolling Updates
- **Zero downtime** deployments
- **Readiness probes** ensure traffic only goes to ready pods
- **Progressive rollout** with configurable parameters

### Blue-Green Deployments
```bash
# Switch traffic to new version
kubectl patch service api-gateway-service \
  -p '{"spec":{"selector":{"version":"v2.0.0"}}}'
```

### Canary Deployments
- Traffic splitting with ingress rules
- Gradual rollout with monitoring
- Automatic rollback on error thresholds

## 🐛 Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   # Check resource constraints, node affinity, PVC binding
   ```

2. **Service connectivity issues**
   ```bash
   kubectl get endpoints <service-name> -n <namespace>
   # Verify selector matches pod labels
   ```

3. **Database connection failures**
   ```bash
   kubectl logs deployment/user-service -n <namespace>
   # Check connection strings and secrets
   ```

4. **High resource usage**
   ```bash
   kubectl top pods -n <namespace>
   # Adjust resource requests/limits
   ```

### Debug Commands

```bash
# Pod logs
kubectl logs -f deployment/api-gateway -n mediq-production

# Service connectivity test
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash

# Database connectivity
kubectl exec -it mysql-0 -n mediq-production -- mysql -u root -p

# Redis connectivity  
kubectl exec -it redis-0 -n mediq-production -- redis-cli

# RabbitMQ management
kubectl port-forward service/rabbitmq-service 15672:15672 -n mediq-production
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [cert-manager](https://cert-manager.io/)

## 🤝 Contributing

1. Test changes in staging environment first
2. Update resource limits based on actual usage
3. Follow security best practices
4. Document configuration changes
5. Test rollback procedures

## 📞 Support

For deployment issues:
1. Check health status: `./health-check.sh <environment>`
2. Review pod logs: `kubectl logs <pod-name> -n <namespace>`
3. Verify resource usage: `kubectl top pods -n <namespace>`
4. Check network policies if connectivity issues occur

---

**⚠️ Production Deployment Checklist:**
- [ ] Update all secret values with production keys
- [ ] Configure TLS certificates for domains
- [ ] Set up monitoring alerts
- [ ] Configure backup procedures
- [ ] Test rollback procedures
- [ ] Review and adjust resource limits
- [ ] Verify network policies
- [ ] Set up log aggregation
- [ ] Configure external monitoring
- [ ] Test disaster recovery procedures
