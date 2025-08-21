import os
from dotenv import load_dotenv
from google import genai
from pydantic import BaseModel
from PIL import Image
from flask import Flask, request, jsonify
import json

load_dotenv()

app = Flask(__name__)
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
model_name = "gemini-2.5-flash-preview-05-20"

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

prompt = """
Ekstrak data KTP Indonesia dari gambar dan kembalikan dalam format JSON berikut:
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
        "kecamatan": "",
    },
    "agama": "",
    "status_perkawinan": "",
    "pekerjaan": "",
    "kewarganegaraan": "",
    "berlaku_hingga": ""
}
"""
client = genai.Client(api_key=GOOGLE_API_KEY)

@app.route('/scan-ocr', methods=['POST'])
def ocr():
    # Pastikan file dikirim dengan key 'image' (form-data)
    if 'image' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400
    file = request.files['image']
    try:
        im = Image.open(file.stream)
        im.thumbnail([1024, 1024], Image.Resampling.LANCZOS)
        response = client.models.generate_content(
            model=model_name,
            contents=[prompt, im],
            config={
                "response_mime_type": "application/json",
            },
        )
        result_json = json.loads(response.text)
        return jsonify(result_json)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)