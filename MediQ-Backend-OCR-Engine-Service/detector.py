# detector.py (safe extraction for Ultralytics YOLO)
from typing import Optional, Tuple
import numpy as np

try:
    from ultralytics import YOLO
except Exception:
    YOLO = None

TARGET_GROUPS = {
    "ktp": {"ktp_lama", "ktp_baru", "ktp"},
    "sim": {"sim_lama", "sim_baru", "sim"},
}

def _names_dict(names_attr):
    # r.names bisa dict atau list/tuple
    if isinstance(names_attr, dict):
        return names_attr
    if isinstance(names_attr, (list, tuple)):
        return {i: n for i, n in enumerate(names_attr)}
    return {}

def _scalar(x):
    # ambil nilai scalar dari tensor/ndarray/python number
    try:
        # torch tensor
        return float(x.item())
    except Exception:
        pass
    try:
        # numpy scalar
        return float(np.asarray(x).reshape(-1)[0])
    except Exception:
        return float(x)

def _xyxy_from_box(box):
    """
    Ultralytics result.boxes iterasi mengembalikan "box" dengan .xyxy shape (1,4).
    Kita ambil baris [0] lalu tolist dan pastikan 4 angka.
    """
    if not hasattr(box, "xyxy"):
        return None
    xy = getattr(box, "xyxy")
    # to numpy & flatten
    try:
        arr = xy[0].cpu().numpy().reshape(-1)
    except Exception:
        arr = np.array(xy).reshape(-1)
    if arr.size < 4:
        return None
    x1, y1, x2, y2 = [int(v) for v in arr[:4].tolist()]
    return x1, y1, x2, y2

class DocDetector:
    def __init__(self, weights: str, imgsz: int = 640, conf: float = 0.25, device: str = ""):
        if YOLO is None:
            raise RuntimeError("Ultralytics YOLO belum terpasang. pip install -U ultralytics")
        self.model = YOLO(weights)
        self.imgsz = imgsz
        self.conf = conf
        self.device = device

    def predict_type_and_box(self, bgr) -> Tuple[Optional[str], Optional[Tuple[int,int,int,int]]]:
        # Hasil bisa list of Results
        results = self.model.predict(source=bgr, imgsz=self.imgsz, conf=self.conf, device=self.device, verbose=False)
        best_name, best_score, best_box = None, -1.0, None

        for r in results:
            boxes = getattr(r, "boxes", None)
            if boxes is None:
                continue
            names = _names_dict(getattr(r, "names", {}))
            # iterasi tiap box
            for box in boxes:
                # koordinat aman
                coords = _xyxy_from_box(box)
                if coords is None:
                    continue
                x1, y1, x2, y2 = coords

                # conf & cls aman
                conf_val = getattr(box, "conf", None)
                cls_val  = getattr(box, "cls", None)
                if conf_val is None or cls_val is None:
                    continue
                try:
                    conf = _scalar(conf_val[0])
                except Exception:
                    conf = _scalar(conf_val)
                try:
                    cls_idx = int(_scalar(cls_val[0]))
                except Exception:
                    cls_idx = int(_scalar(cls_val))

                cls_name = str(names.get(cls_idx, cls_idx)).lower()

                if conf > best_score:
                    best_name, best_score, best_box = cls_name, conf, (x1, y1, x2, y2)

        if best_name is None:
            return None, None

        # Normalisasi ke grup 'ktp' atau 'sim'
        for g, name_set in TARGET_GROUPS.items():
            if any(n in best_name for n in name_set):
                return g, best_box
        if "ktp" in best_name:
            return "ktp", best_box
        if "sim" in best_name:
            return "sim", best_box
        return None, best_box
