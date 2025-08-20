# PIN OCR Service (KTP/SIM) — Field-ROI — YOLOv12 + Quick OCR (EasyOCR)
Dibuat: 2025-08-20 13:03:44

- YOLO hanya untuk deteksi tipe (KTP/SIM)
- Quick OCR: **EasyOCR** (bahasa `id` + `en`)
- Format respons mirip e-KTP-OCR-CNN + `tipe_identifikasi`

## Setup
pip install -r requirements.txt
# (Opsional) Install PyTorch GPU/CPU sesuai instruksi PyTorch
cp config.example.yaml config.yaml
# atur yolo.weights -> model YOLO kustom jika ingin tipe otomatis

python app.py

## Tes
curl -X POST "http://localhost:8000/ocr?debug=1" -F "image=@/path/ktp.jpg;type=image/jpeg"

## Lisensi
Dual License: Apache-2.0 + Lisensi Komersial (royalti) © 2025 Alif Nurhidayat (KillerKing93).
