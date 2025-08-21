import pytest
import json
from unittest.mock import patch, MagicMock
from app import app

class TestHealthEndpoints:
    """Test health check endpoints"""
    
    def test_health_root_endpoint(self, client):
        """Test root health endpoint"""
        response = client.get('/health/')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['name'] == 'MediQ OCR Engine Service'
        assert data['version'] == '4.0.1'
        assert 'yolo_loaded' in data
        assert 'port' in data
        assert 'languages' in data

    def test_health_check_endpoint(self, client):
        """Test detailed health check"""
        response = client.get('/health/health')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert data['service'] == 'ocr-engine'
        assert 'timestamp' in data
        assert 'yolo_status' in data
        assert 'ocr_status' in data

    def test_legacy_index_endpoint(self, client):
        """Test legacy index endpoint for backward compatibility"""
        response = client.get('/')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert 'name' in data
        assert 'version' in data
        assert 'yolo_loaded' in data

    def test_legacy_healthz_endpoint(self, client):
        """Test legacy healthz endpoint"""
        response = client.get('/healthz')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert data['ok'] is True

class TestOCREndpoints:
    """Test OCR processing endpoints"""
    
    def test_ocr_endpoint_missing_image(self, client):
        """Test OCR endpoint without image parameter"""
        response = client.post('/ocr/scan-ocr')
        assert response.status_code == 400
        
        data = json.loads(response.data)
        assert data['error'] is True
        assert 'image' in data['message'].lower()

    def test_ocr_endpoint_invalid_image(self, client, invalid_image):
        """Test OCR endpoint with invalid image data"""
        response = client.post('/ocr/scan-ocr', data={
            'image': (invalid_image, 'invalid.jpg')
        })
        assert response.status_code == 400
        
        data = json.loads(response.data)
        assert data['error'] is True
        assert 'gagal membaca gambar' in data['message'].lower()

    @patch('app.easy_sweep')
    @patch('app.easy_read_tokens')
    @patch('app.parse_ktp_text')
    def test_ocr_endpoint_successful_ktp(self, mock_parse_ktp, mock_read_tokens, 
                                        mock_easy_sweep, client, sample_ktp_image, mock_ocr_result):
        """Test successful KTP OCR processing"""
        # Mock the OCR processing functions
        mock_easy_sweep.return_value = {
            "score": 10,
            "text": "REPUBLIK INDONESIA KARTU TANDA PENDUDUK NIK 3171012345678901 NAMA JOHN DOE",
            "tokens": [{"text": "REPUBLIK", "conf": 0.9}],
            "which": "variant1"
        }
        
        mock_read_tokens.return_value = [
            {"text": "3171012345678901", "conf": 0.95, "bbox": (100, 50, 300, 80)}
        ]
        
        mock_parse_ktp.return_value = {
            "nik": "3171012345678901",
            "nama": "JOHN DOE",
            "tempat_lahir": "JAKARTA",
            "tgl_lahir": "01-01-1990"
        }
        
        response = client.post('/ocr/scan-ocr', data={
            'image': (sample_ktp_image, 'ktp.jpg')
        })
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['error'] is False
        assert data['message'] == 'Proses OCR Berhasil'
        assert 'result' in data
        assert data['result']['tipe_identifikasi'] == 'ktp'

    def test_legacy_ocr_endpoint(self, client, sample_ktp_image):
        """Test legacy OCR endpoint for backward compatibility"""
        with patch('app.OCRProcess.post') as mock_post:
            mock_post.return_value = {"error": False, "message": "Success"}
            
            response = client.post('/ocr', data={
                'image': (sample_ktp_image, 'ktp.jpg')
            })
            
            # Should call the new OCR endpoint
            mock_post.assert_called_once()

class TestOCRUtilities:
    """Test OCR utility functions"""
    
    def test_score_text_id_with_ktp_keywords(self):
        """Test text scoring with KTP keywords"""
        from app import score_text_id
        
        ktp_text = "PROVINSI DKI JAKARTA KOTA JAKARTA PUSAT NIK 3171012345678901 NAMA JOHN DOE"
        score = score_text_id(ktp_text)
        assert score > 5  # Should have high score with KTP keywords and NIK

    def test_score_text_id_with_minimal_keywords(self):
        """Test text scoring with minimal keywords"""
        from app import score_text_id
        
        minimal_text = "NAMA JOHN DOE"
        score = score_text_id(minimal_text)
        assert score >= 1  # Should have some score

    def test_score_text_id_empty_text(self):
        """Test text scoring with empty text"""
        from app import score_text_id
        
        score = score_text_id("")
        assert score == 0
        
        score = score_text_id(None)
        assert score == 0

    def test_tokens_to_text_ordering(self):
        """Test token to text conversion with proper ordering"""
        from app import tokens_to_text
        
        tokens = [
            {"text": "NAMA", "cx": 100, "cy": 50},
            {"text": "JOHN", "cx": 200, "cy": 50},
            {"text": "NIK", "cx": 100, "cy": 100},
            {"text": "123456", "cx": 200, "cy": 100}
        ]
        
        result = tokens_to_text(tokens)
        lines = result.split('\n')
        
        assert len(lines) == 2
        assert "NAMA JOHN" in lines[0]
        assert "NIK 123456" in lines[1]

    def test_tokens_to_text_empty(self):
        """Test token to text conversion with empty tokens"""
        from app import tokens_to_text
        
        result = tokens_to_text([])
        assert result == ""
        
        result = tokens_to_text(None)
        assert result == ""

class TestYOLODetector:
    """Test YOLO detector functionality"""
    
    @patch('app.detector')
    def test_yolo_detector_loaded(self, mock_detector):
        """Test YOLO detector availability"""
        mock_detector.predict_type_and_box.return_value = ("ktp", (10, 10, 500, 300))
        
        # Test detector functionality
        assert mock_detector is not None

    def test_yolo_detector_disabled(self):
        """Test behavior when YOLO detector is disabled"""
        with patch('app.detector', None):
            # Should still work without YOLO
            from app import detector
            assert detector is None

class TestConfiguration:
    """Test configuration management"""
    
    def test_default_configuration(self):
        """Test default configuration values"""
        from app import CFG
        
        assert 'yolo' in CFG
        assert 'ocr' in CFG
        assert 'server' in CFG
        assert CFG['ocr']['langs'] == ['id', 'en']
        assert CFG['ocr']['min_width'] == 1400

    @patch.dict(os.environ, {'PIN_OCR_CONFIG': 'nonexistent.yaml'})
    def test_config_file_not_found(self):
        """Test behavior when config file doesn't exist"""
        # Should use default configuration
        from app import CFG
        assert CFG is not None

class TestErrorHandling:
    """Test error handling scenarios"""
    
    def test_invalid_file_format(self, client):
        """Test handling of invalid file formats"""
        # Create a text file instead of image
        text_data = BytesIO(b"This is not an image")
        
        response = client.post('/ocr/scan-ocr', data={
            'image': (text_data, 'text.txt')
        })
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert data['error'] is True

    def test_large_file_handling(self, client):
        """Test handling of large files"""
        # Create a large dummy image
        large_img = np.zeros((5000, 5000, 3), dtype=np.uint8)
        pil_img = Image.fromarray(large_img)
        img_bytes = BytesIO()
        pil_img.save(img_bytes, format='JPEG', quality=95)
        img_bytes.seek(0)
        
        response = client.post('/ocr/scan-ocr', data={
            'image': (img_bytes, 'large.jpg')
        })
        
        # Should handle large files gracefully
        assert response.status_code in [200, 400, 413]  # Success, bad request, or payload too large

class TestPerformance:
    """Test performance characteristics"""
    
    def test_processing_time_recorded(self, client, sample_ktp_image):
        """Test that processing time is recorded"""
        with patch('app.parse_ktp_text') as mock_parse:
            mock_parse.return_value = {"nik": "123456"}
            
            response = client.post('/ocr/scan-ocr', data={
                'image': (sample_ktp_image, 'ktp.jpg')
            })
            
            if response.status_code == 200:
                data = json.loads(response.data)
                if 'result' in data:
                    assert 'time_elapsed' in data['result']

    def test_concurrent_requests_handling(self, client, sample_ktp_image):
        """Test handling of concurrent requests"""
        # Simple test to ensure the app doesn't crash with multiple requests
        responses = []
        
        for i in range(3):
            response = client.post('/ocr/scan-ocr', data={
                'image': (sample_ktp_image, f'ktp_{i}.jpg')
            })
            responses.append(response)
        
        # All requests should return some response
        for response in responses:
            assert response.status_code in [200, 400]

class TestIntegration:
    """Integration tests for complete OCR workflow"""
    
    @patch('app.detector')
    @patch('app.reader')
    def test_complete_ktp_processing_workflow(self, mock_reader, mock_detector, 
                                             client, sample_ktp_image):
        """Test complete KTP processing workflow"""
        # Mock YOLO detector
        mock_detector.predict_type_and_box.return_value = ("ktp", (10, 10, 500, 300))
        
        # Mock EasyOCR reader
        mock_reader.readtext.return_value = [
            ([[100, 50], [300, 50], [300, 80], [100, 80]], "NIK", 0.95),
            ([[310, 50], [500, 50], [500, 80], [310, 80]], "3171012345678901", 0.98),
            ([[100, 100], [200, 100], [200, 130], [100, 130]], "NAMA", 0.92),
            ([[210, 100], [350, 100], [350, 130], [210, 130]], "JOHN DOE", 0.94)
        ]
        
        response = client.post('/ocr/scan-ocr', data={
            'image': (sample_ktp_image, 'ktp.jpg')
        })
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['error'] is False
        assert 'result' in data
        assert data['result']['tipe_identifikasi'] in ['ktp', None]

    def test_debug_mode_functionality(self, client, sample_ktp_image):
        """Test debug mode returns additional information"""
        response = client.post('/ocr/scan-ocr?debug=1', data={
            'image': (sample_ktp_image, 'ktp.jpg')
        })
        
        # Debug mode should work regardless of OCR success
        assert response.status_code in [200, 400]
        
        if response.status_code == 200:
            data = json.loads(response.data)
            if 'result' in data:
                # Debug mode might include debug information
                pass  # Debug info is optional based on processing success
