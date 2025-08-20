# MediQ Integration Testing Guide

## 📋 Overview

Comprehensive integration testing suite for MediQ microservices architecture, covering all inter-service communication, database operations, and external dependencies.

## 🏗️ Test Architecture

```
Integration Test Environment
├── Test Infrastructure (Docker)
│   ├── MySQL (Port 3307) - Test database
│   ├── Redis (Port 6380) - Test cache  
│   ├── RabbitMQ (Port 5673) - Test message broker
│   └── OCR Engine (Port 5001) - Mock external API
├── Test Suites
│   ├── auth-flow.integration.spec.ts - Authentication workflows
│   ├── ocr-workflow.integration.spec.ts - KTP processing end-to-end
│   ├── user-registration.integration.spec.ts - Database CRUD operations
│   ├── queue-management.integration.spec.ts - Redis cache operations
│   ├── api-gateway-proxy.integration.spec.ts - Gateway functionality
│   └── rabbitmq-communication.integration.spec.ts - Message reliability
└── Test Fixtures
    ├── sample-ktp.jpg - Valid test image
    ├── invalid-file.txt - Invalid format test
    └── test data factories
```

## 🚀 Quick Start

### 1. Start Test Infrastructure
```bash
# Start all required services
docker-compose -f docker-compose.test.yml up -d

# Verify services are ready
docker-compose -f docker-compose.test.yml ps
```

### 2. Run Integration Tests
```bash
# All integration tests
npm run test:integration

# Specific test suite
npx jest test/integration/auth-flow.integration.spec.ts

# Watch mode for development
npx jest test/integration --watch

# Coverage report
npx jest test/integration --coverage
```

### 3. Cleanup
```bash
# Stop and remove test infrastructure
docker-compose -f docker-compose.test.yml down -v
```

## 🧪 Test Suites Detail

### Authentication Flow Tests
**File**: `auth-flow.integration.spec.ts`
- Admin login workflow via API Gateway
- User login with role validation  
- JWT token refresh mechanism
- Logout and token invalidation
- Role-based access control enforcement
- RabbitMQ communication reliability

### OCR Workflow Tests
**File**: `ocr-workflow.integration.spec.ts`
- KTP image upload and processing
- External OCR API integration
- User account creation from OCR data
- Automatic queue enrollment
- File validation and security
- Error handling for failed processing

### User Registration Tests
**File**: `user-registration.integration.spec.ts`
- Complete CRUD operations with MySQL
- Database constraint enforcement
- Transaction rollback scenarios
- Password encryption and validation
- Connection failure handling
- Data consistency verification

### Queue Management Tests  
**File**: `queue-management.integration.spec.ts`
- Redis cache operations
- Queue position management
- Priority queue handling
- Real-time updates via pub/sub
- Statistics calculation
- Queue transfer between facilities

### API Gateway Proxy Tests
**File**: `api-gateway-proxy.integration.spec.ts`
- Request routing to services
- Circuit breaker functionality
- Retry logic with exponential backoff
- Timeout handling
- Rate limiting enforcement
- Security validation

### RabbitMQ Communication Tests
**File**: `rabbitmq-communication.integration.spec.ts`
- Message delivery reliability
- Dead letter queue handling
- Request-response pattern
- Publish-subscribe events
- Connection failure recovery
- Message priority handling

## 🔧 Configuration

### Environment Variables
```bash
# Test Database
TEST_DATABASE_URL=mysql://root:testpassword@localhost:3307/mediq_integration_test

# Test Redis
REDIS_HOST=localhost
REDIS_PORT=6380

# Test RabbitMQ
RABBITMQ_URL=amqp://testuser:testpassword@localhost:5673/test

# Test OCR API
OCR_API_URL=http://localhost:5001

# JWT Secrets
JWT_SECRET=test-jwt-secret
JWT_REFRESH_SECRET=test-refresh-secret
```

### Jest Configuration
**File**: `jest-integration.json`
```json
{
  "testEnvironment": "node",
  "testRegex": "integration.*\\.spec\\.ts$",
  "setupFilesAfterEnv": ["<rootDir>/setup-integration.ts"],
  "testTimeout": 60000,
  "maxWorkers": 1,
  "forceExit": true,
  "detectOpenHandles": true
}
```

## 🧰 Test Utilities

### Global Test Utils
Available in all test files via `testUtils`:

```typescript
// User management
const user = await testUtils.createTestUser(userData);

// Database cleanup
await testUtils.cleanupTestData();

// Message queue testing  
await testUtils.sendTestMessage('queue_name', data);
const message = await testUtils.waitForQueueMessage('queue_name');

// Test data generation
const nik = testUtils.generateTestNik();
const email = testUtils.generateTestEmail();
```

### Test Fixtures
Located in `test/fixtures/`:
- `sample-ktp.jpg` - Valid KTP image for OCR testing
- `invalid-file.txt` - Invalid file type for error testing
- `large-image.jpg` - Oversized file for limit testing
- `malicious-script.php` - Security validation testing

## 📊 Test Coverage Requirements

### Coverage Thresholds
- **Statements**: 100% (no uncovered lines)
- **Branches**: 100% (all conditional paths)
- **Functions**: 100% (all functions called)  
- **Lines**: 100% (every line executed)

### Integration Coverage Areas
✅ **Service Communication**
- API Gateway ↔ All Services
- Direct service-to-service messaging
- External API integration

✅ **Database Operations**
- CRUD operations across all entities
- Transaction management
- Connection pooling
- Failure recovery

✅ **Cache Operations**  
- Redis SET/GET/DELETE operations
- Queue state management
- Statistics aggregation
- Pub/sub messaging

✅ **Message Queue Reliability**
- Message persistence
- Acknowledgment handling
- Dead letter processing
- Connection recovery

✅ **Error Scenarios**
- Service unavailability
- Network timeouts
- Database failures
- Invalid inputs

✅ **Security Validation**
- JWT token validation
- Role-based access control
- Input sanitization
- File upload security

## 🐛 Debugging Integration Tests

### Common Issues

#### Database Connection Failures
```bash
# Check MySQL container status
docker-compose -f docker-compose.test.yml logs mysql-test

# Verify database creation
docker exec -it <mysql-container> mysql -u root -p -e "SHOW DATABASES;"
```

#### RabbitMQ Connection Issues  
```bash
# Check RabbitMQ status
docker-compose -f docker-compose.test.yml logs rabbitmq-test

# Access management UI
open http://localhost:15673
# Login: testuser / testpassword
```

#### Redis Connection Problems
```bash
# Test Redis connectivity
docker exec -it <redis-container> redis-cli ping

# Check Redis logs
docker-compose -f docker-compose.test.yml logs redis-test
```

### Test Debugging Commands
```bash
# Run single test with debug output
DEBUG=* npx jest test/integration/auth-flow.integration.spec.ts

# Run with verbose logging
npx jest test/integration --verbose --detectOpenHandles

# Run specific test case
npx jest test/integration -t "should complete admin login flow"

# Generate coverage report
npx jest test/integration --coverage --coverageReporters=html
open coverage/lcov-report/index.html
```

### Performance Monitoring
```bash
# Monitor test execution time
npm run test:integration -- --verbose --testTimeout=30000

# Profile memory usage  
node --max-old-space-size=4096 node_modules/.bin/jest test/integration

# Monitor resource usage during tests
docker stats
```

## 🔄 Continuous Integration

### GitHub Actions Workflow
```yaml
name: Integration Tests
on: 
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: testpassword
          MYSQL_DATABASE: mediq_integration_test
        ports: ['3307:3306']
        options: >-
          --health-cmd="mysqladmin ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
          
      redis:
        image: redis:7-alpine
        ports: ['6380:6379']
        options: >-
          --health-cmd="redis-cli ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3
          
      rabbitmq:
        image: rabbitmq:3-management
        ports: ['5673:5672', '15673:15672']
        env:
          RABBITMQ_DEFAULT_USER: testuser
          RABBITMQ_DEFAULT_PASS: testpassword
        options: >-
          --health-cmd="rabbitmq-diagnostics status"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=3

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Wait for services
        run: |
          timeout 300 bash -c 'until nc -z localhost 3307; do sleep 5; done'
          timeout 300 bash -c 'until nc -z localhost 6380; do sleep 5; done'
          timeout 300 bash -c 'until nc -z localhost 5673; do sleep 5; done'
          
      - name: Run integration tests
        run: npm run test:integration
        env:
          NODE_ENV: test
          TEST_DATABASE_URL: mysql://root:testpassword@localhost:3307/mediq_integration_test
          REDIS_HOST: localhost
          REDIS_PORT: 6380
          RABBITMQ_URL: amqp://testuser:testpassword@localhost:5673
          
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/integration/lcov.info
          flags: integration
          name: integration-tests
```

## 📈 Best Practices

### Test Organization
- **Isolated Tests**: Each test suite is independent
- **Parallel Execution**: Tests can run concurrently (with limitations)  
- **Deterministic**: Tests produce consistent results
- **Fast Feedback**: Critical paths tested first

### Data Management
- **Clean Slate**: Database reset before each test
- **Realistic Data**: Use production-like test data
- **Edge Cases**: Test boundary conditions
- **Error Scenarios**: Test failure modes

### Maintenance
- **Regular Updates**: Keep test data current
- **Performance Monitoring**: Track test execution time
- **Failure Analysis**: Investigate flaky tests immediately
- **Documentation**: Keep test documentation updated
