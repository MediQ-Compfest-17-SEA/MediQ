import cv2
import numpy as np
import os

def read_bgr(file_bytes: bytes):
    arr = np.frombuffer(file_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return img

def ensure_min_width(bgr, min_width=1100):
    # Upscale menjaga aspect ratio hingga lebar minimal tercapai.
    h, w = bgr.shape[:2]
    if w >= min_width:
        return bgr
    scale = float(min_width) / float(w)
    return cv2.resize(bgr, (int(w*scale), int(h*scale)), interpolation=cv2.INTER_CUBIC)

def _unsharp_mask(gray):
    blur = cv2.GaussianBlur(gray, (0, 0), 3)
    sharp = cv2.addWeighted(gray, 1.5, blur, -0.5, 0)
    return sharp

def _clahe(gray):
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    return clahe.apply(gray)

def _order_points(pts):
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect

def rectify_card(bgr):
    # Perbaiki perspektif kartu menggunakan kontur terbesar 4-sudut bila memungkinkan.
    try:
        s = max(1, int(round(1000 / max(bgr.shape[:2]))))
        small = cv2.resize(bgr, (bgr.shape[1]//s, bgr.shape[0]//s))
        gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(gray, 60, 150)
        cnts, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not cnts:
            return bgr
        cnt = max(cnts, key=cv2.contourArea)
        peri = cv2.arcLength(cnt, True)
        approx = cv2.approxPolyDP(cnt, 0.02*peri, True)
        if len(approx) != 4:
            return bgr
        pts = approx.reshape(4, 2).astype(np.float32) * s
        rect = _order_points(pts)
        (tl, tr, br, bl) = rect
        widthA = np.linalg.norm(br - bl)
        widthB = np.linalg.norm(tr - tl)
        heightA = np.linalg.norm(tl - bl)
        heightB = np.linalg.norm(tr - br)
        maxW = int(max(widthA, widthB))
        maxH = int(max(heightA, heightB))
        dst = np.array([[0, 0], [maxW-1, 0], [maxW-1, maxH-1], [0, maxH-1]], dtype=np.float32)
        M = cv2.getPerspectiveTransform(rect, dst)
        warp = cv2.warpPerspective(bgr, M, (maxW, maxH))
        return warp
    except Exception:
        return bgr

def variants_for_ocr(bgr):
    # Hasilkan beberapa varian biner untuk OCR.
    out = []
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    gray = _clahe(gray)
    gray = _unsharp_mask(gray)

    # Adaptive Gaussian
    adapt = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                  cv2.THRESH_BINARY, 35, 15)
    out.append(("adapt", adapt))

    # OTSU
    _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY+cv2.THRESH_OTSU)
    out.append(("otsu", otsu))

    # OTSU inverted
    _, otsu_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV+cv2.THRESH_OTSU)
    out.append(("otsu_inv", otsu_inv))

    # Morph close on otsu to connect strokes
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3,3))
    close = cv2.morphologyEx(otsu, cv2.MORPH_CLOSE, kernel, iterations=1)
    out.append(("otsu_close", close))

    return out

def save_debug(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cv2.imwrite(path, img)
