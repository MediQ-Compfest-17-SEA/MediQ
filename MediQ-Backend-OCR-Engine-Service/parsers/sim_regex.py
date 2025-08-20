import re
from typing import Dict, Any

UP = lambda s: (s or "").upper()

def _search(pattern, text):
    m = re.search(pattern, text, flags=re.IGNORECASE|re.MULTILINE)
    return m.group(1).strip() if m else None

def parse_sim_text(text: str) -> Dict[str, Any]:
    T = UP(text)
    nomor_sim = None
    m = re.search(r'\b(\d{16}|\d{12,14})\b', T)
    if m: nomor_sim = m.group(1)
    jenis_sim = _search(r'(?:JENIS\s*SIM|GOLONGAN|KELAS)\s*[:\-]?\s*([ABCD][12]?\s*(UMUM)?)', T)
    nama = _search(r'(?:NAMA)\s*[:\-]?\s*([A-Z\'\.\-\s]+)', T)
    ttl = re.search(r'(TEMPAT/?TGL\s*LAHIR|TTL|LAHIR)\s*[:\-]?\s*([A-Z \'\-]+)[,\.\s]*(\d{2}[-/\.]\d{2}[-/\.]\d{4})', T)
    tempat_lahir = ttl.group(2).strip() if ttl else None
    tgl_lahir = ttl.group(3).replace('.', '-').replace('/', '-') if ttl else None
    jk = _search(r'(?:JENIS\s*KELAMIN|JK)\s*[:\-]?\s*([A-Z\- ]+)', T)
    if jk:
        if 'PEREMPUAN' in jk or 'P' == jk.strip(): jk = 'PEREMPUAN'
        else: jk = 'LAKI-LAKI'
    gol = _search(r'(?:GOL(?:\.|ONGAN)?\s*DARAH)\s*[:\-]?\s*([A-Z0-9]+)', T)
    alamat = _search(r'(?:ALAMAT)\s*[:\-]?\s*([A-Z0-9/ \.\-]+)', T)
    pekerjaan = _search(r'(?:PEKERJAAN)\s*[:\-]?\s*([A-Z/ \-]+)', T)
    provinsi = _search(r'(?:PROVINSI)\s*[:\-]?\s*([A-Z \-]+)', T)
    berlaku_hingga = _search(r'(?:BERLAKU\s*(HINGGA|S/D|SAMPAI)|MASA\s*BERLAKU)\s*[:\-]?\s*(\d{2}[-/\.]\d{2}[-/\.]\d{4})', T)
    if berlaku_hingga: berlaku_hingga = berlaku_hingga.replace('.', '-').replace('/', '-')
    return {"nomor_sim": nomor_sim, "jenis_sim": jenis_sim, "nama": nama,
            "tempat_lahir": tempat_lahir, "tgl_lahir": tgl_lahir,
            "jenis_kelamin": jk, "golongan_darah": gol, "alamat": alamat,
            "pekerjaan": pekerjaan, "provinsi": provinsi, "berlaku_hingga": berlaku_hingga}
