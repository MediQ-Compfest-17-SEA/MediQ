# MediQ Backend — OCR Engine Service (Internal, Aligned to Current Implementation)

Description
Internal OCR Engine that processes KTP images and returns structured data. This service is used only by the OCR Service. It exposes HTTP endpoints for image processing and health, and provides a local Swagger UI for development. It is not exposed publicly and should not be consumed directly by clients.

Status
- Exposure: Internal-only (behind OCR Service)
- Public access: Not exposed via API Gateway
- Local Swagger: /docs for development and QA only
- Compatibility: Includes legacy/alias endpoints for older clients within the platform

Ports and URLs
- Service port: 8604
- Local Swagger (dev only): http://localhost:8604/docs
- Health (dev): http://localhost:8604/health/health

Key Features (current)
- KTP OCR processing endpoint: /ocr/scan-ocr
- Backward-compatibility alias: /ocr/process and /ocr (legacy)
- Validations for file presence and allowed formats (jpg, jpeg, png, webp)
- Structured JSON output with normalized KTP fields
- Health and information endpoints

Security and Exposure
- This service is internal and should only be called by the OCR Service.
- Do not document or expose these endpoints publicly.
- Local Swagger is for developers and CI-only usage.

Endpoints

Health and Info
- GET /health/ — Service info JSON (name, version, status, endpoints)
- GET /health/health — Health status JSON (healthy/degraded, gemini status)
- GET /healthz — Legacy health check
- GET / — Root info (JSON), contains endpoint map

OCR Processing
- POST /ocr/scan-ocr — Process a KTP image and return normalized JSON result
- POST /ocr/process — Alias of /ocr/scan-ocr (backward compatibility)
- POST /ocr — Legacy endpoint that proxies to /ocr/scan-ocr

Request: /ocr/scan-ocr
- Content-Type: multipart/form-data
- Field: image (required)
- Allowed extensions: jpg, jpeg, png, webp

Successful Response (200):
{
  "error": false,
  "message": "Proses OCR Berhasil",
  "result": {
    "nik": "3506042602660001",
    "nama": "SULISTYONO",
    "tempat_lahir": "KEDIRI",
    "tgl_lahir": "26-02-1966",
    "jenis_kelamin": "LAKI-LAKI",
    "alamat": {
      "name": "JL.RAYA - DSN PURWOKERTO",
      "rt_rw": "002 / 003",
      "kel_desa": "PURWOKERTO",
      "kecamatan": "NGADILUWIH"
    },
    "agama": "ISLAM",
    "status_perkawinan": "KAWIN",
    "pekerjaan": "GURU",
    "kewarganegaraan": "WNI",
    "berlaku_hingga": "SEUMUR HIDUP",
    "tipe_identifikasi": "ktp",
    "processing_time": "2.145s"
  },
  "processing_time": "2.145"
}

Validation/Error Responses:
- 400: Missing file or unsupported format
  {
    "error": true,
    "message": "Parameter 'image' wajib diisi",
    "result": null
  }
  or
  {
    "error": true,
    "message": "Format file tidak didukung. Gunakan: jpg, jpeg, png, webp",
    "result": null
  }
- 503: Gemini AI not ready
  {
    "error": true,
    "message": "Gemini AI service not ready",
    "result": null
  }
- 500: Internal processing error
  {
    "error": true,
    "message": "Internal server error: ...",
    "result": null,
    "processing_time": "0.123"
  }

Integration Contract (with OCR Service)
- OCR Service posts multipart/form-data with field image.
- OCR Engine returns JSON as above; OCR Service will further normalize/validate and map to domain DTOs.
- If OCR Engine returns non-2xx, OCR Service surfaces it back to the API Gateway with accurate status and upstream detail.

Environment Variables
GOOGLE_API_KEY=your-gemini-api-key
PORT=8604
FLASK_ENV=production

Notes:
- GOOGLE_API_KEY must be set with valid Gemini API credentials.
- PORT defaults to 8604 if not set.
- This service uses the Google genai client; ensure outbound internet access where deployed.

Run Locally
- Python 3.11+
- pip install -r requirements.txt
- python app.py
- Swagger UI (dev-only): http://localhost:8604/docs
- Health: http://localhost:8604/health/health

Request Example (curl)
# Valid request
curl -X POST http://localhost:8604/ocr/scan-ocr \
  -H "Content-Type: multipart/form-data" \
  -F "image=@/path/to/ktp-image.jpg"

# Missing file (returns 400)
curl -X POST http://localhost:8604/ocr/scan-ocr

Operational Notes
- Image is resized to a safe thumbnail for processing before sending to the model.
- The model prompt enforces normalized output including snake_case fields and "-" defaults for missing values.
- The service adds metadata: tipe_identifikasi and processing_time.
- For internal-only usage: upgrade/downgrade endpoints may change; keep OCR Service aligned to app responses.

Swagger (dev-only)
- Local docs at /docs are provided by Flask-RESTX for development convenience.
- Do not expose or link this Swagger publicly.
- Remove from production ingress or protect with network policies.

Changelog (doc alignment)
- Marked service as internal and removed public exposure claims.
- Clarified required field name (image) and allowed formats.
- Documented all actual endpoints: /ocr/scan-ocr, /ocr/process (alias), /ocr (legacy), health endpoints.
- Noted dev-only Swagger and internal usage by OCR Service.

License
Dual License: Apache-2.0 + Commercial
