from rapidfuzz import process, fuzz

AGAMA = ["ISLAM", "KRISTEN", "KATOLIK", "HINDU", "BUDDHA", "KONGHUCU"]
STATUS = ["BELUM KAWIN", "KAWIN", "CERAI HIDUP", "CERAI MATI"]
ARAH = ["UTARA", "SELATAN", "TIMUR", "BARAT", "TENGAH"]

def fuzzy_pick(token, choices, score_cutoff=80):
    if not token: return None
    cand, score, _ = process.extractOne(token, choices, scorer=fuzz.WRatio) or (None,0,None)
    return cand if score >= score_cutoff else None

def pick_from_text(text, choices, cutoff=80):
    cand, score, _ = process.extractOne((text or ""), choices, scorer=fuzz.WRatio) or (None,0,None)
    return cand if score >= cutoff else None

def normalize_digits(s: str) -> str:
    if not s: return s
    table = str.maketrans({'O':'0','D':'0','Q':'0','I':'1','l':'1','|':'1','!':'1','S':'5','Z':'2','B':'8','G':'6'})
    return s.translate(table)

def collapse_repeats(s: str):
    import re
    return re.sub(r'(.)\1{2,}', r'\1', s or '')

def fix_direction_word(s: str):
    if not s: return s
    parts = s.split()
    if not parts: return s
    last = parts[-1]
    cand = fuzzy_pick(last, ARAH, score_cutoff=85)
    if cand: parts[-1] = cand
    return " ".join(parts)

COMMON_FIXES = {
    "PERKAWITAN": "PERKAWINAN",
    "UTAAA": "UTARA",
    "KECAMATAM": "KECAMATAN",
    "KEL/ DESA": "KEL/DESA",
    "KEL / DESA": "KEL/DESA",
    "KABUPATEM": "KABUPATEN",
}
def clean_common_misreads(s: str) -> str:
    if not s: return s
    up = (s or "").upper()
    for k, v in COMMON_FIXES.items():
        up = up.replace(k, v)
    return up
