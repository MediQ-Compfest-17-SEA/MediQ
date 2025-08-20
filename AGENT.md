# MediQ Backend - Microservices Architecture

## Build/Test/Lint Commands
Navigate to each service directory and run:
- `npm run build` - Build TypeScript to dist/
- `npm run test` - Run unit tests with Jest (100% coverage required)
- `npm run test:watch` - Run tests in watch mode
- `npm run test:e2e` - Run end-to-end tests
- `npm run test:cov` - Run tests with coverage report
- `npm run test:integration` - Run integration tests
- `npm run lint` - ESLint with auto-fix
- `npm run format` - Prettier formatting
- **Single test**: `npx jest --testNamePattern="specific test name"` or `npx jest path/to/test.spec.ts`

## CI/CD Commands
- `npm run ci:test` - Run all tests in CI environment
- `npm run ci:build` - Production build for CI/CD pipeline
- `npm run security:check` - Security vulnerability scanning
- `npm run docker:build` - Build Docker image
- `npm run docker:push` - Push to container registry
- **GitHub Actions**: Auto-triggered on push to main/develop branches
- **Manual Deploy**: Use "Deploy All Services" workflow from Actions tab

## Kubernetes Commands
- `kubectl apply -f k8s/` - Deploy all services to cluster
- `kubectl get pods -l app=mediq` - Check service status
- `kubectl logs -f deployment/api-gateway` - Stream logs
- `kubectl scale deployment/api-gateway --replicas=3` - Scale services
- `kubectl rollout status deployment/user-service` - Check rollout status
- `kubectl rollout undo deployment/ocr-service` - Rollback deployment
- `helm install mediq ./k8s/helm/` - Deploy with Helm chart
- `helm upgrade mediq ./k8s/helm/` - Upgrade services

## Service Architecture & Ports
- **API Gateway** (Port 8601): Centralized HTTP entry point with advanced synchronization
- **User Service** (Port 8602): User management, authentication, JWT tokens
- **OCR Service** (Port 8603): KTP processing with external OCR API integration
- **OCR Engine Service** (Port 8604): External OCR engine for KTP processing
- **Patient Queue Service** (Port 8605): Queue management with Redis cache
- **Institution Service** (Port 8606): Healthcare institution and service management

## Repository Structure (Updated)
Each service now has its own repository with:
- `.github/workflows/ci-cd.yml` - Service-specific CI/CD pipeline
- `k8s/` - Kubernetes manifests (deployment.yaml, service.yaml, configmap.yaml, hpa.yaml)
- `Dockerfile` - Service-specific Docker configuration
- `docker-compose.yml` - Local development setup with dependencies

Root repository contains:
- `k8s/shared/` - Shared infrastructure (MySQL, Redis, RabbitMQ, Monitoring)
- `k8s/ingress.yaml` - Ingress configuration
- `docker-compose.infrastructure.yml` - Shared infrastructure for development
- `test/` - Cross-service integration tests
- High-level documentation and deployment scripts

## Communication Patterns
- **External**: Client → API Gateway (HTTP) → Services (RabbitMQ)
- **Internal**: Service ↔ Service (Direct RabbitMQ)
- **Message Patterns**: 'service.operation' format (e.g., 'user.create', 'queue.add-to-queue')
- **Database**: MySQL with Prisma ORM (each service has its own schema)
- **Message Queue**: RabbitMQ with queues: user_service_queue, ocr_service_queue, patient_queue_service_queue, institution_service_queue
- **Cache**: Redis (Patient Queue Service)

## Authentication & Security
- **JWT**: Access tokens (15min) + refresh tokens (7 days)
- **Roles**: PASIEN, OPERATOR, ADMIN_FASKES with @Roles decorator
- **Guards**: JwtAuthGuard, RolesGuard, RefreshTokenGuard
- **API Gateway**: Circuit breaker, retry logic, idempotency, rate limiting

## API Documentation
- **API Gateway**: Swagger at `http://localhost:8601/api/docs`
- **User Service**: Swagger at `http://localhost:8602/api/docs` 
- **OCR Service**: Swagger at `http://localhost:8603/api/docs`
- **OCR Engine Service**: Swagger at `http://localhost:8604/api/docs`
- **Patient Queue Service**: Swagger at `http://localhost:8605/api/docs`
- **Institution Service**: Swagger at `http://localhost:8606/api/docs`

## Testing Strategy
- **Unit Tests**: 100% coverage requirement with mocks
- **Integration Tests**: Service-to-service communication via RabbitMQ
- **E2E Tests**: Full workflow testing through API Gateway
- **Mock Strategy**: Mock external dependencies (OCR API, databases)
- **Test Database**: Separate test database for integration tests

## Code Style & Conventions
- **Prettier**: Single quotes, trailing commas (`{ "singleQuote": true, "trailingComma": "all" }`)
- **ESLint**: TypeScript recommended with `@typescript-eslint/no-explicit-any: off`
- **Imports**: Absolute imports using `src/` path mapping
- **DTOs**: Use class-validator decorators and ApiProperty for Swagger
- **Services**: Injectable classes, dependency injection pattern
- **Tests**: Jest with `.spec.ts` suffix, comprehensive mock services
- **Database**: Prisma models with uuid() primary keys, DateTime fields
- **Error Handling**: NestJS ValidationPipe, RpcExceptionFilter, custom exception handling

## Environment Variables
Each service requires:
- `PORT` - Service port
- `RABBITMQ_URL` - Message broker connection
- `DATABASE_URL` - MySQL connection (User/Queue services)
- `JWT_SECRET` & `JWT_REFRESH_SECRET` - Authentication
- `OCR_API_URL` - External OCR API (OCR service only)
