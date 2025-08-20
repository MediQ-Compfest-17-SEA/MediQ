# MediQ Microservices Architecture

## 📐 Arsitektur Sistem

```
                                    ┌─────────────────┐
                                    │   Client App    │
                                    │   (Frontend)    │
                                    └─────────────────┘
                                             │ HTTP
                                             ▼
                              ┌─────────────────────────────┐
                              │      API Gateway            │
                              │      (Port 3001)            │
                              │  • Circuit Breaker          │
                              │  • Rate Limiting            │
                              │  • Request Routing          │
                              └─────────────────────────────┘
                                             │
                                ┌────────────┼────────────┐
                                │ RabbitMQ   │ RabbitMQ   │ RabbitMQ
                                ▼            ▼            ▼
                    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
                    │  User Service   │ │  OCR Service    │ │ Patient Queue   │
                    │  (Port 3000)    │ │  (Port 3002)    │ │ Service         │
                    │                 │ │                 │ │ (Port 3003)     │
                    └─────────────────┘ └─────────────────┘ └─────────────────┘
                             │                   │                   │
                             ▼                   │                   ▼
                    ┌─────────────────┐         │          ┌─────────────────┐
                    │  MySQL Database │         │          │  Redis Cache    │
                    │  (User Data)    │         │          │  (Queue Data)   │
                    └─────────────────┘         │          └─────────────────┘
                                                ▼
                                      ┌─────────────────┐
                                      │ External OCR    │
                                      │ API Service     │
                                      │ (KTP Processing)│
                                      └─────────────────┘

                    ┌──────────────── Direct RabbitMQ Communication ─────────────────┐
                    │                                                                  │
                    ▼                                                                  ▼
            OCR Service ◄─────────────── user.create ──────────────► User Service
                    │                                                         │
                    ▼                                                         ▼
            Queue Service ◄───────── queue.add-patient ────────────► User Service
```

## 🔄 Message Flow & Communication Patterns

### 1. Hybrid Communication Architecture

#### External Communication (Client → API Gateway)
```
Client App ─HTTP─► API Gateway ─RabbitMQ─► Services
```

#### Internal Communication (Service ↔ Service)
```
OCR Service ─RabbitMQ─► User Service (Direct)
OCR Service ─RabbitMQ─► Queue Service (Direct)
User Service ─RabbitMQ─► Queue Service (Direct)
```

### 2. Complete Request Flows

#### User Registration via OCR
```
1. Client → API Gateway → OCR Service (KTP Processing)
2. OCR Service → External OCR API (Image Analysis)
3. OCR Service → User Service (user.create-from-ocr)
4. User Service → Database (Store User)
5. User Service → Queue Service (queue.add-patient)
6. Queue Service → Redis (Update Queue)
7. Response: API Gateway → Client
```

#### Authentication Flow
```
1. Client → API Gateway (auth.login)
2. API Gateway → User Service (auth.validate)
3. User Service → Database (Verify Credentials)
4. User Service → JWT Generation
5. Response: API Gateway → Client (Tokens)
```

#### Queue Management Flow
```
1. Client → API Gateway (queue.add)
2. API Gateway → Queue Service (queue.add-patient)
3. Queue Service → Redis (Store Queue Data)
4. Queue Service → WebSocket (Real-time Updates)
5. Response: API Gateway → Client
```

### 3. Message Patterns by Service

#### User Service Messages
```
HTTP POST /users               → user.create
HTTP POST /users/create-from-ocr → user.create-from-ocr
HTTP GET /users/check-nik/:nik → user.check-nik  
HTTP GET /users/profile        → user.profile
HTTP GET /users                → user.findAll
HTTP PATCH /users/:id/role     → user.updateRole
HTTP DELETE /users/:id         → user.delete
```

#### OCR Service Messages  
```
HTTP POST /ocr/process-ktp     → ocr.process-ktp
HTTP GET /ocr/result/:id       → ocr.get-result
HTTP GET /ocr/status/:id       → ocr.get-status
Internal: ocr.user-created     → Notify other services
```

#### Queue Service Messages
```
HTTP POST /queue/add           → queue.add-patient
HTTP GET /queue/status/:userId → queue.get-status
HTTP PATCH /queue/call-next    → queue.call-next
HTTP PATCH /queue/:id/complete → queue.complete
HTTP DELETE /queue/:id         → queue.cancel
HTTP GET /queue/statistics     → queue.get-statistics
```

#### Auth Service Messages
```
HTTP POST /auth/login/admin    → auth.login.admin
HTTP POST /auth/login/user     → auth.login.user
HTTP GET /auth/refresh         → auth.refresh
HTTP GET /auth/logout          → auth.logout
```

#### Health Check Messages
```
HTTP GET /                     → health.check
HTTP GET /health               → health.detailed
```

## 🔐 Security Layer

### Authentication Flow
```
1. Client → API Gateway: Login request
2. API Gateway → User Service (RabbitMQ): Validate credentials  
3. User Service → API Gateway: JWT tokens
4. API Gateway → Client: JWT tokens
5. Subsequent requests: JWT in Authorization header
```

### Authorization Guards
- **JWT Guard**: Validates access token
- **Refresh Guard**: Validates refresh token  
- **Roles Guard**: Checks user permissions (PASIEN, OPERATOR, ADMIN_FASKES)

## ⚡ Synchronization & Consistency

### 1. Request-Response Pattern
```typescript
// API Gateway - Synchronous communication
const result = await this.messagingService.send('user.create', userData);
```

### 2. Error Handling & Retry Logic
```typescript
// Automatic retry with exponential backoff
@Retryable({
  attempts: 3,
  delay: 1000,
  backoff: { type: 'exponential' }
})
```

### 3. Circuit Breaker Pattern
```typescript
// Fail fast when User Service is down
if (failureRate > 50% && requests > 10) {
  throw new ServiceUnavailableException('User Service temporarily unavailable');
}
```

### 4. Timeout Management
```typescript
// 5 second timeout for all RabbitMQ calls
const response = await this.client.send(pattern, data).pipe(
  timeout(5000),
  catchError(this.handleTimeout)
).toPromise();
```

## 📊 Monitoring & Observability

### Health Checks
- **API Gateway**: `GET /` → Returns gateway status
- **User Service**: `health.check` → Returns service status
- **RabbitMQ**: Connection status monitoring
- **Database**: Prisma connection health

### Logging Strategy
```typescript
// Request/Response logging
@UseInterceptors(LoggingInterceptor)
export class UsersController {
  // Logs: request ID, method, payload, response time, errors
}
```

## 🔧 Service Details

### OCR Service (Port 3002)
- **Purpose**: KTP image processing and data extraction
- **External Dependencies**: OCR CNN Engine API 
- **Communication**: 
  - Inbound: API Gateway → RabbitMQ
  - Outbound: User Service, Queue Service (Direct RabbitMQ)
- **File Handling**: Multipart upload, image validation, temporary storage
- **Processing**: Asynchronous with status tracking

### User Service (Port 3000)  
- **Purpose**: User management, authentication, profile data
- **Database**: MySQL with Prisma ORM
- **Communication**: API Gateway + Direct service-to-service
- **Features**: JWT authentication, role-based access, password management

### Patient Queue Service (Port 3003)
- **Purpose**: Queue management, real-time updates, statistics
- **Cache**: Redis for queue state and performance
- **Communication**: API Gateway + Direct service-to-service  
- **Features**: Priority queues, WebSocket updates, analytics

### API Gateway (Port 3001)
- **Purpose**: Entry point, routing, resilience patterns
- **Features**: Circuit breaker, rate limiting, request/response transformation
- **Security**: JWT validation, request sanitization, error handling

## 🔄 Hybrid Communication Benefits

### External HTTP → RabbitMQ Pattern
- **Reliability**: Message persistence, acknowledgments, dead letter queues
- **Scalability**: Load balancing, horizontal scaling
- **Resilience**: Circuit breakers, retries, timeouts

### Internal RabbitMQ Direct Pattern  
- **Performance**: Lower latency, reduced network hops
- **Consistency**: Event-driven architecture, eventual consistency
- **Decoupling**: Services can evolve independently

## 🚀 Deployment Configuration

### Environment Variables

**API Gateway (.env)**:
```env
PORT=3001
RABBITMQ_URL=amqp://localhost:5672
USER_SERVICE_QUEUE=user_service_queue
OCR_SERVICE_QUEUE=ocr_service_queue
QUEUE_SERVICE_QUEUE=patient_queue_service_queue
JWT_SECRET=your-jwt-secret
TIMEOUT_MS=5000
RETRY_ATTEMPTS=3
CIRCUIT_BREAKER_THRESHOLD=5
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60000
```

**User Service (.env)**:
```env  
PORT=3000
DATABASE_URL=mysql://user:password@localhost:3306/mediq_users
RABBITMQ_URL=amqp://localhost:5672
JWT_SECRET=your-jwt-secret
JWT_REFRESH_SECRET=your-refresh-secret
OCR_SERVICE_QUEUE=ocr_service_queue
QUEUE_SERVICE_QUEUE=patient_queue_service_queue
```

**OCR Service (.env)**:
```env
PORT=3002
RABBITMQ_URL=amqp://localhost:5672
OCR_API_URL=http://localhost:5000
OCR_API_TIMEOUT=30000
USER_SERVICE_QUEUE=user_service_queue
QUEUE_SERVICE_QUEUE=patient_queue_service_queue
UPLOAD_MAX_SIZE=5242880
ALLOWED_FILE_TYPES=jpg,jpeg,png,pdf
```

**Patient Queue Service (.env)**:
```env
PORT=3003
RABBITMQ_URL=amqp://localhost:5672
REDIS_URL=redis://localhost:6379
USER_SERVICE_QUEUE=user_service_queue
WEBSOCKET_PORT=3004
QUEUE_CLEANUP_INTERVAL=300000
STATISTICS_RETENTION_DAYS=30
```

### Production Docker Compose
```yaml
version: '3.8'
networks:
  mediq-network:
    driver: bridge

services:
  # Infrastructure Services
  rabbitmq:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: mediq
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
      RABBITMQ_DEFAULT_VHOST: mediq
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "status"]
      timeout: 30s
      retries: 5
      interval: 10s
      
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: mediq_users
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER: mediq
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      timeout: 3s
      retries: 5

  # OCR Engine (Python Flask)
  ocr-engine:
    build: ./e-KTP-OCR-CNN
    ports:
      - "5000:5000"
    volumes:
      - ./e-KTP-OCR-CNN/models:/app/models
      - ocr_temp:/tmp/ocr
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      timeout: 10s
      retries: 5
      
  # Microservices
  user-service:
    build: ./MediQ-Backend-User-Service
    environment:
      DATABASE_URL: mysql://mediq:${MYSQL_PASSWORD}@mysql:3306/mediq_users
      RABBITMQ_URL: amqp://mediq:${RABBITMQ_PASSWORD}@rabbitmq:5672/mediq
    ports:
      - "3000:3000"
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      timeout: 10s
      retries: 5

  ocr-service:
    build: ./MediQ-Backend-OCR-Service
    environment:
      RABBITMQ_URL: amqp://mediq:${RABBITMQ_PASSWORD}@rabbitmq:5672/mediq
      OCR_API_URL: http://ocr-engine:5000
    ports:
      - "3002:3002"
    depends_on:
      rabbitmq:
        condition: service_healthy
      ocr-engine:
        condition: service_healthy
    volumes:
      - ocr_uploads:/app/uploads
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/health"]
      timeout: 10s
      retries: 5

  queue-service:
    build: ./MediQ-Backend-Patient-Queue-Service
    environment:
      RABBITMQ_URL: amqp://mediq:${RABBITMQ_PASSWORD}@rabbitmq:5672/mediq
      REDIS_URL: redis://redis:6379
    ports:
      - "3003:3003"
      - "3004:3004"  # WebSocket port
    depends_on:
      rabbitmq:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3003/health"]
      timeout: 10s
      retries: 5
      
  api-gateway:
    build: ./MediQ-Backend-API-Gateway  
    environment:
      RABBITMQ_URL: amqp://mediq:${RABBITMQ_PASSWORD}@rabbitmq:5672/mediq
      USER_SERVICE_URL: http://user-service:3000
      OCR_SERVICE_URL: http://ocr-service:3002
      QUEUE_SERVICE_URL: http://queue-service:3003
    ports:
      - "3001:3001"
    depends_on:
      rabbitmq:
        condition: service_healthy
      user-service:
        condition: service_healthy
      ocr-service:
        condition: service_healthy
      queue-service:
        condition: service_healthy
    networks:
      - mediq-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      timeout: 10s
      retries: 5

  # Monitoring & Observability
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - mediq-network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3005:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - mediq-network

volumes:
  mysql_data:
  redis_data:
  rabbitmq_data:
  grafana_data:
  ocr_uploads:
  ocr_temp:
```

## 🧪 Integration Testing Strategy

### Test Environment Setup
```bash
# Start test infrastructure
docker-compose -f docker-compose.test.yml up -d

# Run integration tests for all services
npm run test:integration

# Run specific integration test suite
npx jest test/integration/auth-flow.integration.spec.ts
npx jest test/integration/ocr-workflow.integration.spec.ts
npx jest test/integration/queue-management.integration.spec.ts
```

### Integration Test Coverage

#### Cross-Service Communication Tests
- **Auth Flow**: API Gateway ↔ User Service authentication workflow
- **OCR Workflow**: Complete KTP processing from upload to user creation
- **Queue Management**: Redis operations, queue state management
- **RabbitMQ Communication**: Message reliability, retry logic, dead letters
- **API Gateway Proxy**: Request routing, error handling, circuit breaker

#### Database Integration Tests
- **User Service**: Full CRUD operations with MySQL
- **Queue Service**: Redis cache operations and persistence  
- **OCR Service**: File upload, processing status tracking
- **Transaction Management**: Rollback scenarios, consistency

#### Performance & Resilience Tests
- **Concurrent Requests**: Load testing, connection pooling
- **Failure Scenarios**: Service unavailability, network timeouts
- **Message Queue Reliability**: Redelivery, acknowledgments
- **Circuit Breaker**: Failure detection, recovery

### Test Data Management
```bash
# Setup test fixtures
test/fixtures/
├── sample-ktp.jpg          # Valid KTP image for OCR testing
├── invalid-file.txt        # Invalid file type testing
├── large-image.jpg         # File size limit testing
└── malicious-script.php    # Security testing

# Test database isolation
- Separate test database: mediq_integration_test
- Redis test database: db=1
- RabbitMQ test vhost: mediq-test
```

### Continuous Integration
```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests
on: [push, pull_request]
jobs:
  integration-tests:
    runs-on: ubuntu-latest
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: testpass
          MYSQL_DATABASE: mediq_integration_test
        ports: ['3307:3306']
      redis:
        image: redis:7-alpine
        ports: ['6380:6379']
      rabbitmq:
        image: rabbitmq:3-management
        ports: ['5673:5672']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run test:integration
        env:
          TEST_DATABASE_URL: mysql://root:testpass@localhost:3307/mediq_integration_test
          REDIS_URL: redis://localhost:6380
          RABBITMQ_URL: amqp://localhost:5673
```

## 🔧 Development Commands

### Local Development
```bash
# Start infrastructure services
docker-compose up -d rabbitmq mysql redis ocr-engine

# Start User Service  
cd MediQ-Backend-User-Service
npm run start:dev

# Start OCR Service
cd MediQ-Backend-OCR-Service
npm run start:dev

# Start Queue Service
cd MediQ-Backend-Patient-Queue-Service
npm run start:dev

# Start API Gateway
cd MediQ-Backend-API-Gateway
npm run start:dev
```

### Testing Commands
```bash
# Unit tests (each service)
npm test

# Integration tests
npm run test:integration

# E2E tests
npm run test:e2e

# Coverage reports
npm run test:cov

# Watch mode for development
npm run test:watch
```

### API Testing
```bash
# Health checks
curl http://localhost:3001/health
curl http://localhost:3000/health  # User Service
curl http://localhost:3002/health  # OCR Service
curl http://localhost:3003/health  # Queue Service

# Test OCR workflow
curl -X POST http://localhost:3001/ocr/process-ktp \
  -F "ktp_image=@test/fixtures/sample-ktp.jpg"

# Test queue operations
curl -X POST http://localhost:3001/queue/add \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user123"}'

# Test authentication
curl -X POST http://localhost:3001/auth/login/admin \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@mediq.com", "password": "admin123"}'
```

## 📈 Performance Considerations

### Connection Pooling
- **RabbitMQ**: Persistent connections with connection pooling
- **MySQL**: Prisma connection pooling (pool size: 10)

### Caching Strategy  
- **JWT**: In-memory cache for token validation
- **User data**: Redis cache in Patient Queue Service
- **Connection cache**: RabbitMQ connection reuse

### Load Balancing
- **API Gateway**: Can be horizontally scaled
- **User Service**: Stateless, multiple instances supported
- **RabbitMQ**: Queue-based load distribution

## 🔮 Future Enhancements

### 1. Event Sourcing
- Store all user events for audit trail
- Enable event replay for debugging

### 2. CQRS Pattern  
- Separate read/write models
- Optimize query performance

### 3. Saga Pattern
- Distributed transaction management
- Complex workflow orchestration

### 4. Service Mesh
- Istio/Linkerd integration
- Advanced traffic management
