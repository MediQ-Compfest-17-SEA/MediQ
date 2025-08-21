# MediQ Backend - Platform Digitalisasi Pelayanan Kesehatan

<p align="center">
  <img src="https://img.shields.io/badge/MediQ-Backend-blue?style=for-the-badge" alt="MediQ Backend" />
  <img src="https://img.shields.io/badge/Microservices-6_Services-green?style=for-the-badge" alt="6 Services" />
  <img src="https://img.shields.io/badge/Tech_Stack-NestJS_+_Python-orange?style=for-the-badge" alt="Tech Stack" />
  <img src="https://img.shields.io/badge/Architecture-Enterprise_Grade-red?style=for-the-badge" alt="Enterprise" />
</p>

## 🏥 Deskripsi

**MediQ Backend** adalah **platform digitalisasi pelayanan kesehatan** yang terdiri dari 6 microservices enterprise-grade untuk mengotomatisasi proses pendaftaran pasien, manajemen antrian, dan administrasi fasilitas kesehatan. Platform ini menggunakan teknologi **Machine Learning** untuk pemrosesan KTP otomatis dan **advanced messaging patterns** untuk komunikasi antar layanan.

## ✨ Fitur Utama Platform

### 🤖 Otomatisasi Cerdas
- **KTP Scanning**: ML-powered OCR dengan YOLO + EasyOCR untuk ekstraksi data otomatis
- **Auto Registration**: Pendaftaran pasien otomatis dari data KTP
- **Smart Queueing**: Sistem antrian digital dengan prioritas otomatis
- **Real-time Analytics**: Dashboard analytics untuk management faskes

### 🏗️ Enterprise Architecture
- **Microservices**: 6 layanan independen dengan komunikasi hybrid
- **API Gateway**: Centralized entry point dengan resilience patterns
- **Message Queue**: RabbitMQ untuk komunikasi internal yang reliable
- **Database per Service**: Isolated data dengan Prisma ORM

### 🔒 Keamanan Enterprise
- **JWT Authentication**: Access dan refresh tokens dengan role-based access
- **Circuit Breaker**: Fault tolerance dan automatic recovery
- **Rate Limiting**: Proteksi dari abuse dan DDoS attacks
- **Security Hardening**: Non-root containers, network policies, RBAC

## 🏗️ Arsitektur Sistem

### Service Architecture (Ports 8601-8606)

```
┌─────────────────────────────────────────────────────────────────┐
│                    MediQ Backend Platform                        │
├─────────────────────────────────────────────────────────────────┤
│  🚪 API Gateway (8601)                                          │
│  ├─── Centralized HTTP entry point                             │
│  ├─── JWT authentication & authorization                       │
│  ├─── Circuit breaker & retry logic                           │
│  ├─── Rate limiting & request routing                         │
│  └─── RabbitMQ proxy untuk semua services                     │
├─────────────────────────────────────────────────────────────────┤
│  👤 User Service (8602)                                         │
│  ├─── User management & registration                           │
│  ├─── Dual authentication (Admin: email/pass, User: NIK/nama) │
│  ├─── Role-based access control (PASIEN/OPERATOR/ADMIN)       │
│  └─── JWT token management dengan refresh tokens              │
├─────────────────────────────────────────────────────────────────┤
│  📷 OCR Service (8603)                                          │
│  ├─── KTP processing workflow orchestration                    │
│  ├─── Integration dengan OCR Engine untuk ML processing       │
│  ├─── User creation/lookup via RabbitMQ                       │
│  └─── Queue integration untuk auto-add pasien                │
├─────────────────────────────────────────────────────────────────┤
│  🤖 OCR Engine Service (8604)                                   │
│  ├─── ML-powered OCR dengan YOLO v8 + EasyOCR                 │
│  ├─── KTP/SIM detection dan text extraction                   │
│  ├─── Advanced ROI processing untuk accuracy optimal          │
│  └─── GPU/CPU support dengan performance optimization         │
├─────────────────────────────────────────────────────────────────┤
│  🏥 Patient Queue Service (8605)                                │
│  ├─── Digital queue management dengan smart prioritization    │
│  ├─── Real-time analytics dan statistics                      │
│  ├─── Redis caching untuk performance optimal                 │
│  └─── Integration dengan OCR untuk auto-queueing              │
├─────────────────────────────────────────────────────────────────┤
│  🏢 Institution Service (8606)                                  │
│  ├─── Healthcare facility management                           │
│  ├─── Service management (Poli, Apotek, dll)                  │
│  ├─── Institution search dan discovery                        │
│  └─── Integration dengan semua services untuk context         │
└─────────────────────────────────────────────────────────────────┘
```

### Communication Patterns

```
External Traffic:
Client Apps → API Gateway (HTTP) → Services (RabbitMQ)

Internal Communication:
Service ↔ Service (Direct RabbitMQ)

Message Patterns:
- user.create, user.check-nik-exists, auth.login.admin
- ocr.upload, ocr.confirm, ocr.process
- queue.add-to-queue, queue.get-stats, queue.get-next
- institution.create, institution.findAll, institution.getServices
```

## 🚀 Quick Start

### Prerequisites
- **Docker & Docker Compose** untuk development environment
- **Kubernetes cluster** untuk production deployment
- **MySQL 8.0+** untuk database services
- **Redis 6.0+** untuk caching
- **RabbitMQ 3.9+** untuk message broker

### Development Setup

```bash
# Clone main repository
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ.git
cd MediQ

# Start infrastructure services
docker-compose -f docker-compose.infrastructure.yml up -d

# Clone dan start individual services
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-API-Gateway.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-User-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Engine-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Patient-Queue-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Institution-Service.git

# Start each service
cd MediQ-Backend-API-Gateway && npm install && npm run start:dev &
cd MediQ-Backend-User-Service && npm install && npm run start:dev &
cd MediQ-Backend-OCR-Service && npm install && npm run start:dev &
cd MediQ-Backend-OCR-Engine-Service && pip install -r requirements.txt && python app.py &
cd MediQ-Backend-Patient-Queue-Service && npm install && npm run start:dev &
cd MediQ-Backend-Institution-Service && npm install && npm run start:dev &
```

### Production Deployment

```bash
# Deploy shared infrastructure
kubectl apply -f k8s/shared/

# Deploy ingress configuration
kubectl apply -f k8s/ingress.yaml

# Each service will be deployed via CI/CD or manual deployment
# See individual service repositories for deployment instructions
```

## 📋 Services Overview

| Service | Port | Technology | Repository | Status |
|---------|------|------------|------------|--------|
| **API Gateway** | 8601 | NestJS + RabbitMQ | [MediQ-Backend-API-Gateway](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-API-Gateway) | ✅ Ready |
| **User Service** | 8602 | NestJS + MySQL | [MediQ-Backend-User-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-User-Service) | ✅ Ready |
| **OCR Service** | 8603 | NestJS + RabbitMQ | [MediQ-Backend-OCR-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Service) | ✅ Ready |
| **OCR Engine** | 8604 | Python + ML | [MediQ-Backend-OCR-Engine-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Engine-Service) | ✅ Ready |
| **Patient Queue** | 8605 | NestJS + Redis | [MediQ-Backend-Patient-Queue-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Patient-Queue-Service) | ✅ Ready |
| **Institution** | 8606 | NestJS + MySQL | [MediQ-Backend-Institution-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Institution-Service) | ✅ Ready |

### 🎯 Service Responsibilities

#### 🚪 **API Gateway (Port 8601)**
- **Centralized Entry Point**: Routing semua external requests
- **Authentication & Authorization**: JWT validation dan role checking
- **Resilience Patterns**: Circuit breaker, retry, timeout, bulkhead
- **Request Transformation**: HTTP to RabbitMQ message conversion
- **Security**: Rate limiting, input validation, error handling

#### 👤 **User Service (Port 8602)**
- **User Management**: Registration, profile management, role assignment
- **Authentication**: Dual login system (admin/patient) dengan JWT
- **Authorization**: Role-based access control (PASIEN/OPERATOR/ADMIN_FASKES)
- **Security**: Password hashing, refresh token rotation, session management

#### 📷 **OCR Service (Port 8603)**
- **KTP Workflow Orchestration**: End-to-end KTP processing workflow
- **OCR Engine Integration**: Communication dengan ML-powered OCR engine
- **User Registration**: Auto-create users dari KTP data
- **Queue Integration**: Automatic patient queue addition

#### 🤖 **OCR Engine Service (Port 8604)**
- **ML Processing**: YOLO v8 untuk document detection (KTP/SIM)
- **Text Recognition**: EasyOCR dengan bahasa Indonesia dan Inggris  
- **Advanced OCR**: ROI optimization, multi-variant processing
- **Performance**: GPU acceleration dengan CPU fallback

#### 🏥 **Patient Queue Service (Port 8605)**
- **Digital Queue Management**: Smart prioritization (URGENT→HIGH→NORMAL→LOW)
- **Real-time Analytics**: Queue statistics, daily/weekly reports
- **Redis Caching**: High-performance data access
- **Integration**: OCR auto-queueing, institution context

#### 🏢 **Institution Service (Port 8606)**
- **Healthcare Facility Management**: CRUD operations untuk faskes
- **Service Management**: Layanan yang ditawarkan (Poli, Apotek, dll)
- **Search & Discovery**: Find institutions dengan fuzzy matching
- **Integration**: Context untuk queue dan user management

## 🛠️ Technology Stack

### **Backend Technologies**
- **NestJS**: Modern Node.js framework dengan TypeScript
- **Python Flask**: Lightweight framework untuk ML services
- **Prisma ORM**: Database toolkit dengan type safety
- **RabbitMQ**: Message broker untuk async communication
- **MySQL**: Relational database untuk data persistence
- **Redis**: In-memory cache untuk performance optimization

### **Machine Learning**
- **YOLO v8**: Object detection untuk document classification
- **EasyOCR**: Text recognition dengan multi-language support
- **OpenCV**: Image processing dan computer vision
- **NumPy**: Numerical computing untuk image operations

### **Infrastructure & DevOps**
- **Docker**: Containerization dengan multi-stage builds
- **Kubernetes**: Container orchestration dengan auto-scaling
- **GitHub Actions**: CI/CD automation dengan testing dan deployment
- **Prometheus & Grafana**: Monitoring dan observability stack

### **Security & Authentication**
- **JWT**: JSON Web Tokens untuk stateless authentication
- **BCrypt**: Password hashing dengan salt rounds
- **RBAC**: Role-based access control system
- **Network Policies**: Kubernetes network segmentation

## 📊 System Capabilities

### **Healthcare Workflow**
```
1. Patient KTP Scan → OCR Engine (ML processing)
2. Data Extraction → OCR Service (workflow orchestration) 
3. User Creation → User Service (authentication setup)
4. Queue Addition → Patient Queue Service (smart prioritization)
5. Institution Context → Institution Service (facility information)
6. Real-time Updates → All services via RabbitMQ
```

### **Performance Characteristics**
- **Throughput**: 100+ concurrent requests per service
- **Response Time**: <200ms untuk standard operations
- **OCR Processing**: 2-4 seconds per KTP dengan ML acceleration
- **Queue Management**: Real-time updates dengan <100ms latency
- **Auto-scaling**: 2-10 replicas per service based on load

### **Data Management**
- **Database per Service**: Isolated data dengan clear boundaries
- **Event Sourcing**: Audit trail untuk compliance requirements
- **Caching Strategy**: Redis untuk frequently accessed data
- **Backup & Recovery**: Automated backup dengan point-in-time recovery

## 📋 API Documentation

### **Swagger Documentation**
- **API Gateway**: [http://localhost:8601/api/docs](http://localhost:8601/api/docs)
- **User Service**: [http://localhost:8602/api/docs](http://localhost:8602/api/docs)
- **OCR Service**: [http://localhost:8603/api/docs](http://localhost:8603/api/docs)
- **OCR Engine**: [http://localhost:8604/docs](http://localhost:8604/docs)
- **Patient Queue**: [http://localhost:8605/api/docs](http://localhost:8605/api/docs)
- **Institution**: [http://localhost:8606/api/docs](http://localhost:8606/api/docs)

### **Core Workflows**

#### **Patient Registration Flow**
```http
# 1. Upload KTP
POST http://localhost:8601/ocr/upload
Content-Type: multipart/form-data
Body: KTP image file

# 2. Confirm extracted data
POST http://localhost:8601/ocr/confirm
Content-Type: application/json
Body: Verified KTP data

# 3. Get queue number
Response: Queue number dan estimated wait time
```

#### **Authentication Flow**
```http
# Admin Login
POST http://localhost:8601/auth/login/admin
Body: { "email": "admin@mediq.com", "password": "admin123" }

# Patient Login
POST http://localhost:8601/auth/login/user  
Body: { "nik": "3171012345678901", "name": "John Doe" }

# Access Protected Resources
GET http://localhost:8601/users/profile
Authorization: Bearer [JWT-token]
```

#### **Queue Management Flow**
```http
# Add to queue
POST http://localhost:8601/queue
Body: Patient data dengan priority

# Get next patient
GET http://localhost:8601/queue/next

# Update queue status
PATCH http://localhost:8601/queue/{id}/status
Body: { "status": "IN_PROGRESS" }

# Get statistics
GET http://localhost:8601/queue/stats
```

## 🧪 Testing & Quality Assurance

### **Testing Strategy**
- **Unit Tests**: 100% coverage requirement untuk semua services
- **Integration Tests**: Cross-service communication via RabbitMQ
- **E2E Tests**: Complete workflow testing melalui API Gateway
- **Performance Tests**: Load testing dan benchmark validation
- **Security Tests**: Authentication, authorization, input validation

### **Code Quality**
- **ESLint + Prettier**: Code formatting dan linting standards
- **TypeScript**: Type safety untuk JavaScript services
- **Python PEP 8**: Code style standards untuk Python services
- **SonarQube**: Code quality analysis dan security scanning

### **CI/CD Pipeline**
```yaml
# Each service repository includes:
├── .github/workflows/ci-cd.yml
├── Unit & Integration Testing
├── Security Vulnerability Scanning  
├── Docker Build & Push
├── Kubernetes Deployment
└── Multi-environment Support (staging/production)
```

## 📦 Deployment Options

### **Development Environment**
```bash
# Using Docker Compose
docker-compose up -d

# Services available at:
# http://localhost:8601 - API Gateway
# http://localhost:8602 - User Service
# http://localhost:8603 - OCR Service  
# http://localhost:8604 - OCR Engine
# http://localhost:8605 - Patient Queue
# http://localhost:8606 - Institution Service
```

### **Production Environment**
```bash
# Kubernetes deployment
kubectl apply -f k8s/shared/infrastructure/  # MySQL, Redis, RabbitMQ
kubectl apply -f k8s/ingress.yaml           # Load balancer setup

# Individual services deploy via CI/CD or:
kubectl apply -f service-repository/k8s/
```

### **Cloud Deployment**
- **AWS**: EKS dengan ALB ingress, RDS untuk database
- **Google Cloud**: GKE dengan Cloud SQL dan Cloud Memorystore
- **Azure**: AKS dengan Azure Database dan Azure Cache
- **On-Premise**: Kubernetes cluster dengan persistent storage

## 📊 Monitoring & Observability

### **Monitoring Stack**
- **Prometheus**: Metrics collection dari semua services
- **Grafana**: Dashboard visualization dengan custom panels
- **Jaeger**: Distributed tracing untuk request flows
- **ELK Stack**: Centralized logging dengan log aggregation

### **Key Metrics**
- **Request Rate**: HTTP requests per second per service
- **Response Time**: P95 response time < 200ms
- **Error Rate**: Error rate < 1% untuk production
- **Queue Performance**: Average wait time, throughput
- **OCR Accuracy**: Recognition accuracy > 95% untuk standard quality
- **Resource Usage**: CPU, memory, storage utilization

### **Alerting**
- **Service Health**: Automatic alerts untuk service downtime
- **Performance Degradation**: Response time atau error rate increases
- **Resource Exhaustion**: CPU, memory, atau storage thresholds
- **Queue Backlogs**: Patient queue length exceeds thresholds

## 🔒 Security Features

### **Authentication & Authorization**
- **Multi-factor Authentication**: Planned untuk admin accounts
- **Role-based Access Control**: Granular permissions per service
- **JWT Token Management**: Secure token lifecycle management
- **Session Security**: Secure session handling dengan timeout

### **Data Protection**
- **Encryption at Rest**: Database encryption untuk sensitive data
- **Encryption in Transit**: TLS untuk all API communications
- **PII Handling**: Secure handling untuk KTP dan personal data
- **Audit Logging**: Comprehensive audit trail untuk compliance

### **Infrastructure Security**
- **Network Segmentation**: Kubernetes network policies
- **Container Security**: Non-root containers, read-only filesystems
- **Secret Management**: Kubernetes secrets dengan rotation
- **Vulnerability Scanning**: Automated scanning dalam CI/CD pipeline

## 🚀 Scalability & Performance

### **Horizontal Scaling**
- **Auto-scaling**: HPA berdasarkan CPU, memory, custom metrics
- **Load Balancing**: Intelligent load distribution
- **Database Scaling**: Read replicas dan connection pooling
- **Cache Strategy**: Multi-level caching dengan Redis

### **Performance Optimization**
- **Connection Pooling**: Database dan message queue connections
- **Async Processing**: Non-blocking operations dengan RabbitMQ
- **Image Optimization**: Efficient Docker images dengan multi-stage builds
- **Resource Limits**: Appropriate CPU dan memory allocation

## 📚 Documentation

### **Architecture Documentation**
- **[AGENT.md](AGENT.md)**: Development guide dengan build/test commands
- **[microservices-architecture.md](microservices-architecture.md)**: System architecture guide
- **[KUBERNETES_DEPLOYMENT_GUIDE.md](KUBERNETES_DEPLOYMENT_GUIDE.md)**: Production deployment guide
- **[TESTING_DOCUMENTATION.md](TESTING_DOCUMENTATION.md)**: Testing strategy dan guidelines

### **Deployment Documentation**
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**: Production deployment procedures
- **[INFRASTRUCTURE_GUIDE.md](INFRASTRUCTURE_GUIDE.md)**: Infrastructure setup guide
- **[CI_CD_README.md](CI_CD_README.md)**: CI/CD pipeline documentation

### **Service-Specific Documentation**
Each service repository contains comprehensive README.md dalam Bahasa Indonesia dengan:
- Service description dan features
- API documentation dengan examples
- Installation dan setup guide
- Testing instructions
- Production deployment guide
- Architecture overview

## 🤝 Contributing

### **Development Workflow**
1. **Fork** individual service repository
2. **Create feature branch** (`git checkout -b feature/amazing-feature`)
3. **Follow service guidelines** dalam service README.md
4. **Write comprehensive tests** dengan 100% coverage
5. **Update documentation** jika menambah features
6. **Submit Pull Request** dengan detailed description

### **Code Standards**
- **TypeScript**: Strict type checking untuk NestJS services
- **Python PEP 8**: Code style untuk Python services
- **Comprehensive Testing**: Unit, integration, E2E tests
- **Security First**: Secure coding practices
- **Performance Aware**: Optimize untuk production loads

### **Review Process**
- **Automated Checks**: CI/CD pipeline validation
- **Code Review**: Peer review untuk all changes
- **Security Review**: Security team review untuk sensitive changes
- **Performance Review**: Performance impact assessment

## 🔧 Development Guide

### **Local Development**
```bash
# Start development environment
./scripts/setup-development.sh

# Run integration tests
./scripts/run-integration-tests.sh

# Deploy all services
./scripts/deploy-all-services.sh staging
```

### **Service Development**
```bash
# Navigate to specific service
cd MediQ-Backend-[Service-Name]

# Install dependencies
npm install  # atau pip install -r requirements.txt

# Start development server
npm run start:dev  # atau python app.py

# Run tests
npm run test:cov  # atau pytest --cov=.
```

### **Database Management**
```bash
# Run migrations untuk all services
for service in User-Service Patient-Queue-Service Institution-Service; do
  cd MediQ-Backend-$service
  npx prisma migrate dev
  cd ..
done
```

## 📈 Roadmap & Future Enhancements

### **Phase 1: Core Platform** ✅ COMPLETED
- ✅ Microservices architecture dengan 6 services
- ✅ ML-powered OCR processing
- ✅ Digital queue management
- ✅ User authentication dan authorization
- ✅ Institution management

### **Phase 2: Advanced Features** 🔄 PLANNED
- 📱 **Mobile App Integration**: React Native app untuk patients
- 💬 **Real-time Notifications**: WebSocket untuk queue updates
- 📊 **Advanced Analytics**: ML-powered queue prediction
- 🔄 **Workflow Automation**: Advanced business process automation

### **Phase 3: Enterprise Features** 🔮 FUTURE
- 🏥 **EMR Integration**: Electronic Medical Records integration
- 💳 **Payment Processing**: Integrated payment system
- 📋 **Appointment Scheduling**: Advanced scheduling system
- 🌐 **Multi-tenant**: Support untuk multiple healthcare facilities

## 📞 Support & Contact

### **Technical Support**
- **Documentation**: Comprehensive guides dalam repository
- **Issues**: GitHub Issues untuk bug reports dan feature requests
- **Discussions**: GitHub Discussions untuk community support

### **Development Team**
- **Lead Developer**: Alif Nurhidayat (KillerKing93)
- **Contact**: alifnurhidayatwork@gmail.com
- **Organization**: MediQ-Compfest-17-SEA

### **Community**
- **Contributing**: Welcome contributions dari community
- **Code of Conduct**: Professional dan respectful collaboration
- **License**: Dual license untuk flexibility in usage

## 📄 License

**Dual License**: Apache-2.0 + Commercial License (Royalty)

**Copyright (c) 2025 Alif Nurhidayat (KillerKing93)**

### **Open Source License**
Licensed under the Apache License, Version 2.0 (the "License");  
you may not use this file except in compliance with the License.  
You may obtain a copy of the License at: http://www.apache.org/licenses/LICENSE-2.0

### **Commercial License**
For commercial use, proprietary modifications, or usage in closed-source projects,  
a commercial license is required.  
**Contact**: alifnurhidayatwork@gmail.com

Unless required by applicable law or agreed to in writing, software  
distributed under the License is distributed on an "AS IS" BASIS,  
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  
See the License untuk specific language governing permissions dan  
limitations under the License.

---

**🏥 MediQ Backend - Revolutionizing Healthcare Digital Transformation**

**Built with ❤️ untuk Indonesian Healthcare System**

---

**💡 Quick Links:**
- 📖 [Architecture Guide](microservices-architecture.md)
- 🚀 [Deployment Guide](DEPLOYMENT_GUIDE.md)
- 🧪 [Testing Documentation](TESTING_DOCUMENTATION.md)
- ☸️ [Kubernetes Guide](KUBERNETES_DEPLOYMENT_GUIDE.md)
- 🔧 [Infrastructure Guide](INFRASTRUCTURE_GUIDE.md)
