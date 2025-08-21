import os
import time
import json
from dotenv import load_dotenv
from google import genai
from pydantic import BaseModel
from PIL import Image
from flask import Flask, request, jsonify
from flask_restx import Api, Resource, fields
from werkzeug.datastructures import FileStorage

load_dotenv()

app = Flask(__name__)

# Swagger API documentation setup
api = Api(
    app,
    version='2.0',
    title='MediQ OCR Engine Service - Gemini Powered',
    description='Advanced Gemini AI-powered OCR engine untuk ekstraksi data KTP Indonesia. Service ini menggunakan Google Gemini AI untuk akurasi tinggi dalam pengenalan karakter dan ekstraksi data terstruktur.',
    doc='/docs',
    contact='MediQ Support',
    contact_url='https://mediq.craftthingy.com',
    contact_email='support@mediq.com'
)

# API namespaces
ns_ocr = api.namespace('ocr', description='Gemini AI OCR Processing operations')
ns_health = api.namespace('health', description='Health check operations')

# Swagger models
ocr_response_model = api.model('OCRResponse', {
    'error': fields.Boolean(description='Status error', example=False),
    'message': fields.String(description='Response message', example='Proses OCR Berhasil'),
    'result': fields.Raw(description='OCR hasil data terstruktur'),
    'processing_time': fields.String(description='Waktu processing dalam detik', example='2.145')
})

ktp_data_model = api.model('KTPData', {
    'nik': fields.String(description='Nomor Induk Kependudukan', example='3506042602660001'),
    'nama': fields.String(description='Nama lengkap', example='SULISTYONO'),
    'tempat_lahir': fields.String(description='Tempat lahir', example='KEDIRI'),
    'tgl_lahir': fields.String(description='Tanggal lahir', example='26-02-1966'),
    'jenis_kelamin': fields.String(description='Jenis kelamin', example='LAKI-LAKI'),
    'alamat': fields.Nested(api.model('Alamat', {
        'name': fields.String(description='Alamat lengkap', example='JL.RAYA - DSN PURWOKERTO'),
        'rt_rw': fields.String(description='RT/RW', example='002 / 003'),
        'kel_desa': fields.String(description='Kelurahan/Desa', example='PURWOKERTO'),
        'kecamatan': fields.String(description='Kecamatan', example='NGADILUWIH')
    })),
    'agama': fields.String(description='Agama', example='ISLAM'),
    'status_perkawinan': fields.String(description='Status perkawinan', example='KAWIN'),
    'pekerjaan': fields.String(description='Pekerjaan', example='GURU'),
    'kewarganegaraan': fields.String(description='Kewarganegaraan', example='WNI'),
    'berlaku_hingga': fields.String(description='Masa berlaku', example='SEUMUR HIDUP'),
    'tipe_identifikasi': fields.String(description='Tipe dokumen', example='ktp'),
    'processing_time': fields.String(description='Waktu processing', example='2.145s')
})

health_response_model = api.model('HealthResponse', {
    'status': fields.String(description='Status kesehatan service', example='healthy'),
    'service': fields.String(description='Nama service', example='ocr-engine-gemini'),
    'timestamp': fields.Float(description='Timestamp Unix', example=1755799351.2458284),
    'gemini_status': fields.String(description='Status Gemini AI', example='ready'),
    'version': fields.String(description='Versi service', example='3.0.0')
})

upload_parser = api.parser()
upload_parser.add_argument('image', location='files', type=FileStorage, required=True, help='KTP image file (JPG, PNG, WEBP)')

# Configuration
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "AIzaSyDeJf8yNpIq7v0HPzmuibzbuawGAb8Y8HA")
MODEL_NAME = "gemini-2.0-flash-exp"
PORT = int(os.getenv("PORT", 8604))

class IdCard(BaseModel):
    provinsi: str
    kota: str
    NIK: str
    nama: str
    tempat_tgl_lahir: str
    jenis_kelamin: str
    gol_darah: str
    alamat: str
    rt_rw: str
    kel_desa: str
    kecamatan: str
    agama: str
    status_perkawinan: str
    pekerjaan: str
    kewarganegaraan: str
    berlaku_hingga: str

# Gemini prompt untuk ekstraksi KTP
PROMPT = """
Ekstrak data KTP Indonesia dari gambar dan kembalikan dalam format JSON yang tepat berikut:
{
    "nik": "",
    "nama": "",
    "tempat_lahir": "",
    "tgl_lahir": "",
    "jenis_kelamin": "",
    "alamat": {
        "name": "",
        "rt_rw": "",
        "kel_desa": "",
        "kecamatan": ""
    },
    "agama": "",
    "status_perkawinan": "",
    "pekerjaan": "",
    "kewarganegaraan": "",
    "berlaku_hingga": ""
}

Pastikan:
- NIK dalam format 16 digit
- Tanggal dalam format DD-MM-YYYY
- Jenis kelamin: LAKI-LAKI atau PEREMPUAN
- Berlaku hingga: gunakan "SEUMUR HIDUP" jika tidak ada tanggal kadaluarsa
- Alamat dipecah sesuai struktur yang diminta
- Semua field diisi, gunakan "-" jika tidak ditemukan
"""

# Initialize Gemini client
try:
    client = genai.Client(api_key=GOOGLE_API_KEY)
    gemini_ready = True
except Exception as e:
    print(f"[ERROR] Gemini initialization failed: {e}")
    client = None
    gemini_ready = False

def process_ktp_with_gemini(image_file):
    """Process KTP image with Gemini AI"""
    try:
        # Prepare image
        image = Image.open(image_file.stream)
        image.thumbnail([1024, 1024], Image.Resampling.LANCZOS)
        
        # Call Gemini API
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=[PROMPT, image],
            config={
                "response_mime_type": "application/json",
                "temperature": 0.1,  # Low temperature for consistent results
                "top_p": 0.8,
                "max_output_tokens": 1024
            },
        )
        
        # Parse response
        result_json = json.loads(response.text)
        
        # Add metadata
        result_json['tipe_identifikasi'] = 'ktp'
        
        return result_json, None
        
    except json.JSONDecodeError as e:
        return None, f"Failed to parse Gemini response: {str(e)}"
    except Exception as e:
        return None, f"Gemini processing error: {str(e)}"

@ns_health.route('/')
class HealthRoot(Resource):
    @api.marshal_with(health_response_model)
    def get(self):
        """Service information"""
        return {
            "name": "MediQ OCR Engine Service - Gemini Powered",
            "version": "3.0.0", 
            "status": "running",
            "gemini_ready": gemini_ready,
            "port": PORT,
            "model": MODEL_NAME,
            "endpoints": {
                "health": "/health/health",
                "legacy_health": "/healthz", 
                "docs": "/docs",
                "ocr_scan": "/ocr/scan-ocr",
                "legacy_ocr": "/ocr"
            }
        }

@ns_health.route('/health')
class Health(Resource):
    @api.marshal_with(health_response_model)
    def get(self):
        """Health check endpoint"""
        return {
            "status": "healthy" if gemini_ready else "degraded",
            "service": "ocr-engine-gemini",
            "timestamp": time.time(),
            "gemini_status": "ready" if gemini_ready else "error",
            "version": "3.0.0"
        }

@ns_ocr.route('/scan-ocr')
class OCRProcess(Resource):
    @api.expect(upload_parser)
    @api.marshal_with(ocr_response_model)
    def post(self):
        """Process KTP image menggunakan Gemini AI untuk ekstraksi data yang akurat"""
        if not gemini_ready:
            return {
                "error": True,
                "message": "Gemini AI service not ready",
                "result": None
            }, 503
            
        t0 = time.time()
        
        # Validate file upload
        if 'image' not in request.files:
            return {
                "error": True,
                "message": "Parameter 'image' wajib diisi",
                "result": None
            }, 400
            
        file = request.files['image']
        if file.filename == '':
            return {
                "error": True,
                "message": "File tidak dipilih",
                "result": None
            }, 400
        
        # Validate file type
        allowed_extensions = {'jpg', 'jpeg', 'png', 'webp'}
        file_ext = file.filename.lower().split('.')[-1] if '.' in file.filename else ''
        if file_ext not in allowed_extensions:
            return {
                "error": True,
                "message": f"Format file tidak didukung. Gunakan: {', '.join(allowed_extensions)}",
                "result": None
            }, 400
        
        try:
            # Process with Gemini
            result, error = process_ktp_with_gemini(file)
            processing_time = f"{time.time() - t0:.3f}"
            
            if error:
                return {
                    "error": True,
                    "message": error,
                    "result": None,
                    "processing_time": processing_time
                }, 500
            
            # Add processing time to result
            result['processing_time'] = processing_time + 's'
            
            return {
                "error": False,
                "message": "Proses OCR Berhasil",
                "result": result,
                "processing_time": processing_time
            }
            
        except Exception as e:
            return {
                "error": True,
                "message": f"Internal server error: {str(e)}",
                "result": None,
                "processing_time": f"{time.time() - t0:.3f}"
            }, 500

# Compatibility endpoints for backward compatibility with old API structure
@ns_ocr.route('/process')
class OCRProcessAlias(Resource):
    @api.expect(upload_parser)
    @api.marshal_with(ocr_response_model)
    def post(self):
        """Alias untuk /scan-ocr endpoint untuk backward compatibility"""
        return OCRProcess().post()

@ns_ocr.route('/validate-result')
class OCRValidate(Resource):
    @api.expect(api.model('ValidateRequest', {
        'ocr_data': fields.Raw(description='Data hasil OCR untuk divalidasi', required=True)
    }))
    def post(self):
        """Validasi hasil OCR (untuk compatibility dengan API lama)"""
        try:
            data = request.get_json()
            if not data or 'ocr_data' not in data:
                return {
                    "error": True,
                    "message": "Parameter 'ocr_data' wajib diisi",
                    "result": None
                }, 400
            
            ocr_data = data['ocr_data']
            
            # Simple validation logic
            validation_result = {
                "valid": True,
                "confidence": 0.95,
                "errors": [],
                "warnings": []
            }
            
            # Validate NIK
            if not ocr_data.get('nik') or len(str(ocr_data.get('nik', ''))) != 16:
                validation_result['errors'].append("NIK harus 16 digit")
                validation_result['valid'] = False
            
            # Validate nama
            if not ocr_data.get('nama'):
                validation_result['errors'].append("Nama tidak boleh kosong")
                validation_result['valid'] = False
            
            return {
                "error": False,
                "message": "Validasi selesai",
                "result": validation_result
            }
            
        except Exception as e:
            return {
                "error": True,
                "message": f"Validation error: {str(e)}",
                "result": None
            }, 500

# Legacy endpoints for backward compatibility
@app.route("/")
def index():
    return jsonify({
        "name": "MediQ OCR Engine Service - Gemini Powered",
        "version": "3.0.0", 
        "status": "running",
        "gemini_ready": gemini_ready,
        "port": PORT,
        "model": MODEL_NAME,
        "endpoints": {
            "health": "/health/health",
            "legacy_health": "/healthz", 
            "docs": "/docs",
            "ocr_scan": "/ocr/scan-ocr",
            "ocr_process": "/ocr/process",
            "ocr_validate": "/ocr/validate-result",
            "legacy_ocr": "/ocr"
        }
    })

@app.route("/healthz")  
def healthz():
    return jsonify({
        "ok": True,
        "service": "ocr-engine-gemini",
        "gemini_status": "ready" if gemini_ready else "error"
    })

@app.route("/ocr", methods=["POST"])
def ocr_legacy():
    """Legacy OCR endpoint for backward compatibility"""
    return OCRProcess().post()

if __name__ == "__main__":
    print(f"🚀 Starting MediQ OCR Engine Service (Gemini Powered) on port {PORT}")
    print(f"🤖 Gemini AI Model: {MODEL_NAME}")
    print(f"📚 API Documentation: http://localhost:{PORT}/docs")
    print(f"💚 Health Check: http://localhost:{PORT}/health/health")
    
    if not gemini_ready:
        print("⚠️  WARNING: Gemini AI not initialized. Please check GOOGLE_API_KEY.")
    
    app.run(host="0.0.0.0", port=PORT, debug=False)
