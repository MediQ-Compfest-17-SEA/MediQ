import os, sys, time, yaml, re
sys.path.insert(0, os.path.dirname(__file__))

from flask import Flask, request, jsonify
from flask_restx import Api, Resource, fields
from werkzeug.datastructures import FileStorage
from PIL import Image
import numpy as np
import cv2
import easyocr

from utils.image_ops import read_bgr, ensure_min_width, rectify_card, variants_for_ocr, save_debug
from detector import DocDetector
from parsers.ktp_regex import parse_ktp_text
from parsers.sim_regex import parse_sim_text
from utils.postprocess import normalize_digits

CFG = {
    "yolo":{"weights":"runs/detect_train/weights/best.pt","imgsz":640,"conf":0.25,"use_type":True},
    "ocr":{"langs":["id","en"],"min_width":1400,"debug_dir":"debug_out","text_threshold":0.7,"low_text":0.3,"slope_ths":0.2,"mag_ratio":1.5},
    "heuristic_roi":{"ktp_left_ratio":0.78,"nik_top_ratio":0.22},
    "server":{"host":"0.0.0.0","port":8000,"debug":False}
}
cfg_path = os.getenv("PIN_OCR_CONFIG","config.yaml")
if os.path.exists(cfg_path):
    with open(cfg_path,"r",encoding="utf-8") as f:
        user_cfg = yaml.safe_load(f) or {}
    for k in CFG:
        if k in user_cfg and isinstance(user_cfg[k],dict):
            CFG[k].update(user_cfg[k])

# init OCR reader
try:
    reader = easyocr.Reader(CFG["ocr"]["langs"], gpu=True)
except Exception:
    reader = easyocr.Reader(CFG["ocr"]["langs"], gpu=False)

app = Flask(__name__)

# Swagger API documentation setup
api = Api(
    app,
    version='1.0',
    title='MediQ OCR Engine Service',
    description='Advanced OCR engine untuk pemrosesan KTP dan SIM menggunakan YOLO + EasyOCR',
    doc='/docs'
)

# API namespaces
ns_ocr = api.namespace('ocr', description='OCR Processing operations')
ns_health = api.namespace('health', description='Health check operations')

# Swagger models
ocr_response_model = api.model('OCRResponse', {
    'error': fields.Boolean(description='Status error', example=False),
    'message': fields.String(description='Response message', example='Proses OCR Berhasil'),
    'result': fields.Raw(description='OCR hasil data')
})

upload_parser = api.parser()
upload_parser.add_argument('image', location='files', type=FileStorage, required=True, help='KTP atau SIM image file')

detector = None
try:
    if CFG["yolo"].get("use_type", True):
        detector = DocDetector(
            CFG["yolo"]["weights"],
            CFG["yolo"]["imgsz"],
            CFG["yolo"]["conf"],
            device=CFG["yolo"].get("device", "0"),
        )
except Exception as e:
    print("[WARN] YOLO init failed:", e); detector=None

def score_text_id(text):
    T = (text or "").upper()
    tokens = ["PROVINSI","KOTA","KABUPATEN","NIK","NAMA","TEMPAT","LAHIR","JENIS","KELAMIN",
              "ALAMAT","AGAMA","STATUS","PEKERJAAN","KEWARGANEGARAAN","BERLAKU"]
    s = sum(1 for t in tokens if t in T)
    digits = sum(ch.isdigit() for ch in T)
    s2 = 1 if digits >= 10 else 0
    return s + s2

def easy_read_tokens(img_bgr):
    # Run EasyOCR and return tokens: text, conf, bbox, cx, cy, h, w
    rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    res = reader.readtext(
        rgb,
        detail=1,
        paragraph=False,
        text_threshold=CFG["ocr"]["text_threshold"],
        low_text=CFG["ocr"]["low_text"],
        slope_ths=CFG["ocr"]["slope_ths"],
        mag_ratio=CFG["ocr"]["mag_ratio"]
    )
    out = []
    for (bbox, text, conf) in res:
        xs = [p[0] for p in bbox]; ys = [p[1] for p in bbox]
        x1,y1,x2,y2 = min(xs), min(ys), max(xs), max(ys)
        cx, cy = (x1+x2)/2.0, (y1+y2)/2.0
        out.append({"text":text, "conf":float(conf), "bbox":(x1,y1,x2,y2), "cx":cx, "cy":cy, "h":(y2-y1), "w":(x2-x1)})
    return out

def tokens_to_text(tokens):
    if not tokens: return ""
    toks = sorted(tokens, key=lambda t: (round(t["cy"]/20), t["cx"]))
    lines, cur, cur_ybin = [], [], None
    for t in toks:
        ybin = round(t["cy"]/20)
        if cur_ybin is None: cur_ybin = ybin
        if ybin != cur_ybin:
            lines.append(" ".join(x["text"] for x in cur))
            cur = [t]; cur_ybin = ybin
        else:
            cur.append(t)
    if cur: lines.append(" ".join(x["text"] for x in cur))
    return "\n".join(lines)

def easy_sweep(img_bgr, save_prefix=None):
    best = {"score":-1, "text":"", "tokens":None, "which":None}
    for vname, var in variants_for_ocr(img_bgr):
        if len(var.shape)==2:
            var_rgb = cv2.cvtColor(var, cv2.COLOR_GRAY2BGR)
        else:
            var_rgb = var
        tokens = easy_read_tokens(var_rgb)
        text = tokens_to_text(tokens)
        sc = score_text_id(text)
        if sc > best["score"]:
            best = {"score":sc, "text":text, "tokens":tokens, "which":vname}
        if save_prefix:
            save_debug(var, f'{CFG["ocr"]["debug_dir"]}/{save_prefix}_{vname}.png')
    return best

def crop_panel_and_nik(rect):
    h,w = rect.shape[:2]
    left_w = int(w * CFG["heuristic_roi"]["ktp_left_ratio"])
    panel = rect[:, :left_w].copy()
    nik_h = int(panel.shape[0] * CFG["heuristic_roi"]["nik_top_ratio"])
    nik_band = panel[:nik_h, :].copy()
    return panel, nik_band

def ocr_nik_by_anchor_easyocr(tokens):
    if not tokens: return None
    for t in sorted(tokens, key=lambda x: x["cx"]):
        w = (t["text"] or "").strip().upper().replace(":", "")
        if w in {"NIK","N1K","N|K"}:
            x1,y1,x2,y2 = t["bbox"]
            line_y = (y1+y2)/2.0
            same_line = [u for u in tokens if (abs(u["cy"]-line_y) <= max(t["h"], u["h"])*0.7) and (u["cx"] > x2+5)]
            same_line = sorted(same_line, key=lambda u: u["cx"])
            raw = " ".join(u["text"] for u in same_line)
            digits = re.findall(r"\d", normalize_digits(raw))
            if len(digits) >= 12:
                s = "".join(digits)
                return s[:16] if len(s) >= 16 else s
    raw_all = " ".join(tt["text"] for tt in tokens)
    m = re.search(r"\b(\d{16})\b", normalize_digits(raw_all))
    return m.group(1) if m else None

@ns_health.route('/')
class HealthRoot(Resource):
    def get(self):
        """Service information"""
        return {
            "name": "MediQ OCR Engine Service",
            "version": "4.0.1", 
            "yolo_loaded": detector is not None,
            "port": CFG["server"]["port"],
            "languages": CFG["ocr"]["langs"]
        }

@ns_health.route('/health')
class Health(Resource):
    def get(self):
        """Health check endpoint"""
        return {
            "status": "healthy",
            "service": "ocr-engine",
            "timestamp": time.time(),
            "yolo_status": "loaded" if detector else "disabled",
            "ocr_status": "ready"
        }

@ns_ocr.route('/scan-ocr')
class OCRProcess(Resource):
    @api.expect(upload_parser)
    @api.marshal_with(ocr_response_model)
    def post(self):
        """Process KTP atau SIM image menggunakan YOLO + EasyOCR"""
    t0=time.time()
    f = request.files.get("image")
    if not f: return jsonify({"error":True,"message":"Parameter 'image' wajib diisi","result":None}),400
    img_bytes = f.read()
    bgr = read_bgr(img_bytes)
    if bgr is None: return jsonify({"error":True,"message":"Gagal membaca gambar","result":None}),400

    bgr = ensure_min_width(bgr, min_width=CFG["ocr"]["min_width"])
    rect = rectify_card(bgr)

    doc_type=None; box=None
    if detector is not None and CFG["yolo"].get("use_type", True):
        try:
            doc_type, box = detector.predict_type_and_box(rect)
        except Exception as e:
            print("[WARN] YOLO predict error:", e)

    panel, nik_band = crop_panel_and_nik(rect)

    best_panel = easy_sweep(panel, save_prefix="panel")
    best_full  = easy_sweep(rect,  save_prefix="full")

    tokens_nik = easy_read_tokens(nik_band)
    raw_nik = " ".join(t["text"] for t in tokens_nik)
    digits = re.findall(r"\d", normalize_digits(raw_nik))
    nik_best = {"score": len(digits), "digits": "".join(digits)}

    text = best_panel["text"] if best_panel["score"] >= max(2, best_full["score"]) else best_full["text"]
    tokens_full = best_full["tokens"] if text == best_full["text"] else best_panel["tokens"]

    TUP = (text or "").upper()
    if doc_type is None:
        if ("SURAT IZIN MENGEMUDI" in TUP) or re.search(r'\bSIM\b', TUP): doc_type="sim"
        elif ("KARTU TANDA PENDUDUK" in TUP) or ("NIK" in TUP): doc_type="ktp"

    nik_anchor = ocr_nik_by_anchor_easyocr(tokens_full)

    if doc_type=="sim":
        result = parse_sim_text(text)
    else:
        result = parse_ktp_text(text)
        if not result.get("nik"):
            if nik_anchor and len(nik_anchor) >= 12:
                result["nik"] = nik_anchor[:16]
            elif nik_best["score"] >= 12:
                s = nik_best["digits"]
                result["nik"] = s[:16] if len(s) >= 16 else s
        doc_type = "ktp" if doc_type is None else doc_type

    elapsed = f"{time.time()-t0:.3f}"
    result["tipe_identifikasi"] = doc_type
    result["time_elapsed"] = elapsed

    debug_mode = request.args.get("debug") in ("1","true","yes")
    if debug_mode:
        result["debug"] = {
            "panel": {"which": best_panel["which"], "score": best_panel["score"]},
            "full":  {"which": best_full["which"],  "score": best_full["score"]},
            "nik_digits": nik_best["score"]
        }

    if result.get("tipe_identifikasi") is None:
        return jsonify({"error":False,"message":"Tidak dapat menentukan tipe dokumen (KTP/SIM)",
                        "result":result}),200

        return {"error": False, "message": "Proses OCR Berhasil", "result": result}

# Legacy endpoints for backward compatibility
@app.route("/")
def index():
    return jsonify({"name":"MediQ OCR Engine Service","version":"4.0.1","yolo_loaded": detector is not None})

@app.route("/healthz")  
def healthz():
    return jsonify({"ok": True})

@app.route("/ocr", methods=["POST"])
def ocr_legacy():
    """Legacy OCR endpoint for backward compatibility"""
    return OCRProcess().post()

if __name__=="__main__":
    # Update port ke 8604 untuk consistency dengan arsitektur MediQ
    port = int(os.getenv("PORT", CFG["server"]["port"]))
    if port == 8000:  # Update default port
        port = 8604
    app.run(host=CFG["server"]["host"], port=port, debug=CFG["server"]["debug"])
