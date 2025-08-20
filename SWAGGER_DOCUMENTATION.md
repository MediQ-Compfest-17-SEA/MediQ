# MediQ Backend - Swagger Documentation Setup

## Overview
Comprehensive Swagger/OpenAPI documentation has been successfully configured for all MediQ backend services with consistent styling, proper response types, and detailed endpoint descriptions.

## Service Documentation URLs

### 1. API Gateway Service
- **Port**: 3001
- **Swagger URL**: `http://localhost:3001/api/docs`
- **Status**: ✅ Configured (pre-existing)
- **Features**: Bearer Auth, comprehensive endpoint documentation

### 2. User Service  
- **Port**: 3000
- **Swagger URL**: `http://localhost:3000/api/docs`
- **Status**: ✅ Updated and Enhanced
- **Features**: JWT authentication, user management, auth operations
- **Tags**: `users`, `auth`

### 3. OCR Service
- **Port**: 3002  
- **Swagger URL**: `http://localhost:3002/api/docs`
- **Status**: ✅ Newly Configured
- **Features**: File upload documentation, OCR processing, comprehensive DTOs
- **Tags**: `OCR`

### 4. Patient Queue Service
- **Port**: 3003
- **Swagger URL**: `http://localhost:3003/api/docs`  
- **Status**: ✅ Newly Configured
- **Features**: Queue management, statistics, filtering, pagination
- **Tags**: `Queue`, `Stats`

## Key Features Implemented

### OCR Service Documentation
- **File Upload**: Proper `multipart/form-data` documentation
- **Response Types**: Comprehensive DTOs with validation decorators
- **Error Handling**: Detailed error response schemas
- **Data Models**: 
  - `AlamatDto` - Address information
  - `OcrDataDto` - Complete KTP data structure
  - `OcrUploadResponseDto` - Upload operation response
  - `OcrConfirmResponseDto` - Confirmation response

#### OCR Endpoints:
1. `POST /ocr/upload` - Upload KTP image for OCR processing
2. `POST /ocr/confirm` - Confirm OCR data and add to patient queue

### Patient Queue Service Documentation
- **CRUD Operations**: Complete queue management endpoints
- **Filtering & Pagination**: Query parameters with validation
- **Statistics**: Real-time queue analytics
- **Priority System**: URGENT, HIGH, NORMAL, LOW priorities
- **Status Tracking**: WAITING, IN_PROGRESS, COMPLETED, CANCELLED

#### Queue Endpoints:
1. `POST /queue` - Add patient to queue
2. `GET /queue` - Get all queues (with filtering)
3. `GET /queue/stats` - Get queue statistics
4. `GET /queue/next` - Get next patient in queue
5. `GET /queue/:id` - Get queue by ID
6. `PATCH /queue/:id/status` - Update queue status
7. `DELETE /queue/:id` - Cancel queue

#### Statistics Endpoints:
1. `GET /stats/daily` - Daily queue statistics
2. `GET /stats/weekly` - Weekly queue statistics

## Data Transfer Objects (DTOs)

### OCR Service DTOs
```typescript
- AlamatDto - Address components (kel_desa, kecamatan, name, rt_rw)
- OcrDataDto - Complete KTP data (nik, nama, tempat_lahir, etc.)
- OcrUploadResponseDto - Upload operation response
- OcrConfirmResponseDto - Confirmation response
```

### Queue Service DTOs
```typescript
- CreatePatientQueueDto - Patient registration data
- UpdateQueueStatusDto - Status update data
- QueueDto - Queue information
- QueueStatsDto - Statistics data
- GetQueuesQueryDto - Query parameters for filtering
```

## Validation & Security Features

### Input Validation
- **Class Validators**: Comprehensive validation using class-validator decorators
- **Type Safety**: Strong TypeScript typing throughout
- **Required Fields**: Proper validation for mandatory fields
- **Data Formats**: Validation for NIK (16 digits), dates, enums

### Error Handling
- **Consistent Responses**: Standardized error response formats
- **HTTP Status Codes**: Proper status code usage
- **Descriptive Messages**: Clear error descriptions
- **Validation Errors**: Detailed field-level validation feedback

### API Documentation Features
- **Interactive UI**: Swagger UI with try-it-out functionality
- **Request Examples**: Sample data for all endpoints
- **Response Schemas**: Detailed response structure documentation
- **File Upload**: Proper binary file upload documentation
- **Query Parameters**: Complete parameter documentation with examples

## Code Style Compliance

All implementations follow the established code style guidelines:
- **Prettier Configuration**: Single quotes, trailing commas
- **ESLint Rules**: TypeScript recommended rules
- **Import Structure**: Absolute imports using src/ mapping
- **Decorator Usage**: Comprehensive API decorators
- **Error Handling**: NestJS ValidationPipe integration

## Build Status

### ✅ Successfully Building Services:
1. **OCR Service**: `npm run build` ✅
2. **Patient Queue Service**: `npm run build` ✅
3. **User Service**: `npm run build` ✅

### 🔧 Requires Attention:
1. **API Gateway Service**: Complex architectural issues requiring refactoring

## Usage Instructions

### Starting Services with Swagger Documentation:

1. **OCR Service:**
   ```bash
   cd MediQ-Backend-OCR-Service
   npm run start:dev
   # Visit: http://localhost:3002/api/docs
   ```

2. **Patient Queue Service:**
   ```bash
   cd MediQ-Backend-Patient-Queue-Service  
   npm run start:dev
   # Visit: http://localhost:3003/api/docs
   ```

3. **User Service:**
   ```bash
   cd MediQ-Backend-User-Service
   npm run start:dev
   # Visit: http://localhost:3000/api/docs
   ```

### Testing API Endpoints:
- Use Swagger UI's interactive testing feature
- Import OpenAPI JSON/YAML into tools like Postman
- Use curl commands generated by Swagger UI

## Next Steps Recommendations

1. **Database Integration**: Replace mock implementations with Prisma/database operations
2. **Authentication**: Add JWT guards where needed for protected endpoints
3. **API Gateway**: Resolve architectural issues and ensure proper service integration  
4. **Testing**: Implement comprehensive integration tests for documented endpoints
5. **Performance**: Add performance monitoring and metrics collection
6. **Deployment**: Set up environment-specific Swagger configurations

## Summary

The Swagger documentation setup is now comprehensive and production-ready for OCR Service and Patient Queue Service, with enhanced documentation for the User Service. All services provide:

- Interactive API documentation
- Comprehensive request/response schemas
- File upload support (OCR Service)
- Query parameter validation
- Error response documentation
- Consistent styling and branding

The documentation follows OpenAPI 3.0 standards and provides a solid foundation for frontend development and API testing.
