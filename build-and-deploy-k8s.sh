#!/bin/bash

set -e

echo "🚀 Building Docker images and deploying to Kubernetes..."

# Services to build and deploy
SERVICES=(
    "MediQ-Backend-API-Gateway:api-gateway"
    "MediQ-Backend-User-Service:user-service"
    "MediQ-Backend-OCR-Service:ocr-service"
    "MediQ-Backend-OCR-Engine-Service:ocr-engine-service"
    "MediQ-Backend-Patient-Queue-Service:patient-queue-service"
    "MediQ-Backend-Institution-Service:institution-service"
)

# Create namespace
echo "📦 Creating mediq namespace..."
kubectl create namespace mediq --dry-run=client -o yaml | kubectl apply -f -

# Build Docker images
echo "🔨 Building Docker images..."
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r service_dir service_name <<< "$service_info"
    
    if [[ "$service_name" == "ocr-engine-service" ]]; then
        # Python service
        echo "🔨 Building $service_name (Python)..."
        cd "$service_dir"
        if [[ -f "Dockerfile" ]]; then
            docker build -t "mediq/${service_name}:latest" .
        else
            echo "⚠️  No Dockerfile found for $service_name, skipping..."
        fi
        cd ..
    else
        # Node.js services
        echo "🔨 Building $service_name (Node.js)..."
        cd "$service_dir"
        if [[ -f "Dockerfile" ]]; then
            docker build -t "mediq/${service_name}:latest" .
        else
            echo "⚠️  No Dockerfile found for $service_name, creating basic Dockerfile..."
            cat > Dockerfile << EOF
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Expose port
EXPOSE 8601 8602 8603 8604 8605 8606

# Start the application
CMD ["npm", "run", "start:prod"]
EOF
            docker build -t "mediq/${service_name}:latest" .
        fi
        cd ..
    fi
done

# Load images into minikube
echo "📦 Loading images into minikube..."
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r service_dir service_name <<< "$service_info"
    echo "Loading mediq/${service_name}:latest into minikube..."
    minikube image load "mediq/${service_name}:latest"
done

# Deploy infrastructure services first
echo "🗄️ Deploying infrastructure..."

# Deploy MySQL
kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: mediq
type: Opaque
data:
  root-password: IUAyTSBBeUlCM2VGMHJHMVYybkAhISE=  # Base64 encoded
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: mediq
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: mediq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_DATABASE
          value: mediq_db
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: mediq
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
EOF

# Deploy Redis
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: mediq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command: ["redis-server"]
        args: ["--appendonly", "yes"]
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: mediq
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF

# Deploy RabbitMQ
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: mediq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management-alpine
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: "mediq"
        - name: RABBITMQ_DEFAULT_PASS
          value: "mediq123"
        ports:
        - containerPort: 5672
        - containerPort: 15672
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-service
  namespace: mediq
spec:
  selector:
    app: rabbitmq
  ports:
  - name: amqp
    port: 5672
    targetPort: 5672
  - name: management
    port: 15672
    targetPort: 15672
  type: ClusterIP
EOF

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/mysql -n mediq
kubectl wait --for=condition=available --timeout=300s deployment/redis -n mediq
kubectl wait --for=condition=available --timeout=300s deployment/rabbitmq -n mediq

# Deploy microservices
echo "🚀 Deploying microservices..."
kubectl apply -f k8s/deployments/

# Wait for deployments
echo "⏳ Waiting for microservices to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n mediq

# Create ingress
echo "🌐 Creating ingress..."
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mediq-ingress
  namespace: mediq
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization, Content-Type, X-Requested-With"
spec:
  rules:
  - host: mediq-api-gateway.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway-service
            port:
              number: 8601
  - host: mediq-user-service.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 8602
  - host: mediq-ocr-service.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ocr-service
            port:
              number: 8603
  - host: mediq-ocr-engine-service.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ocr-engine-service
            port:
              number: 8604
  - host: mediq-patient-queue-service.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: patient-queue-service
            port:
              number: 8605
  - host: mediq-institution-service.craftthingy.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: institution-service
            port:
              number: 8606
EOF

echo "✅ Deployment completed!"
echo ""
echo "📋 Status:"
kubectl get all -n mediq

echo ""
echo "🌐 Services:"
kubectl get ingress -n mediq

echo ""
echo "🔗 Access URLs:"
echo "- API Gateway: http://mediq-api-gateway.craftthingy.com"
echo "- User Service: http://mediq-user-service.craftthingy.com"
echo "- OCR Service: http://mediq-ocr-service.craftthingy.com"
echo "- OCR Engine Service: http://mediq-ocr-engine-service.craftthingy.com"
echo "- Patient Queue Service: http://mediq-patient-queue-service.craftthingy.com"
echo "- Institution Service: http://mediq-institution-service.craftthingy.com"
