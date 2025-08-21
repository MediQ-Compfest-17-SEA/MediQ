import pytest
import os
import sys
import cv2
import numpy as np
from PIL import Image
from io import BytesIO

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app import app, CFG

@pytest.fixture
def client():
    """Flask test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

@pytest.fixture
def sample_ktp_image():
    """Create sample KTP image for testing"""
    # Create a simple test image (placeholder)
    img = np.zeros((600, 800, 3), dtype=np.uint8)
    
    # Add some text-like regions
    cv2.rectangle(img, (50, 50), (750, 100), (255, 255, 255), -1)
    cv2.rectangle(img, (50, 120), (400, 170), (255, 255, 255), -1)
    cv2.rectangle(img, (50, 190), (600, 240), (255, 255, 255), -1)
    
    # Convert to bytes
    pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    img_bytes = BytesIO()
    pil_img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    
    return img_bytes

@pytest.fixture
def sample_sim_image():
    """Create sample SIM image for testing"""
    # Create a simple test image for SIM
    img = np.zeros((400, 600, 3), dtype=np.uint8)
    
    # Add some text-like regions for SIM
    cv2.rectangle(img, (30, 30), (570, 80), (255, 255, 255), -1)
    cv2.rectangle(img, (30, 100), (300, 150), (255, 255, 255), -1)
    
    # Convert to bytes
    pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    img_bytes = BytesIO()
    pil_img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    
    return img_bytes

@pytest.fixture
def invalid_image():
    """Create invalid image data for testing"""
    return BytesIO(b"invalid image data")

@pytest.fixture
def mock_config():
    """Mock configuration for testing"""
    return {
        "yolo": {
            "weights": "test_weights.pt",
            "imgsz": 640,
            "conf": 0.25,
            "use_type": True
        },
        "ocr": {
            "langs": ["id", "en"],
            "min_width": 1400,
            "debug_dir": "test_debug",
            "text_threshold": 0.7,
            "low_text": 0.3,
            "slope_ths": 0.2,
            "mag_ratio": 1.5
        },
        "server": {
            "host": "0.0.0.0",
            "port": 8604,
            "debug": False
        }
    }

@pytest.fixture
def mock_ocr_result():
    """Mock OCR result for KTP"""
    return {
        "nik": "3171012345678901",
        "nama": "JOHN DOE SMITH", 
        "tempat_lahir": "JAKARTA",
        "tgl_lahir": "01-01-1990",
        "jenis_kelamin": "LAKI-LAKI",
        "alamat": {
            "kel_desa": "MENTENG",
            "kecamatan": "MENTENG",
            "name": "JL. SUDIRMAN NO. 123 RT 001 RW 002",
            "rt_rw": "001/002"
        },
        "agama": "ISLAM",
        "status_perkawinan": "BELUM KAWIN", 
        "pekerjaan": "PELAJAR/MAHASISWA",
        "kewarganegaraan": "WNI",
        "berlaku_hingga": "SEUMUR HIDUP",
        "tipe_identifikasi": "ktp"
    }
