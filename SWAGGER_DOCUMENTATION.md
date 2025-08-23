# MediQ Backend — Swagger/OpenAPI Documentation (Aligned to Current Implementation)

Overview

This document aligns the Swagger/OpenAPI documentation across MediQ backend services with the current architecture and implemented behavior. Public clients use the API Gateway over HTTP, while internal service-to-service communication uses gRPC. Deprecated RabbitMQ proxying paths and endpoints are removed from documentation.

Service Documentation URLs

- API Gateway (Port 8601): http://localhost:8601/api/docs
- User Service (Port 8602): http://localhost:8602/api/docs
- OCR Service (Port 8603): http://localhost:8603/api/docs
- Patient Queue Service (Port 8605): http://localhost:8605/api/docs
- Institution Service (Port 8606): http://localhost:8606/api/docs
- OCR Engine Service (Port 8604): No public Swagger (ML engine), service is internal-only

Notes

- External access is via API Gateway only. Services expose REST for local/internal use and Swagger for development.
- Internal calls are gRPC-first. The gateway preserves upstream HTTP status codes on fallbacks.
- Leaderboard is WebSocket-first with snapshot hydration; HTTP snapshot exists for admins when token is present.
- All field names in OCR and Queue DTOs use snake_case where applicable to match current implementations and tests.

API Gateway

- Base URL: http://localhost:8601
- Swagger: http://localhost:8601/api/docs
- Auth:
  - Bearer JWT: Authorization: Bearer <token>
  - Optional API Key: x-api-key: <key> (for allowed public routes like /ocr/upload)
- WebSocket: Real-time leaderboard stream; snapshot available via HTTP for admins

Exposed Routes (facade)

- Auth
  - POST /auth/login/admin — Admin login
  - POST /auth/login/user — Patient login (nik + name)
  - POST /auth/refresh — Refresh access token
- Users
  - GET /users — Admin-only listing (JWT required)
- OCR
  - POST /ocr/upload — multipart/form-data; field "file" required
  - POST /ocr/confirm — Confirm OCR data and enqueue
  - GET /ocr/temp/:tempId — Get temporary record by ID
  - PATCH /ocr/temp/:tempId — Patch temporary record
  - POST /ocr/confirm-from-temp/:tempId — Confirm from temp
- Queue
  - POST /queue — Add to queue
  - GET /queue — List queues (filtering/pagination)
  - GET /queue/stats — Snapshot stats
  - GET /queue/next — Dequeue next
  - GET /queue/:id — Get by id
  - PATCH /queue/:id/status — Update status
  - DELETE /queue/:id — Cancel queue
- Institutions
  - GET /institutions — List institutions
  - GET /institutions/:id — Get institution (includes services)
  - GET /institutions/:id/services — List services of institution

User Service

- Port: 8602
- Swagger: http://localhost:8602/api/docs
- Publicly reached via API Gateway. Direct use is for development.
- Typical tags: auth, users
- Main endpoints:
  - POST /auth/login/admin
  - POST /auth/login/user
  - POST /auth/refresh
  - GET /users (protected, role ADMIN_FASKES)
- JWT: Access ~15m; Refresh ~7d

OCR Service

- Port: 8603
- Swagger: http://localhost:8603/api/docs
- Purpose: KTP OCR pipeline (upload → temp → confirm → queue)

Endpoints

- POST /ocr/upload
  - Content-Type: multipart/form-data
  - Required field: file (the uploaded KTP image). Requests without "file" return 400 BadRequest.
  - Response: { success, message, data?, requestId? }
- POST /ocr/confirm
  - Body: OcrDataDto
  - Behavior: Confirms data, ensures user existence, adds to queue via gRPC. Defaults '-' for missing alamat/agama segments.
- GET /ocr/temp/:tempId
  - Returns 404 when not found or expired.
- PATCH /ocr/temp/:tempId
  - Updates the temp record; returns 404 when not found.
- POST /ocr/confirm-from-temp/:tempId
  - Confirms from temp path; errors propagate with 500 on service failures.

Error Mapping

- Upstream engine errors are surfaced with accurate HTTP status and include the upstream detail body.
- Example message pattern preserved by service layer for controller parsing:
  - "Upstream OCR engine error: status=502, body={...json...}"

Validation

- isValidNik: 16-digit string
- String similarity helpers (hammingDistance, levenshtein) exist for internal validation

Patient Queue Service

- Port: 8605
- Swagger: http://localhost:8605/api/docs
- Purpose: Manage queues, priorities, status transitions, and stats

Endpoints

- POST /queue — Add patient to queue
- GET /queue — Filter by status, priority, institutionId, pagination (page, pageSize)
- GET /queue/stats — Aggregate snapshot
- GET /queue/next — Returns the highest priority, earliest-created queue entry; 404 on empty
- GET /queue/:id — Fetch queue by id; 404 when missing
- PATCH /queue/:id/status — Allowed transitions: WAITING → IN_PROGRESS → COMPLETED; CANCELLED from WAITING
- DELETE /queue/:id — Cancel queue; 404 when not found
- GET /stats/daily — Hourly distribution (timezone-safe)
- GET /stats/weekly — Weekly aggregates

Priority and Status

- Priority: URGENT, HIGH, NORMAL, LOW
- Status: WAITING, IN_PROGRESS, COMPLETED, CANCELLED

Institution Service

- Port: 8606
- Swagger: http://localhost:8606/api/docs
- Purpose: Manage institutions and expose available services per institution

Endpoints

- POST /institutions — Create institution (requires code and type)
- GET /institutions — List institutions
- GET /institutions/:id — Get institution by id (includes services)
- GET /institutions/:id/services — List services for an institution

DTOs and Models

OCR Service DTOs

- AlamatDto — { name, kel_desa, kecamatan, rt_rw }
- OcrDataDto — KTP data fields (nik, nama, tempat_lahir, tgl_lahir, jenis_kelamin, alamat, agama, status_perkawinan, pekerjaan, kewarganegaraan, berlaku_hingga)
- OcrUploadResponseDto — { success, message, data?, requestId? }
- OcrConfirmResponseDto — { success, message, user?, queue? }

Queue Service DTOs

- CreatePatientQueueDto — Patient registration data; supports snake_case input
- UpdateQueueStatusDto — { status }
- GetQueuesQueryDto — filtering and pagination

Validation and Security

- DTOs use class-validator decorators
- API Gateway applies JwtAuthGuard and RolesGuard for protected routes
- x-api-key header supported for selected public endpoints (like /ocr/upload)

API Documentation Features

- Interactive UI with try-it-out
- Request examples for each endpoint
- Response schemas aligned with real implementations and tests

How To Run Locally

- Start each service in development mode:
  - API Gateway: cd MediQ-Backend-API-Gateway && npm run start:dev → http://localhost:8601/api/docs
  - User Service: cd MediQ-Backend-User-Service && npm run start:dev → http://localhost:8602/api/docs
  - OCR Service: cd MediQ-Backend-OCR-Service && npm run start:dev → http://localhost:8603/api/docs
  - Patient Queue Service: cd MediQ-Backend-Patient-Queue-Service && npm run start:dev → http://localhost:8605/api/docs
  - Institution Service: cd MediQ-Backend-Institution-Service && npm run start:dev → http://localhost:8606/api/docs

Conventions

- Prettier: singleQuote=true, trailingComma=all
- ESLint: TypeScript recommended
- Absolute imports via src/ mapping
- Do not document internal gRPC interfaces in Swagger; keep docs to public REST behaviors

Version and Status

- OpenAPI alignment: Completed for User, Queue, Institution, OCR, and Gateway facades
- Coverage policy: No exclusions; global 90% per service
- Architecture: Public REST via API Gateway; internal gRPC

Appendix: Example Requests

- Upload KTP via Gateway
  - curl -X POST http://localhost:8601/ocr/upload -F "file=@/path/ktp.jpg"
- Confirm OCR via Gateway
  - curl -X POST http://localhost:8601/ocr/confirm -H "Content-Type: application/json" -d '{ "nik": "3171012345678901", "nama": "John Doe" }'
- Get next queue via Gateway
  - curl http://localhost:8601/queue/next

End
