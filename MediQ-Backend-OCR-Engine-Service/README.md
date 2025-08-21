# MediQ OCR Engine Service - Gemini Powered

Advanced Gemini AI-powered OCR engine untuk ekstraksi data KTP Indonesia dengan akurasi tinggi.

## Features

- 🤖 **Gemini AI Integration**: Menggunakan Google Gemini 2.0 Flash untuk OCR akurat
- 📄 **KTP Processing**: Ekstraksi data lengkap dari KTP Indonesia
- 🚀 **High Performance**: Processing cepat dengan response time < 3 detik
- 📊 **Swagger Documentation**: API documentation lengkap di `/docs`
- 💚 **Health Monitoring**: Health check endpoints untuk monitoring
- 🔄 **Backward Compatibility**: Compatible dengan API lama

## API Endpoints

### OCR Processing
- `POST /ocr/scan-ocr` - Process KTP dengan Gemini AI
- `POST /ocr/process` - Alias untuk backward compatibility  
- `POST /ocr/validate-result` - Validasi hasil OCR
- `POST /ocr` - Legacy endpoint

### Health & Monitoring
- `GET /health/` - Service information
- `GET /health/health` - Health check
- `GET /healthz` - Legacy health check
- `GET /` - Root endpoint dengan service info
- `GET /docs` - Swagger documentation

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env dan set GOOGLE_API_KEY
```

3. Run service:
```bash
python app.py
```

## Environment Variables

- `GOOGLE_API_KEY` - Google Gemini AI API key (required)
- `PORT` - Service port (default: 8604)
- `FLASK_ENV` - Flask environment (production/development)

## Response Format

```json
{
  "error": false,
  "message": "Proses OCR Berhasil",
  "processing_time": "2.145",
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
  }
}
```

## Integration

Service ini terintegrasi dengan:
- MediQ API Gateway (port 8601)
- MediQ OCR Service (port 8603) 
- Nginx reverse proxy
- Kubernetes deployment

Swagger documentation: http://localhost:8604/docs
