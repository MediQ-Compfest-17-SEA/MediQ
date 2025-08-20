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

## Service Architecture & Ports
- **API Gateway** (Port 3001): Centralized HTTP entry point with advanced synchronization
- **User Service** (Port 3000): User management, authentication, JWT tokens
- **Patient Queue Service** (Port 3003): Queue management with Redis cache
- **OCR Service** (Port 3002): KTP processing with external OCR API integration

## Communication Patterns
- **External**: Client → API Gateway (HTTP) → Services (RabbitMQ)
- **Internal**: Service ↔ Service (Direct RabbitMQ)
- **Message Patterns**: 'service.operation' format (e.g., 'user.create', 'queue.add-to-queue')
- **Database**: MySQL with Prisma ORM (each service has its own schema)
- **Message Queue**: RabbitMQ with queues: user_service_queue, ocr_service_queue, patient_queue_service_queue
- **Cache**: Redis (Patient Queue Service)

## Authentication & Security
- **JWT**: Access tokens (15min) + refresh tokens (7 days)
- **Roles**: PASIEN, OPERATOR, ADMIN_FASKES with @Roles decorator
- **Guards**: JwtAuthGuard, RolesGuard, RefreshTokenGuard
- **API Gateway**: Circuit breaker, retry logic, idempotency, rate limiting

## API Documentation
- **API Gateway**: Swagger at `http://localhost:3001/api/docs`
- **User Service**: Swagger at `http://localhost:3000/api/docs` 
- **OCR Service**: Swagger at `http://localhost:3002/api/docs`
- **Patient Queue Service**: Swagger at `http://localhost:3003/api/docs`

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
