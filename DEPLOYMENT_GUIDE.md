# MediQ Backend - Production Deployment Guide

## 🚀 **Deployment Overview**

MediQ backend menggunakan **containerized microservices architecture** dengan Docker dan orchestration support untuk production deployment.

## 🏗️ **Infrastructure Requirements**

### System Requirements
- **CPU**: 4+ cores per service
- **Memory**: 8GB+ total (2GB per service)
- **Storage**: 50GB+ SSD
- **Network**: 1Gbps+ bandwidth
- **OS**: Linux (Ubuntu 20.04+ recommended)

### External Dependencies  
- **MySQL 8.0+**: Primary database
- **Redis 6.0+**: Caching layer
- **RabbitMQ 3.9+**: Message broker
- **External OCR API**: KTP processing service

## 🔄 **CI/CD Pipeline**

### GitHub Actions Workflow
MediQ menggunakan automated CI/CD pipeline dengan GitHub Actions untuk:
- **Automated Testing**: Unit, integration, dan E2E tests
- **Security Scanning**: Dependency vulnerability scanning
- **Docker Build**: Multi-stage optimized builds
- **Multi-Environment**: Staging (auto) dan Production (manual approval)
- **Health Checks**: Post-deployment verification

### Workflow Triggers
- **Push to main/develop**: Auto-deployment to staging
- **Manual dispatch**: Production deployment with approval
- **Pull requests**: Automated testing dan validation

### Environment Management
```bash
# Staging Environment (auto-deployment)
ENVIRONMENT=staging
API_URL=https://api-staging.mediq.com

# Production Environment (manual approval)
ENVIRONMENT=production  
API_URL=https://api.mediq.com
```

## 📦 **Service Deployment**

### **1. API Gateway** (Port 8601)
```dockerfile
# Production Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
EXPOSE 8601
CMD ["node", "dist/main.js"]
```

**Environment Variables**:
```env
PORT=8601
RABBITMQ_URL=amqp://rabbitmq-cluster:5672
JWT_SECRET=your-production-jwt-secret
JWT_REFRESH_SECRET=your-production-refresh-secret
TIMEOUT_MS=5000
RETRY_ATTEMPTS=3
CIRCUIT_BREAKER_THRESHOLD=5
```

### **2. User Service** (Port 8602)
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
RUN npm ci
RUN npx prisma generate
COPY . .
RUN npm run build

FROM node:18-alpine  
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
EXPOSE 8602
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
```

**Environment Variables**:
```env
PORT=8602
DATABASE_URL=mysql://mediq_user:password@mysql-primary:3306/mediq_users
RABBITMQ_URL=amqp://rabbitmq-cluster:5672
JWT_SECRET=your-production-jwt-secret
JWT_REFRESH_SECRET=your-production-refresh-secret
```

### **3. OCR Service** (Port 8603)  
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app  
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 8603
CMD ["node", "dist/main.js"]
```

**Environment Variables**:
```env
PORT=8603
RABBITMQ_URL=amqp://rabbitmq-cluster:5672
OCR_API_URL=https://your-ocr-api.com/scan
OCR_API_KEY=your-ocr-api-key
UPLOAD_LIMIT=10mb
```

### **4. Patient Queue Service** (Port 8605)
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
RUN npm ci
RUN npx prisma generate
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules  
COPY --from=builder /app/prisma ./prisma
EXPOSE 8605
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
```

**Environment Variables**:
```env
PORT=8605
DATABASE_URL=mysql://mediq_queue:password@mysql-primary:3306/mediq_queue
RABBITMQ_URL=amqp://rabbitmq-cluster:5672
REDIS_HOST=redis-cluster
REDIS_PORT=6379
REDIS_PASSWORD=your-redis-password
REDIS_TTL=3600
```

## 🐳 **Docker Compose Production**

```yaml
version: '3.8'

services:
  # Infrastructure Services
  mysql-primary:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: mediq_users
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d
    restart: unless-stopped

  redis-cluster:  
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  rabbitmq-cluster:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASS}
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    restart: unless-stopped

  # Application Services  
  api-gateway:
    build: ./MediQ-Backend-API-Gateway
    ports:
      - "8601:8601"
    environment:
      - PORT=8601
      - RABBITMQ_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq-cluster:5672
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - rabbitmq-cluster
    restart: unless-stopped
    
  user-service:
    build: ./MediQ-Backend-User-Service
    ports:
      - "8602:8602"  
    environment:
      - PORT=8602
      - DATABASE_URL=mysql://mediq_user:${DB_PASSWORD}@mysql-primary:3306/mediq_users
      - RABBITMQ_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq-cluster:5672
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - mysql-primary
      - rabbitmq-cluster
    restart: unless-stopped

  ocr-service:
    build: ./MediQ-Backend-OCR-Service
    ports:
      - "8603:8603"
    environment:
      - PORT=8603
      - RABBITMQ_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq-cluster:5672
      - OCR_API_URL=${OCR_API_URL}
    depends_on:
      - rabbitmq-cluster
    restart: unless-stopped

  queue-service:
    build: ./MediQ-Backend-Patient-Queue-Service  
    ports:
      - "8605:8605"
    environment:
      - PORT=8605
      - DATABASE_URL=mysql://mediq_queue:${DB_PASSWORD}@mysql-primary:3306/mediq_queue
      - RABBITMQ_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq-cluster:5672
      - REDIS_HOST=redis-cluster
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      - mysql-primary
      - redis-cluster
      - rabbitmq-cluster
    restart: unless-stopped

volumes:
  mysql_data:
  redis_data:
  rabbitmq_data:
```

## ⚙️ **Environment Configuration**

### Production .env
```env
# Database
MYSQL_ROOT_PASSWORD=your-secure-mysql-root-password
DB_PASSWORD=your-secure-db-password

# Message Queue
RABBITMQ_USER=your-rabbitmq-user
RABBITMQ_PASS=your-secure-rabbitmq-password

# Cache  
REDIS_PASSWORD=your-secure-redis-password

# Security
JWT_SECRET=your-very-secure-jwt-secret-256-bits-minimum
JWT_REFRESH_SECRET=your-very-secure-refresh-secret-256-bits

# External APIs
OCR_API_URL=https://your-production-ocr-api.com/scan
OCR_API_KEY=your-ocr-api-production-key

# Monitoring
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project
LOG_LEVEL=info
```

## 🔒 **Security Configuration**

### SSL/TLS Setup
```nginx
# Nginx reverse proxy configuration
upstream api_gateway {
    server 127.0.0.1:3001;
}

server {
    listen 443 ssl http2;
    server_name api.mediq.com;
    
    ssl_certificate /path/to/ssl/certificate.crt;
    ssl_certificate_key /path/to/ssl/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location / {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Network Security
```yaml
# Docker network isolation
networks:
  mediq_internal:
    driver: bridge
    internal: true
  mediq_external:
    driver: bridge
```

## 📊 **Monitoring & Observability**

### Health Checks
```yaml
# Docker Compose health checks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Prometheus Metrics
```typescript
// Custom metrics endpoint
@Get('metrics')
async getMetrics() {
  return {
    requests_total: this.metricsService.getTotalRequests(),
    response_time_avg: this.metricsService.getAverageResponseTime(),
    error_rate: this.metricsService.getErrorRate(),
    active_connections: this.metricsService.getActiveConnections(),
  };
}
```

### Log Aggregation
```yaml
# ELK Stack integration
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 🚀 **Deployment Scripts**

### Automated Deployment
```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 Starting MediQ Backend Deployment..."

# Pull latest code
git pull origin main

# Build services
echo "🏗️ Building services..."
docker-compose build --no-cache

# Database migrations
echo "📊 Running database migrations..."
docker-compose run --rm user-service npx prisma migrate deploy
docker-compose run --rm queue-service npx prisma migrate deploy

# Deploy services
echo "🚀 Deploying services..."
docker-compose up -d

# Health checks
echo "🏥 Running health checks..."
./scripts/health-check.sh

echo "✅ Deployment completed successfully!"
```

### Rolling Update
```bash
#!/bin/bash
# rolling-update.sh

services=("api-gateway" "user-service" "ocr-service" "queue-service")

for service in "${services[@]}"; do
    echo "🔄 Updating $service..."
    
    # Build new image
    docker-compose build $service
    
    # Graceful shutdown
    docker-compose stop $service
    
    # Start with new image
    docker-compose up -d $service
    
    # Health check
    ./scripts/health-check.sh $service
    
    echo "✅ $service updated successfully"
    sleep 10
done
```

## 🔄 **Backup & Recovery**

### Database Backup
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# MySQL backup
docker exec mediq_mysql mysqldump -u root -p$MYSQL_ROOT_PASSWORD \
    --all-databases --routines --triggers > $BACKUP_DIR/mysql_backup.sql

# Redis backup  
docker exec mediq_redis redis-cli SAVE
docker cp mediq_redis:/data/dump.rdb $BACKUP_DIR/redis_backup.rdb

echo "✅ Backup completed: $BACKUP_DIR"
```

### Disaster Recovery
```bash
#!/bin/bash
# restore.sh

BACKUP_DIR=$1

# Restore MySQL
docker exec -i mediq_mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < $BACKUP_DIR/mysql_backup.sql

# Restore Redis
docker cp $BACKUP_DIR/redis_backup.rdb mediq_redis:/data/dump.rdb
docker restart mediq_redis

echo "✅ Restore completed from: $BACKUP_DIR"
```

## ⚓ **Kubernetes Deployment**

### Complete Kubernetes Manifests
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mediq-production
---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediq-config
  namespace: mediq-production
data:
  RABBITMQ_URL: "amqp://mediq:password@rabbitmq:5672"
  REDIS_HOST: "redis"
  REDIS_PORT: "6379"
---
# k8s/api-gateway-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: mediq-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: mediq/api-gateway:latest
        ports:
        - containerPort: 8601
        env:
        - name: PORT
          value: "8601"
        - name: RABBITMQ_URL
          valueFrom:
            configMapKeyRef:
              name: mediq-config
              key: RABBITMQ_URL
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8601
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8601
          initialDelaySeconds: 5
          periodSeconds: 5
---
# k8s/api-gateway-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: mediq-production
spec:
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 8601
  type: LoadBalancer
```

### Helm Deployment
```bash
# Deploy with Helm
helm install mediq ./k8s/helm/ \
  --namespace mediq-production \
  --create-namespace \
  --values ./k8s/helm/values-production.yaml

# Upgrade services
helm upgrade mediq ./k8s/helm/ \
  --namespace mediq-production \
  --values ./k8s/helm/values-production.yaml

# Rollback if needed
helm rollback mediq 1 --namespace mediq-production
```

### Service Mesh (Istio)
```yaml
# k8s/istio-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: mediq-gateway
  namespace: mediq-production
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: mediq-tls-cert
    hosts:
    - api.mediq.com
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mediq-api
  namespace: mediq-production
spec:
  hosts:
  - api.mediq.com
  gateways:
  - mediq-gateway
  http:
  - route:
    - destination:
        host: api-gateway
        port:
          number: 80
```

## 📈 **Scaling Strategy**

### Horizontal Pod Autoscaler
```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: mediq-production
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

### Vertical Pod Autoscaler
```yaml
# k8s/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-gateway-vpa
  namespace: mediq-production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  updatePolicy:
    updateMode: "Auto"
```

### Load Balancing
```nginx
upstream mediq_api {
    least_conn;
    server mediq-api-1:3001;
    server mediq-api-2:3001;  
    server mediq-api-3:3001;
}
```

## 🎯 **Performance Optimization**

### Connection Pooling
```typescript
// Database connection pooling
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
  pool_size = 20
  connection_timeout = 10
}
```

### Caching Strategy  
```typescript
// Redis caching configuration
@CacheModule.register({
  store: redisStore,
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  ttl: 3600, // 1 hour
  max: 1000, // Maximum items in cache
})
```

---

**Status: ✅ Production-ready deployment configuration dengan comprehensive monitoring dan security**
