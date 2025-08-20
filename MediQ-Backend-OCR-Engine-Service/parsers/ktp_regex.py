import re
from typing import Dict, Any
from utils.postprocess import (
    fuzzy_pick, normalize_digits, collapse_repeats, fix_direction_word,
    pick_from_text, clean_common_misreads, AGAMA, STATUS
)

UP = lambda s: (s or "").upper()

def _search(pattern, text):
    m = re.search(pattern, text, flags=re.IGNORECASE|re.MULTILINE)
    return m.group(1).strip() if m else None

def _after_label(T: str, label_regex: str):
    pat = rf"{label_regex}\s*[:\-]?\s*([A-Z0-9/ \.,\-]+)"
    return _search(pat, T)

def parse_ktp_text(text: str) -> Dict[str, Any]:
    T = UP(text)
    T = clean_common_misreads(collapse_repeats(T))

    T_digits = normalize_digits(T)
    nik_match = re.search(r'\b(\d{16})\b', T_digits)
    nik = nik_match.group(1) if nik_match else None

    nama = _after_label(T, r'(?:NAMA|NAM4|N0MA)')
    ttl = re.search(r'(?:TEMPAT/?TGL\s*LAHIR|TEMPAT\s*LAHIR|TTL)\s*[:\-]?\s*([A-Z \'\-]+?)[,\.\s]+\s*(\d{2}[\-/. ]\d{2}[\-/. ]\d{4})', T)
    tempat_lahir = ttl.group(1).strip() if ttl else None
    tgl_lahir = ttl.group(2).replace('.', '-').replace('/', '-').replace(' ', '-') if ttl else None

    jk = _after_label(T, r'(?:JENIS\s*KELAMIN|JK)')
    if jk:
        jk = 'PEREMPUAN' if 'PEREMPUAN' in jk or jk.strip() == 'P' else 'LAKI-LAKI'
    else:
        if re.search(r'\bPEREMPUAN\b', T): jk = 'PEREMPUAN'
        elif re.search(r'\bLAKI(?:-|\s*)LAKI\b', T): jk = 'LAKI-LAKI'
        else: jk = None

    agama_raw = _after_label(T, r'AGAMA')
    agama = fuzzy_pick((agama_raw or '').strip(), AGAMA) or pick_from_text(T, AGAMA, cutoff=88) or (agama_raw or '')

    status_raw = _after_label(T, r'STATUS(?:\s*PERKAWINAN)?')
    status = fuzzy_pick((status_raw or '').strip(), STATUS) or pick_from_text(T, STATUS, cutoff=88) or (status_raw or '')

    pekerjaan = _after_label(T, r'PEKERJAAN') or ""

    kewarganegaraan = _after_label(T, r'KEWARGANEGARAAN')
    if kewarganegaraan:
        kewarganegaraan = 'WNI' if 'WNI' in kewarganegaraan else ('WNA' if 'WNA' in kewarganegaraan else kewarganegaraan)

    alamat_name = _after_label(T, r'ALAMAT')
    if alamat_name: alamat_name = collapse_repeats(alamat_name)

    rt_rw = _after_label(T_digits, r'(?:RT/?RW|RTRW)')
    if rt_rw:
        rt_rw = rt_rw.replace('O','0').replace('I','1').replace('l','1')

    kel_desa = _after_label(T, r'(?:KEL/?DESA|KELURAHAN|DESA)')
    kecamatan = _after_label(T, r'KECAMATAN')
    kab = _after_label(T, r'(?:KABUPATEN|KOTA)')
    prov = _after_label(T, r'PROVINSI')

    if kecamatan: kecamatan = fix_direction_word(kecamatan)
    if kab: kab = fix_direction_word(kab)

    return {
        "nik": nik,
        "nama": nama,
        "tempat_lahir": tempat_lahir,
        "tgl_lahir": tgl_lahir,
        "jenis_kelamin": jk,
        "agama": agama,
        "status_perkawinan": status,
        "pekerjaan": pekerjaan,
        "kewarganegaraan": kewarganegaraan,
        "alamat": {
            "name": alamat_name,
            "rt_rw": rt_rw,
            "kel_desa": kel_desa,
            "kecamatan": kecamatan,
            "kabupaten": kab,
            "provinsi": prov
        }
    }
