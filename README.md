# MediQ Backend - Platform Digitalisasi Pelayanan Kesehatan

<p align="center">
  <img src="https://img.shields.io/badge/MediQ-Healthcare_Platform-blue?style=for-the-badge&logo=medical-cross" alt="MediQ Platform" />
  <img src="https://img.shields.io/badge/Microservices-6_Services-green?style=for-the-badge&logo=docker" alt="6 Services" />
  <img src="https://img.shields.io/badge/Architecture-Enterprise_Grade-red?style=for-the-badge&logo=kubernetes" alt="Enterprise" />
  <img src="https://img.shields.io/badge/ML_Powered-YOLO_+_EasyOCR-orange?style=for-the-badge&logo=tensorflow" alt="ML Powered" />
</p>

<p align="center">
  <strong>🏥 Solusi Digitalisasi Terpadu untuk Fasilitas Kesehatan Indonesia</strong><br/>
  Platform microservices modern untuk otomatisasi pendaftaran pasien, manajemen antrian digital, dan administrasi fasilitas kesehatan
</p>

---

## 🎯 Deskripsi Platform

**MediQ Backend** adalah **platform digitalisasi pelayanan kesehatan enterprise-grade** yang dirancang khusus untuk fasilitas kesehatan di Indonesia. Platform ini mengotomatisasi seluruh proses dari pendaftaran pasien hingga manajemen antrian menggunakan teknologi **Machine Learning**, **microservices architecture**, dan **advanced messaging patterns**.

### 🌟 Value Proposition
- **⏱️ Efisiensi Waktu**: Reduce pendaftaran pasien dari 10-15 menit menjadi 2-3 menit
- **📊 Transparansi**: Real-time queue information dan estimated wait time
- **🤖 Otomatisasi**: KTP scanning otomatis menggantikan form manual
- **📈 Analytics**: Data-driven insights untuk optimasi pelayanan
- **🔒 Keamanan**: Enterprise-grade security untuk data pasien

## 🏗️ Arsitektur Sistem

### 📐 Microservices Architecture

```mermaid
graph TB
    subgraph "🌐 External Layer"
        CLIENT[👥 Client Applications<br/>Mobile App, Web Dashboard, Kiosk]
        ADMIN[👨‍💼 Admin Dashboard<br/>Management Interface]
    end
    
    subgraph "🚪 API Gateway Layer (Port 8601)"
        GW[🚪 API Gateway<br/>- Centralized Entry Point<br/>- JWT Authentication<br/>- Circuit Breaker<br/>- Rate Limiting]
    end
    
    subgraph "🔧 Microservices Layer"
        USER[👤 User Service<br/>Port 8602<br/>- Authentication<br/>- User Management<br/>- Role-based Access]
        
        OCR[📷 OCR Service<br/>Port 8603<br/>- KTP Workflow<br/>- Data Validation<br/>- Service Integration]
        
        ENGINE[🤖 OCR Engine<br/>Port 8604<br/>- YOLO Detection<br/>- EasyOCR Processing<br/>- ML Pipeline]
        
        QUEUE[🏥 Patient Queue<br/>Port 8605<br/>- Smart Queueing<br/>- Analytics<br/>- Redis Cache]
        
        INST[🏢 Institution<br/>Port 8606<br/>- Facility Management<br/>- Service Discovery<br/>- Context Provider]
    end
    
    subgraph "💾 Data Layer"
        MYSQL[(🗄️ MySQL Cluster<br/>User & Institution Data)]
        REDIS[(⚡ Redis Cluster<br/>Queue Cache & Sessions)]
        RMQ[(📨 RabbitMQ<br/>Message Broker)]
    end
    
    subgraph "📊 Infrastructure Layer"
        PROM[📈 Prometheus<br/>Metrics Collection]
        GRAF[📊 Grafana<br/>Dashboards]
        JAEGER[🔍 Jaeger<br/>Distributed Tracing]
    end

    CLIENT --> GW
    ADMIN --> GW
    
    GW <--> USER
    GW <--> OCR
    GW <--> QUEUE
    GW <--> INST
    
    OCR <--> ENGINE
    OCR <--> USER
    OCR <--> QUEUE
    QUEUE <--> USER
    QUEUE <--> INST
    
    USER --- MYSQL
    INST --- MYSQL
    QUEUE --- REDIS
    
    USER --- RMQ
    OCR --- RMQ
    QUEUE --- RMQ
    INST --- RMQ
    GW --- RMQ
    
    USER --> PROM
    OCR --> PROM
    ENGINE --> PROM
    QUEUE --> PROM
    INST --> PROM
    GW --> PROM
    
    PROM --> GRAF
    PROM --> JAEGER
```

### 🎯 Service Responsibilities

| Service | Port | Technology | Primary Function | Key Features |
|---------|------|------------|------------------|--------------|
| **🚪 API Gateway** | 8601 | NestJS + RabbitMQ | Entry Point & Routing | Circuit breaker, rate limiting, JWT auth |
| **👤 User Service** | 8602 | NestJS + MySQL | Authentication & Users | Dual login, RBAC, token management |
| **📷 OCR Service** | 8603 | NestJS + RabbitMQ | KTP Workflow | Orchestration, validation, integration |
| **🤖 OCR Engine** | 8604 | Python + ML | ML Processing | YOLO detection, EasyOCR, GPU support |
| **🏥 Patient Queue** | 8605 | NestJS + Redis | Queue Management | Smart prioritization, analytics, caching |
| **🏢 Institution** | 8606 | NestJS + MySQL | Facility Management | CRUD operations, search, service discovery |

## ✨ Platform Features

### 🤖 Intelligent Automation
- **🔍 AI-Powered KTP Scanning**: YOLO v8 + EasyOCR untuk ekstraksi data otomatis
- **👤 Auto User Registration**: Pendaftaran pasien otomatis dari data KTP
- **🏥 Smart Queue Management**: Prioritization otomatis berdasarkan kondisi pasien
- **📊 Real-time Analytics**: Dashboard insights untuk optimasi pelayanan

### 🏗️ Enterprise Architecture
- **⚡ High Performance**: 100+ concurrent requests per service
- **🔄 Fault Tolerance**: Circuit breaker, retry logic, graceful degradation
- **📈 Auto Scaling**: Kubernetes HPA dengan CPU/memory/custom metrics
- **🔒 Enterprise Security**: JWT, RBAC, network policies, container security

### 🌐 Healthcare Workflow Integration
- **📱 Multi-Channel Access**: Mobile app, web dashboard, kiosk integration
- **🔄 End-to-End Process**: KTP scan → user creation → queue management
- **📋 Institution Context**: Multi-facility support dengan service discovery
- **📊 Management Dashboard**: Real-time analytics untuk healthcare management

## 🚀 Quick Start

### 🛠️ Prerequisites
```bash
# Required Infrastructure
- Docker & Docker Compose 20+
- Kubernetes cluster (untuk production)
- MySQL 8.0+
- Redis 6.0+
- RabbitMQ 3.9+
- Node.js 18+ (untuk development)
- Python 3.11+ (untuk OCR Engine)
```

### 💻 Development Setup

#### **1. Clone Main Repository**
```bash
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ.git
cd MediQ
```

#### **2. Start Infrastructure Services**
```bash
# Start MySQL, Redis, RabbitMQ
docker-compose -f docker-compose.infrastructure.yml up -d

# Verify infrastructure
docker-compose -f docker-compose.infrastructure.yml ps
```

#### **3. Setup Individual Services**
```bash
# Clone all service repositories
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-API-Gateway.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-User-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Engine-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Patient-Queue-Service.git
git clone https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Institution-Service.git

# Setup and start services
cd MediQ-Backend-API-Gateway && npm install && npm run start:dev &
cd ../MediQ-Backend-User-Service && npm install && npm run start:dev &
cd ../MediQ-Backend-OCR-Service && npm install && npm run start:dev &
cd ../MediQ-Backend-OCR-Engine-Service && pip install -r requirements.txt && python app.py &
cd ../MediQ-Backend-Patient-Queue-Service && npm install && npm run start:dev &
cd ../MediQ-Backend-Institution-Service && npm install && npm run start:dev &
```

#### **4. Verify Services**
```bash
# Check all services are running
curl http://localhost:8601/health  # API Gateway
curl http://localhost:8602/health  # User Service
curl http://localhost:8603/health  # OCR Service
curl http://localhost:8604/health/health  # OCR Engine
curl http://localhost:8605/health  # Patient Queue
curl http://localhost:8606/health  # Institution Service
```

### 🚀 Production Deployment

#### **Kubernetes Production**
```bash
# Deploy infrastructure
kubectl apply -f k8s/shared/infrastructure/

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Services deploy via CI/CD atau manual:
kubectl apply -f MediQ-Backend-[Service]/k8s/
```

#### **Docker Compose Production**
```bash
# Production deployment
docker-compose -f docker-compose.prod.yml up -d

# Monitor services
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

## 📋 API Documentation

### 🌐 **Service Endpoints**

| Service | Development URL | Production URL | Swagger Docs |
|---------|----------------|----------------|--------------|
| **API Gateway** | http://localhost:8601 | https://api.mediq.com | [/api/docs](http://localhost:8601/api/docs) |
| **User Service** | http://localhost:8602 | Internal only | [/api/docs](http://localhost:8602/api/docs) |
| **OCR Service** | http://localhost:8603 | Internal only | [/api/docs](http://localhost:8603/api/docs) |
| **OCR Engine** | http://localhost:8604 | Internal only | [/docs](http://localhost:8604/docs) |
| **Patient Queue** | http://localhost:8605 | Internal only | [/api/docs](http://localhost:8605/api/docs) |
| **Institution** | http://localhost:8606 | Internal only | [/api/docs](http://localhost:8606/api/docs) |

### 🔄 **Core Workflows**

#### **1. Patient Registration via KTP Scan**
```bash
# Upload KTP image
curl -X POST http://localhost:8601/ocr/upload \
  -F "file=@ktp_image.jpg"

# Response: Extracted KTP data untuk verification

# Confirm dan register
curl -X POST http://localhost:8601/ocr/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "nik": "3171012345678901",
    "nama": "John Doe",
    "tempat_lahir": "Jakarta",
    "priority": "NORMAL"
  }'

# Response: User created + Queue number assigned
```

#### **2. Admin Authentication Flow**
```bash
# Admin login
curl -X POST http://localhost:8601/auth/login/admin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@mediq.com",
    "password": "admin123"
  }'

# Response: JWT access + refresh tokens

# Access protected resource
curl -X GET http://localhost:8601/users \
  -H "Authorization: Bearer [jwt-token]"
```

#### **3. Queue Management Workflow**
```bash
# Get current queue statistics
curl http://localhost:8601/queue/stats

# Get next patient in queue
curl http://localhost:8601/queue/next

# Update patient status
curl -X PATCH http://localhost:8601/queue/PQ-20240120-001/status \
  -H "Content-Type: application/json" \
  -d '{"status": "IN_PROGRESS"}'
```

## 🧪 Testing & Quality

### **Testing Strategy**
- **✅ Unit Tests**: 100% coverage requirement untuk semua services
- **✅ Integration Tests**: Cross-service communication via RabbitMQ
- **✅ E2E Tests**: Complete healthcare workflow testing
- **✅ Performance Tests**: Load testing dengan realistic scenarios
- **✅ Security Tests**: Authentication, authorization, input validation

### **Quality Metrics**
```bash
# Run tests untuk all services
./scripts/test-all-services.sh

# Coverage report
npm run test:cov  # Per service
python -m pytest --cov=. # OCR Engine

# Performance benchmarks
./scripts/performance-test.sh
```

### **CI/CD Pipeline**
```yaml
# Automated pipeline untuk each service:
✅ Code Quality Checks (ESLint, Prettier, Flake8)
✅ Unit & Integration Testing
✅ Security Vulnerability Scanning
✅ Docker Image Building & Scanning
✅ Multi-environment Deployment
✅ Performance Testing
✅ Health Check Validation
```

## 📊 Platform Capabilities

### 🏥 **Healthcare Digital Transformation**

#### **Before MediQ (Traditional Process)**
```
❌ Manual form filling (10-15 minutes)
❌ Paper-based queue system
❌ No wait time transparency  
❌ Manual data entry errors
❌ No real-time analytics
❌ Limited scalability
```

#### **After MediQ (Digital Process)**
```
✅ KTP scan + auto-fill (2-3 minutes)
✅ Digital queue dengan prioritization
✅ Real-time wait time estimates
✅ 95%+ data accuracy dengan ML
✅ Live analytics dashboard
✅ Auto-scaling infrastructure
```

### 📈 **Performance Characteristics**

| Metric | Development | Production | Enterprise |
|--------|-------------|------------|------------|
| **Concurrent Users** | 50+ | 500+ | 5000+ |
| **Response Time** | <300ms | <200ms | <100ms |
| **KTP Processing** | 3-5s | 2-4s | 1-3s |
| **Queue Updates** | Real-time | Real-time | Real-time |
| **Availability** | 99% | 99.9% | 99.99% |
| **Auto-scaling** | Manual | 2-10 pods | 2-50 pods |

### 🔐 **Security & Compliance**

#### **Data Protection**
- **🔒 Encryption**: Data encryption at rest dan in transit
- **🛡️ PII Handling**: Secure personal information processing
- **📋 Audit Trail**: Comprehensive logging untuk compliance
- **🔄 Data Retention**: Configurable retention policies

#### **Access Control**
- **🎫 JWT Authentication**: Stateless token-based auth
- **👥 Role-Based Access**: PASIEN/OPERATOR/ADMIN_FASKES roles
- **🔐 Multi-Factor Auth**: Planned untuk sensitive operations
- **🚨 Session Security**: Automatic timeout dan token rotation

## 🛠️ Technology Stack

### **Backend Services (NestJS)**
```typescript
// Modern TypeScript framework dengan:
- Dependency Injection
- Decorators & Metadata
- Built-in Validation
- Swagger Integration
- Microservices Support
- Enterprise Patterns
```

### **Machine Learning (Python)**
```python
# Advanced ML pipeline dengan:
- YOLO v8 untuk document detection
- EasyOCR untuk text recognition  
- OpenCV untuk image processing
- NumPy untuk numerical operations
- GPU acceleration support
```

### **Infrastructure & DevOps**
```yaml
# Production-ready stack:
- Docker: Multi-stage builds
- Kubernetes: Auto-scaling orchestration
- GitHub Actions: CI/CD automation
- Prometheus/Grafana: Monitoring
- RabbitMQ: Async messaging
- MySQL/Redis: Data persistence & caching
```

## 📋 Service Documentation

### 📖 **Individual Service READMEs**

| Service | Repository | Documentation |
|---------|------------|---------------|
| **🚪 API Gateway** | [MediQ-Backend-API-Gateway](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-API-Gateway) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-API-Gateway/blob/main/README.md) |
| **👤 User Service** | [MediQ-Backend-User-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-User-Service) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-User-Service/blob/main/README.md) |
| **📷 OCR Service** | [MediQ-Backend-OCR-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Service) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Service/blob/main/README.md) |
| **🤖 OCR Engine** | [MediQ-Backend-OCR-Engine-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Engine-Service) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-OCR-Engine-Service/blob/main/README.md) |
| **🏥 Patient Queue** | [MediQ-Backend-Patient-Queue-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Patient-Queue-Service) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Patient-Queue-Service/blob/main/README.md) |
| **🏢 Institution** | [MediQ-Backend-Institution-Service](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Institution-Service) | [README.md](https://github.com/MediQ-Compfest-17-SEA/MediQ-Backend-Institution-Service/blob/main/README.md) |

### 📚 **Platform Documentation**

| Document | Description | Link |
|----------|-------------|------|
| **Development Guide** | Build commands, testing, architecture | [AGENT.md](AGENT.md) |
| **Architecture Guide** | System design, communication patterns | [microservices-architecture.md](microservices-architecture.md) |
| **Deployment Guide** | Production deployment procedures | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) |
| **Kubernetes Guide** | K8s deployment, scaling, monitoring | [KUBERNETES_DEPLOYMENT_GUIDE.md](KUBERNETES_DEPLOYMENT_GUIDE.md) |
| **Testing Guide** | Testing strategy, coverage requirements | [TESTING_DOCUMENTATION.md](TESTING_DOCUMENTATION.md) |
| **Infrastructure Guide** | Infrastructure setup dan optimization | [INFRASTRUCTURE_GUIDE.md](INFRASTRUCTURE_GUIDE.md) |

## 🎭 Use Cases & Scenarios

### 🏥 **Scenario 1: Rumah Sakit Besar**
```
👥 1000+ patients per day
🏢 Multiple departments (Poli, UGD, Radiologi)
📊 Real-time dashboard untuk management
⚡ Auto-scaling untuk peak hours
```

### 🏪 **Scenario 2: Klinik Praktik Umum**
```
👥 100+ patients per day  
🏢 Basic services (Poli Umum, Apotek)
📱 Simple mobile interface
💰 Cost-effective deployment
```

### 🏛️ **Scenario 3: Puskesmas**
```
👥 50+ patients per day
🏢 Community healthcare services
📊 Basic analytics untuk reporting
🌐 Government integration ready
```

## 📊 Monitoring & Analytics

### **Real-time Dashboards**
- **📈 Queue Analytics**: Wait times, patient flow, peak hours
- **👥 User Statistics**: Registration trends, demographics
- **🏥 Facility Performance**: Service utilization, efficiency metrics
- **🤖 OCR Performance**: Processing accuracy, speed, error rates

### **Management Insights**
- **📊 Daily Reports**: Patient counts, service utilization
- **📈 Trend Analysis**: Weekly/monthly performance trends
- **⚠️ Alert System**: Queue backlogs, system performance issues
- **💡 Optimization Recommendations**: Data-driven improvement suggestions

## 🔧 Development & Maintenance

### **Command Reference**
```bash
# Development
./scripts/setup-development.sh     # Setup development environment
./scripts/start-all-services.sh    # Start all services
./scripts/stop-all-services.sh     # Stop all services

# Testing
./scripts/test-all-services.sh     # Run tests untuk all services
./scripts/integration-tests.sh     # Cross-service integration tests
./scripts/performance-tests.sh     # Performance benchmarking

# Deployment
./scripts/deploy-staging.sh        # Deploy to staging
./scripts/deploy-production.sh     # Deploy to production
./scripts/rollback.sh [service]     # Rollback specific service

# Monitoring
./scripts/health-check-all.sh      # Check all service health
./scripts/view-logs.sh [service]    # View service logs
./scripts/metrics-report.sh        # Generate metrics report
```

### **Development Workflow**
1. **🔄 Service Development**: Independent development per service
2. **🧪 Testing**: Comprehensive testing dengan 100% coverage
3. **📋 Integration**: Cross-service integration testing
4. **🚀 Deployment**: Automated CI/CD deployment
5. **📊 Monitoring**: Real-time monitoring dan alerting

## 🌍 Deployment Options

### **🐳 Development (Docker Compose)**
```bash
# Quick start untuk development
docker-compose up -d

# Services available immediately
✅ All services running di localhost
✅ Swagger documentation accessible
✅ Database dan infrastructure ready
```

### **☸️ Production (Kubernetes)**
```bash
# Enterprise deployment
kubectl apply -f k8s/

# Features:
✅ Auto-scaling berdasarkan load
✅ Rolling deployments
✅ Health monitoring
✅ Resource optimization
✅ Security policies
✅ Backup dan disaster recovery
```

### **☁️ Cloud Deployment**
- **AWS**: EKS + RDS + ElastiCache + ALB
- **Google Cloud**: GKE + Cloud SQL + Memorystore + Cloud Load Balancing
- **Azure**: AKS + Azure Database + Azure Cache + Application Gateway
- **Multi-Cloud**: Terraform modules untuk multi-cloud deployment

## 🔮 Roadmap & Future Enhancements

### **🎯 Phase 1: Core Platform** ✅ **COMPLETED**
- ✅ **6 Microservices** dengan comprehensive features
- ✅ **ML-powered OCR** untuk KTP processing
- ✅ **Digital queue management** dengan prioritization
- ✅ **Enterprise security** dengan JWT dan RBAC
- ✅ **Production deployment** ready

### **🚀 Phase 2: Advanced Features** 🔄 **IN PLANNING**
- 📱 **Mobile Applications**: Patient dan staff mobile apps
- 💬 **Real-time Notifications**: WebSocket untuk live updates
- 🔔 **Push Notifications**: Mobile push untuk queue updates
- 📊 **Advanced Analytics**: ML-powered queue prediction
- 💳 **Payment Integration**: Digital payment processing

### **🌟 Phase 3: Enterprise Integration** 🔮 **FUTURE**
- 🏥 **EMR Integration**: Electronic Medical Records connectivity
- 📋 **Appointment Scheduling**: Advanced booking system
- 🌐 **Government Integration**: BPJS, Kemenkes APIs
- 🏢 **Multi-tenant Architecture**: Support multiple healthcare networks
- 🤖 **AI Diagnostics**: ML-assisted diagnostic recommendations

### **🔬 Phase 4: Research & Innovation** 💭 **RESEARCH**
- 🧬 **Biometric Integration**: Fingerprint, face recognition
- 🗣️ **Voice Interface**: Voice-activated queue management
- 🎯 **Predictive Analytics**: Patient flow prediction
- 🌍 **International Expansion**: Support untuk different ID documents

## 🤝 Contributing

### **🔧 Development Guidelines**
1. **Fork** service repository yang ingin dimodifikasi
2. **Follow** service-specific guidelines dalam README.md
3. **Write tests** dengan 100% coverage requirement
4. **Update documentation** untuk new features
5. **Submit PR** dengan detailed description dan test results

### **📋 Contribution Areas**
- **🐛 Bug Fixes**: Issue resolution dan stability improvements
- **✨ Feature Development**: New capabilities dan enhancements
- **📚 Documentation**: Improve documentation quality
- **🧪 Testing**: Enhance test coverage dan scenarios
- **🚀 Performance**: Optimization dan scalability improvements
- **🔒 Security**: Security enhancements dan vulnerability fixes

### **👥 Community**
- **💬 Discussions**: GitHub Discussions untuk feature requests
- **🐛 Issues**: Bug reports dengan detailed reproduction steps
- **📋 Project Board**: Track development progress
- **📖 Wiki**: Community-maintained documentation

## 📞 Support & Contact

### **📧 Technical Contact**
- **👨‍💻 Lead Developer**: Alif Nurhidayat (KillerKing93)
- **📧 Email**: alifnurhidayatwork@gmail.com
- **🏢 Organization**: MediQ-Compfest-17-SEA

### **🆘 Support Channels**
- **📚 Documentation**: Comprehensive guides dalam repositories
- **🐛 GitHub Issues**: Bug reports dan feature requests
- **💬 GitHub Discussions**: Community support dan Q&A
- **📧 Direct Contact**: Commercial support dan licensing

### **🤝 Community Guidelines**
- **🤝 Professional Collaboration**: Respectful dan constructive communication
- **📋 Code of Conduct**: Professional standards untuk all interactions
- **🔄 Contribution Process**: Clear guidelines untuk contributions
- **⚡ Response Time**: Community support dengan reasonable response time

## 📄 License

**Dual License**: Apache-2.0 + Commercial License (Royalty)

**Copyright (c) 2025 Alif Nurhidayat (KillerKing93)**

### **📖 Open Source License**
Licensed under the **Apache License, Version 2.0** (the "License");  
you may not use this file except in compliance with the License.  
You may obtain a copy of the License at:  
**[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)**

### **💼 Commercial License**
For **commercial use**, **proprietary modifications**, or usage in **closed-source projects**,  
a commercial license is required.  

**📧 Commercial Licensing Contact**: alifnurhidayatwork@gmail.com

### **⚖️ License Terms**
Unless required by applicable law or agreed to in writing, software  
distributed under the License is distributed on an **"AS IS" BASIS**,  
**WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND**, either express or implied.  
See the License for the specific language governing permissions and  
limitations under the License.

---

## 🎯 Quick Navigation

<p align="center">
  <a href="microservices-architecture.md">📐 Architecture</a> •
  <a href="DEPLOYMENT_GUIDE.md">🚀 Deployment</a> •
  <a href="TESTING_DOCUMENTATION.md">🧪 Testing</a> •
  <a href="KUBERNETES_DEPLOYMENT_GUIDE.md">☸️ Kubernetes</a> •
  <a href="INFRASTRUCTURE_GUIDE.md">🏗️ Infrastructure</a>
</p>

---

<p align="center">
  <strong>🏥 MediQ Backend - Transforming Indonesian Healthcare Digital Experience</strong><br/>
  <em>Built with ❤️ untuk Indonesian Healthcare System</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Production_Ready-brightgreen?style=for-the-badge" alt="Production Ready" />
  <img src="https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/License-Apache_2.0_+_Commercial-orange?style=for-the-badge" alt="License" />
</p>
