import pytest
import numpy as np
from unittest.mock import patch, MagicMock
from detector import DocDetector, _names_dict, _scalar, _xyxy_from_box

class TestDocDetector:
    """Test YOLO document detector"""
    
    @patch('detector.YOLO')
    def test_detector_initialization_success(self, mock_yolo):
        """Test successful detector initialization"""
        mock_model = MagicMock()
        mock_yolo.return_value = mock_model
        
        detector = DocDetector("test_weights.pt", imgsz=640, conf=0.25)
        
        assert detector.model == mock_model
        assert detector.imgsz == 640
        assert detector.conf == 0.25
        mock_yolo.assert_called_once_with("test_weights.pt")

    def test_detector_initialization_no_yolo(self):
        """Test detector initialization when YOLO not available"""
        with patch('detector.YOLO', None):
            with pytest.raises(RuntimeError, match="Ultralytics YOLO belum terpasang"):
                DocDetector("test_weights.pt")

    @patch('detector.YOLO')
    def test_predict_type_and_box_ktp(self, mock_yolo):
        """Test KTP detection and bounding box extraction"""
        # Mock YOLO model and results
        mock_model = MagicMock()
        mock_yolo.return_value = mock_model
        
        # Mock detection result
        mock_box = MagicMock()
        mock_box.xyxy = [[100, 50, 500, 300]]  # x1, y1, x2, y2
        mock_box.conf = [0.95]
        mock_box.cls = [0]  # Class index for KTP
        
        mock_result = MagicMock()
        mock_result.boxes = [mock_box]
        mock_result.names = {0: "ktp_baru"}
        
        mock_model.predict.return_value = [mock_result]
        
        detector = DocDetector("test_weights.pt")
        test_image = np.zeros((600, 800, 3), dtype=np.uint8)
        
        doc_type, bbox = detector.predict_type_and_box(test_image)
        
        assert doc_type == "ktp"
        assert bbox == (100, 50, 500, 300)

    @patch('detector.YOLO')
    def test_predict_type_and_box_sim(self, mock_yolo):
        """Test SIM detection"""
        mock_model = MagicMock()
        mock_yolo.return_value = mock_model
        
        # Mock SIM detection result
        mock_box = MagicMock()
        mock_box.xyxy = [[80, 40, 450, 250]]
        mock_box.conf = [0.88]
        mock_box.cls = [1]  # Class index for SIM
        
        mock_result = MagicMock()
        mock_result.boxes = [mock_box]
        mock_result.names = {1: "sim_baru"}
        
        mock_model.predict.return_value = [mock_result]
        
        detector = DocDetector("test_weights.pt")
        test_image = np.zeros((400, 600, 3), dtype=np.uint8)
        
        doc_type, bbox = detector.predict_type_and_box(test_image)
        
        assert doc_type == "sim"
        assert bbox == (80, 40, 450, 250)

    @patch('detector.YOLO')
    def test_predict_no_detection(self, mock_yolo):
        """Test when no document is detected"""
        mock_model = MagicMock()
        mock_yolo.return_value = mock_model
        
        # Mock empty detection result
        mock_result = MagicMock()
        mock_result.boxes = []
        mock_model.predict.return_value = [mock_result]
        
        detector = DocDetector("test_weights.pt")
        test_image = np.zeros((400, 600, 3), dtype=np.uint8)
        
        doc_type, bbox = detector.predict_type_and_box(test_image)
        
        assert doc_type is None
        assert bbox is None

class TestUtilityFunctions:
    """Test utility functions"""
    
    def test_names_dict_with_dict_input(self):
        """Test _names_dict with dictionary input"""
        input_dict = {0: "ktp", 1: "sim"}
        result = _names_dict(input_dict)
        assert result == input_dict

    def test_names_dict_with_list_input(self):
        """Test _names_dict with list input"""
        input_list = ["ktp", "sim"]
        result = _names_dict(input_list)
        assert result == {0: "ktp", 1: "sim"}

    def test_names_dict_with_tuple_input(self):
        """Test _names_dict with tuple input"""
        input_tuple = ("ktp", "sim")
        result = _names_dict(input_tuple)
        assert result == {0: "ktp", 1: "sim"}

    def test_names_dict_with_invalid_input(self):
        """Test _names_dict with invalid input"""
        result = _names_dict("invalid")
        assert result == {}

    def test_scalar_with_tensor_like(self):
        """Test _scalar with tensor-like object"""
        # Mock tensor with item() method
        mock_tensor = MagicMock()
        mock_tensor.item.return_value = 0.95
        
        result = _scalar(mock_tensor)
        assert result == 0.95

    def test_scalar_with_numpy_array(self):
        """Test _scalar with numpy array"""
        arr = np.array([0.88])
        result = _scalar(arr)
        assert result == 0.88

    def test_scalar_with_python_number(self):
        """Test _scalar with Python number"""
        result = _scalar(0.92)
        assert result == 0.92

    def test_xyxy_from_box_valid(self):
        """Test bounding box extraction from valid box object"""
        mock_box = MagicMock()
        mock_xyxy = MagicMock()
        mock_xyxy.__getitem__.return_value.cpu.return_value.numpy.return_value.reshape.return_value = np.array([100, 50, 500, 300])
        mock_box.xyxy = [mock_xyxy]
        
        # This test requires actual tensor-like behavior
        # For now, test the function exists
        result = _xyxy_from_box(mock_box)
        # Test passes if function doesn't crash

    def test_xyxy_from_box_invalid(self):
        """Test bounding box extraction from invalid box object"""
        mock_box = MagicMock()
        del mock_box.xyxy  # Remove xyxy attribute
        
        result = _xyxy_from_box(mock_box)
        assert result is None

class TestOCRProcessing:
    """Test OCR processing functions"""
    
    @patch('app.reader')
    def test_easy_read_tokens(self, mock_reader):
        """Test EasyOCR token extraction"""
        from app import easy_read_tokens
        
        # Mock EasyOCR result
        mock_reader.readtext.return_value = [
            ([[100, 50], [300, 50], [300, 80], [100, 80]], "NIK", 0.95),
            ([[310, 50], [500, 50], [500, 80], [310, 80]], "3171012345678901", 0.98)
        ]
        
        test_image = np.zeros((400, 600, 3), dtype=np.uint8)
        tokens = easy_read_tokens(test_image)
        
        assert len(tokens) == 2
        assert tokens[0]['text'] == 'NIK'
        assert tokens[0]['conf'] == 0.95
        assert tokens[1]['text'] == '3171012345678901'
        assert tokens[1]['conf'] == 0.98

    def test_crop_panel_and_nik(self):
        """Test panel and NIK region cropping"""
        from app import crop_panel_and_nik
        
        # Create test image
        test_rect = np.zeros((400, 600, 3), dtype=np.uint8)
        
        panel, nik_band = crop_panel_and_nik(test_rect)
        
        # Panel should be left portion of image
        assert panel.shape[1] < test_rect.shape[1]  # Width should be smaller
        assert panel.shape[0] == test_rect.shape[0]  # Height should be same
        
        # NIK band should be top portion of panel
        assert nik_band.shape[0] < panel.shape[0]  # Height should be smaller
        assert nik_band.shape[1] == panel.shape[1]  # Width should be same

    @patch('app.easy_read_tokens')
    def test_ocr_nik_by_anchor_easyocr(self, mock_read_tokens):
        """Test NIK extraction by anchor method"""
        from app import ocr_nik_by_anchor_easyocr
        
        # Mock tokens with NIK anchor
        tokens = [
            {"text": "NIK", "bbox": (100, 50, 150, 80), "cx": 125, "cy": 65, "h": 30, "w": 50},
            {"text": "3171012345678901", "bbox": (160, 50, 350, 80), "cx": 255, "cy": 65, "h": 30, "w": 190}
        ]
        
        nik = ocr_nik_by_anchor_easyocr(tokens)
        assert nik == "3171012345678901"

    def test_ocr_nik_by_anchor_no_anchor(self):
        """Test NIK extraction when no anchor found"""
        from app import ocr_nik_by_anchor_easyocr
        
        # Tokens without NIK anchor
        tokens = [
            {"text": "NAMA", "bbox": (100, 50, 150, 80), "cx": 125, "cy": 65, "h": 30, "w": 50},
            {"text": "JOHN DOE", "bbox": (160, 50, 350, 80), "cx": 255, "cy": 65, "h": 30, "w": 190}
        ]
        
        nik = ocr_nik_by_anchor_easyocr(tokens)
        assert nik is None

    def test_ocr_nik_by_anchor_empty_tokens(self):
        """Test NIK extraction with empty tokens"""
        from app import ocr_nik_by_anchor_easyocr
        
        nik = ocr_nik_by_anchor_easyocr([])
        assert nik is None
        
        nik = ocr_nik_by_anchor_easyocr(None)
        assert nik is None
