# MediQ Infrastructure Setup Guide

## 🏗️ Overview

Complete infrastructure setup guide untuk MediQ backend microservices, covering Docker Compose untuk development, Kubernetes untuk production, security best practices, dan monitoring solutions.

## 📋 Infrastructure Architecture

```
                                    ┌─────────────────────────────────┐
                                    │          Load Balancer          │
                                    │         (NGINX/Traefik)         │
                                    └─────────────────────────────────┘
                                                    │
                                    ┌─────────────────────────────────┐
                                    │           Ingress               │
                                    │      (SSL Termination)          │
                                    └─────────────────────────────────┘
                                                    │
                          ┌─────────────────────────┼─────────────────────────┐
                          │                         │                         │
                 ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
                 │  API Gateway    │      │  API Gateway    │      │  API Gateway    │
                 │   (Port 8601)   │      │   (Port 8601)   │      │   (Port 8601)   │
                 └─────────────────┘      └─────────────────┘      └─────────────────┘
                          │                         │                         │
                          └─────────────────────────┼─────────────────────────┘
                                                    │
                                        ┌─────────────────┐
                                        │   Message Bus   │
                                        │   (RabbitMQ)    │
                                        └─────────────────┘
                                                    │
                    ┌─────────────────────────────┼─────────────────────────────┐
                    │                             │                             │
          ┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
          │  User Service   │          │  OCR Service    │          │ Queue Service   │
          │   (Port 8602)   │          │   (Port 8603)   │          │   (Port 8605)   │
          └─────────────────┘          └─────────────────┘          └─────────────────┘
                    │                             │                             │
                    │                             │                             │
          ┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
          │     MySQL       │          │  OCR Engine     │          │     Redis       │
          │   (Primary)     │          │   (Port 8604)   │          │    (Cluster)    │
          └─────────────────┘          └─────────────────┘          └─────────────────┘
                    │
          ┌─────────────────┐
          │     MySQL       │
          │   (Replica)     │
          └─────────────────┘
```

## 🐳 Docker Compose Setup

### Development Environment
```yaml
# docker-compose.dev.yml
version: '3.8'

networks:
  mediq-dev:
    driver: bridge

volumes:
  mysql_dev_data:
  redis_dev_data:
  rabbitmq_dev_data:

services:
  # Infrastructure Services
  mysql-dev:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: dev_password
      MYSQL_DATABASE: mediq_users
      MYSQL_USER: mediq_dev
      MYSQL_PASSWORD: dev_password
    ports:
      - "3306:3306"
    volumes:
      - mysql_dev_data:/var/lib/mysql
      - ./mysql/dev-init:/docker-entrypoint-initdb.d
    networks:
      - mediq-dev
    command: --default-authentication-plugin=mysql_native_password

  redis-dev:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_dev_data:/data
    networks:
      - mediq-dev
    command: redis-server --save 60 1 --loglevel warning

  rabbitmq-dev:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: mediq_dev
      RABBITMQ_DEFAULT_PASS: dev_password
      RABBITMQ_DEFAULT_VHOST: mediq_dev
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_dev_data:/var/lib/rabbitmq
    networks:
      - mediq-dev

  # OCR Engine
  ocr-engine-dev:
    build: ./e-KTP-OCR-CNN
    environment:
      FLASK_ENV: development
      MODEL_PATH: /app/models
    ports:
      - "8604:5000"
    volumes:
      - ./e-KTP-OCR-CNN/models:/app/models:ro
      - ./e-KTP-OCR-CNN/uploads:/app/uploads
    networks:
      - mediq-dev

  # Application Services (Hot Reload)
  api-gateway-dev:
    build:
      context: ./MediQ-Backend-API-Gateway
      target: development
    environment:
      - NODE_ENV=development
      - PORT=8601
      - RABBITMQ_URL=amqp://mediq_dev:dev_password@rabbitmq-dev:5672/mediq_dev
      - JWT_SECRET=dev-jwt-secret
      - JWT_REFRESH_SECRET=dev-refresh-secret
    ports:
      - "8601:8601"
    volumes:
      - ./MediQ-Backend-API-Gateway/src:/app/src
      - ./MediQ-Backend-API-Gateway/package.json:/app/package.json
    depends_on:
      - rabbitmq-dev
    networks:
      - mediq-dev
    command: npm run start:dev

  user-service-dev:
    build:
      context: ./MediQ-Backend-User-Service
      target: development
    environment:
      - NODE_ENV=development
      - PORT=8602
      - DATABASE_URL=mysql://mediq_dev:dev_password@mysql-dev:3306/mediq_users
      - RABBITMQ_URL=amqp://mediq_dev:dev_password@rabbitmq-dev:5672/mediq_dev
      - JWT_SECRET=dev-jwt-secret
      - JWT_REFRESH_SECRET=dev-refresh-secret
    ports:
      - "8602:8602"
    volumes:
      - ./MediQ-Backend-User-Service/src:/app/src
      - ./MediQ-Backend-User-Service/prisma:/app/prisma
    depends_on:
      - mysql-dev
      - rabbitmq-dev
    networks:
      - mediq-dev
    command: sh -c "npx prisma migrate dev && npm run start:dev"

  ocr-service-dev:
    build:
      context: ./MediQ-Backend-OCR-Service
      target: development
    environment:
      - NODE_ENV=development
      - PORT=8603
      - RABBITMQ_URL=amqp://mediq_dev:dev_password@rabbitmq-dev:5672/mediq_dev
      - OCR_API_URL=http://ocr-engine-dev:5000
      - UPLOAD_LIMIT=10mb
    ports:
      - "8603:8603"
    volumes:
      - ./MediQ-Backend-OCR-Service/src:/app/src
      - ./MediQ-Backend-OCR-Service/uploads:/app/uploads
    depends_on:
      - rabbitmq-dev
      - ocr-engine-dev
    networks:
      - mediq-dev
    command: npm run start:dev

  queue-service-dev:
    build:
      context: ./MediQ-Backend-Patient-Queue-Service
      target: development
    environment:
      - NODE_ENV=development
      - PORT=8605
      - DATABASE_URL=mysql://mediq_dev:dev_password@mysql-dev:3306/mediq_queue
      - RABBITMQ_URL=amqp://mediq_dev:dev_password@rabbitmq-dev:5672/mediq_dev
      - REDIS_URL=redis://redis-dev:6379
    ports:
      - "8605:8605"
    volumes:
      - ./MediQ-Backend-Patient-Queue-Service/src:/app/src
      - ./MediQ-Backend-Patient-Queue-Service/prisma:/app/prisma
    depends_on:
      - mysql-dev
      - redis-dev
      - rabbitmq-dev
    networks:
      - mediq-dev
    command: sh -c "npx prisma migrate dev && npm run start:dev"
```

### Production Environment
```yaml
# docker-compose.prod.yml
version: '3.8'

networks:
  mediq-prod:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: mediq-prod-br
  mediq-internal:
    driver: bridge
    internal: true

volumes:
  mysql_primary_data:
  mysql_replica_data:
  redis_cluster_data:
  rabbitmq_cluster_data:
  prometheus_data:
  grafana_data:

services:
  # Database Cluster
  mysql-primary:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: mediq_users
      MYSQL_USER: mediq_prod
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_REPLICATION_MODE: master
      MYSQL_REPLICATION_USER: replicator
      MYSQL_REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_primary_data:/var/lib/mysql
      - ./mysql/production-init:/docker-entrypoint-initdb.d
      - ./mysql/master.cnf:/etc/mysql/conf.d/mysql.cnf
    networks:
      - mediq-internal
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'

  mysql-replica:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_REPLICATION_MODE: slave
      MYSQL_REPLICATION_USER: replicator
      MYSQL_REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
      MYSQL_MASTER_HOST: mysql-primary
      MYSQL_MASTER_PORT_NUMBER: 3306
      MYSQL_MASTER_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "3307:3306"
    volumes:
      - mysql_replica_data:/var/lib/mysql
      - ./mysql/slave.cnf:/etc/mysql/conf.d/mysql.cnf
    depends_on:
      - mysql-primary
    networks:
      - mediq-internal
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'

  # Redis Cluster
  redis-cluster:
    image: redis:7-alpine
    command: >
      redis-server
      --maxmemory 1gb
      --maxmemory-policy allkeys-lru
      --save 900 1
      --save 300 10
      --save 60 10000
      --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_cluster_data:/data
    networks:
      - mediq-internal
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'

  # RabbitMQ Cluster
  rabbitmq-cluster:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
      RABBITMQ_DEFAULT_VHOST: mediq
      RABBITMQ_ERLANG_COOKIE: ${RABBITMQ_ERLANG_COOKIE}
      RABBITMQ_VM_MEMORY_HIGH_WATERMARK: 0.7
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_cluster_data:/var/lib/rabbitmq
      - ./rabbitmq/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf
    networks:
      - mediq-internal
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'

  # Application Services
  api-gateway:
    image: mediq/api-gateway:${VERSION:-latest}
    environment:
      - NODE_ENV=production
      - PORT=8601
      - RABBITMQ_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@rabbitmq-cluster:5672/mediq
      - JWT_SECRET=${JWT_SECRET}
      - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
      - TIMEOUT_MS=5000
      - RETRY_ATTEMPTS=3
    ports:
      - "8601:8601"
    depends_on:
      - rabbitmq-cluster
    networks:
      - mediq-prod
      - mediq-internal
    restart: unless-stopped
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8601/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Monitoring Stack
  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - mediq-internal
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
      GF_INSTALL_PLUGINS: grafana-piechart-panel
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/var/lib/grafana/dashboards
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
    networks:
      - mediq-internal
    restart: unless-stopped

  # Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - api-gateway
    networks:
      - mediq-prod
    restart: unless-stopped
```

## ☸️ Kubernetes vs Docker Compose Comparison

| Feature | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Use Case** | Development, Small Production | Large Scale Production |
| **Orchestration** | Single Host | Multi-Host Cluster |
| **Scaling** | Manual (`docker-compose scale`) | Auto-scaling (HPA/VPA) |
| **Load Balancing** | External (NGINX) | Built-in (Services, Ingress) |
| **Service Discovery** | DNS | Native Service Discovery |
| **Health Checks** | Basic | Advanced (Liveness, Readiness) |
| **Rolling Updates** | Manual | Automated |
| **Secrets Management** | Environment Variables | Native Secrets |
| **Storage** | Volumes | Persistent Volumes |
| **Networking** | Bridge/Overlay | Pod Network, Network Policies |
| **Monitoring** | External Stack | Native + External |

## 🔐 Security Best Practices

### 1. Network Security
```bash
# Docker Compose Network Isolation
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
  database:
    driver: bridge
    internal: true
```

### 2. Container Security
```dockerfile
# Multi-stage build for smaller attack surface
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS production
RUN addgroup -g 1001 -S nestjs && \
    adduser -S nestjs -u 1001
USER nestjs
COPY --from=builder --chown=nestjs:nestjs /app/node_modules ./node_modules
```

### 3. Secrets Management

#### Docker Compose Secrets
```yaml
# docker-compose.secrets.yml
version: '3.8'

secrets:
  jwt_secret:
    file: ./secrets/jwt_secret.txt
  mysql_password:
    file: ./secrets/mysql_password.txt
  redis_password:
    external: true

services:
  api-gateway:
    secrets:
      - jwt_secret
      - mysql_password
    environment:
      - JWT_SECRET_FILE=/run/secrets/jwt_secret
      - MYSQL_PASSWORD_FILE=/run/secrets/mysql_password
```

#### Kubernetes Secrets
```yaml
# Generate secrets
kubectl create secret generic mediq-secrets \
  --from-literal=jwt-secret="$(openssl rand -base64 32)" \
  --from-literal=mysql-password="$(openssl rand -base64 32)" \
  --from-literal=redis-password="$(openssl rand -base64 32)" \
  -n mediq-production
```

### 4. SSL/TLS Configuration
```nginx
# nginx/ssl.conf
server {
    listen 443 ssl http2;
    server_name api.mediq.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://api-gateway:8601;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 📊 Monitoring & Observability

### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'mediq-services'
    static_configs:
      - targets: 
        - 'api-gateway:8601'
        - 'user-service:8602'
        - 'ocr-service:8603'
        - 'queue-service:8605'
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### Grafana Dashboards
```json
{
  "dashboard": {
    "title": "MediQ Services Overview",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{service}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])"
          }
        ]
      }
    ]
  }
}
```

### Application Metrics
```typescript
// metrics.service.ts
import { Injectable } from '@nestjs/common';
import { Counter, Histogram, register } from 'prom-client';

@Injectable()
export class MetricsService {
  private readonly httpRequestsTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'status', 'endpoint'],
  });

  private readonly httpRequestDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'endpoint'],
    buckets: [0.1, 0.5, 1, 2, 5],
  });

  constructor() {
    register.registerMetric(this.httpRequestsTotal);
    register.registerMetric(this.httpRequestDuration);
  }

  incrementHttpRequests(method: string, status: number, endpoint: string) {
    this.httpRequestsTotal.inc({ method, status, endpoint });
  }

  observeHttpDuration(method: string, endpoint: string, duration: number) {
    this.httpRequestDuration.observe({ method, endpoint }, duration);
  }

  getMetrics() {
    return register.metrics();
  }
}
```

## 🚀 Deployment Strategies

### Blue-Green Deployment
```bash
#!/bin/bash
# blue-green-deploy.sh

CURRENT_COLOR=$(kubectl get service api-gateway -o jsonpath='{.spec.selector.version}')
NEW_COLOR="green"

if [ "$CURRENT_COLOR" = "green" ]; then
    NEW_COLOR="blue"
fi

echo "Deploying to $NEW_COLOR environment..."

# Deploy new version
kubectl set image deployment/api-gateway-$NEW_COLOR api-gateway=mediq/api-gateway:$NEW_VERSION

# Wait for deployment to be ready
kubectl rollout status deployment/api-gateway-$NEW_COLOR

# Run health checks
if curl -f http://api-gateway-$NEW_COLOR/health; then
    # Switch traffic
    kubectl patch service api-gateway -p '{"spec":{"selector":{"version":"'$NEW_COLOR'"}}}'
    echo "Traffic switched to $NEW_COLOR"
    
    # Scale down old version
    kubectl scale deployment api-gateway-$CURRENT_COLOR --replicas=0
else
    echo "Health check failed, rollback needed"
    exit 1
fi
```

### Canary Deployment
```yaml
# canary-deployment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-gateway-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 20
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 100
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: api-gateway
      trafficRouting:
        nginx:
          stableService: api-gateway-stable
          canaryService: api-gateway-canary
```

## 🔄 Backup & Disaster Recovery

### Automated Backup Script
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Database backup
docker exec mediq_mysql mysqldump \
    -u root -p$MYSQL_ROOT_PASSWORD \
    --all-databases \
    --routines \
    --triggers \
    --single-transaction > $BACKUP_DIR/mysql_backup.sql

# Redis backup
docker exec mediq_redis redis-cli BGSAVE
docker cp mediq_redis:/data/dump.rdb $BACKUP_DIR/redis_backup.rdb

# Configuration backup
cp -r ./k8s $BACKUP_DIR/
cp -r ./docker-compose* $BACKUP_DIR/
cp -r ./nginx $BACKUP_DIR/

# Upload to S3
aws s3 sync $BACKUP_DIR s3://mediq-backups/$(date +%Y%m%d)/

echo "Backup completed: $BACKUP_DIR"
```

### Disaster Recovery Procedures
```bash
#!/bin/bash
# disaster-recovery.sh

RESTORE_DATE=$1
BACKUP_PATH="s3://mediq-backups/$RESTORE_DATE/"

echo "Starting disaster recovery from $RESTORE_DATE"

# Download backup
aws s3 sync $BACKUP_PATH ./restore/

# Restore database
docker exec -i mediq_mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < ./restore/mysql_backup.sql

# Restore Redis
docker cp ./restore/redis_backup.rdb mediq_redis:/data/dump.rdb
docker restart mediq_redis

# Redeploy services
kubectl apply -f ./restore/k8s/

echo "Disaster recovery completed"
```

## 🔧 Infrastructure as Code

### Terraform Configuration
```hcl
# terraform/main.tf
provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "mediq_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "mediq-vpc"
    Environment = var.environment
  }
}

# EKS Cluster
resource "aws_eks_cluster" "mediq_cluster" {
  name     = "mediq-${var.environment}"
  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.24"

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

# RDS Instance
resource "aws_rds_instance" "mediq_mysql" {
  identifier     = "mediq-${var.environment}"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true
  
  db_name  = "mediq_users"
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  final_snapshot_identifier = "mediq-${var.environment}-final-snapshot"
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "mediq_redis" {
  name       = "mediq-redis-${var.environment}"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "mediq_redis" {
  replication_group_id       = "mediq-${var.environment}"
  description                = "Redis cluster for MediQ"
  
  node_type                  = "cache.t3.micro"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 3
  automatic_failover_enabled = true
  
  subnet_group_name          = aws_elasticache_subnet_group.mediq_redis.name
  security_group_ids         = [aws_security_group.redis.id]
}
```

## 📈 Performance Optimization

### Database Optimization
```sql
-- MySQL Performance Tuning
-- /mysql/performance.cnf

[mysqld]
# Buffer Pool Settings
innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 4

# Log Settings
innodb_log_file_size = 256M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2

# Connection Settings
max_connections = 200
max_user_connections = 180

# Query Cache
query_cache_type = 1
query_cache_size = 64M

# Indexes
key_buffer_size = 256M
sort_buffer_size = 4M
read_buffer_size = 2M
```

### Redis Configuration
```conf
# redis/redis.conf

# Memory Management
maxmemory 1gb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000

# Network
timeout 300
tcp-keepalive 300

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Security
requirepass ${REDIS_PASSWORD}
```

### RabbitMQ Tuning
```conf
# rabbitmq/rabbitmq.conf

# Memory Management
vm_memory_high_watermark.relative = 0.7
vm_memory_high_watermark_paging_ratio = 0.5

# Disk Space
disk_free_limit.relative = 2.0

# Connection Limits
num_acceptors.tcp = 10
handshake_timeout = 10000

# Clustering
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_k8s
cluster_formation.k8s.host = kubernetes.default.svc.cluster.local
```

## 🛠️ Development Tools & Setup

### Local Development with Tilt
```python
# Tiltfile
load('ext://restart_process', 'docker_build_with_restart')

# Build images
docker_build_with_restart(
    'mediq/api-gateway:dev',
    './MediQ-Backend-API-Gateway',
    entrypoint=['npm', 'run', 'start:dev'],
    dockerfile='./MediQ-Backend-API-Gateway/Dockerfile.dev',
    live_update=[
        sync('./MediQ-Backend-API-Gateway/src', '/app/src'),
        restart_container(),
    ],
)

# Apply manifests
k8s_yaml('k8s/development/')

# Port forwards
k8s_resource('api-gateway', port_forwards=8601)
k8s_resource('user-service', port_forwards=8602)
```

### Skaffold Configuration
```yaml
# skaffold.yaml
apiVersion: skaffold/v2beta28
kind: Config
metadata:
  name: mediq-backend

build:
  artifacts:
  - image: mediq/api-gateway
    context: ./MediQ-Backend-API-Gateway
    docker:
      dockerfile: Dockerfile.dev
    sync:
      manual:
      - src: "src/**/*.ts"
        dest: /app/src

deploy:
  kubectl:
    manifests:
    - k8s/development/*.yaml

portForward:
- resourceType: service
  resourceName: api-gateway
  port: 8601
  localPort: 8601
```

---

**Status: ✅ Complete infrastructure guide dengan development dan production configurations**
