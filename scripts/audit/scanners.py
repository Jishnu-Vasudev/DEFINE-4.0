"""Content-safety checks run by the audit service. All models run locally (no network).

text   -> alt-profanity-check (linear model trained on ~200k labelled toxic comments)
images -> NudeNet 320n ONNX detector (onnxruntime)
files  -> magic-byte signature vs declared extension, high-risk types, macro documents
"""
import io
import os
import zipfile

HIGH_RISK_EXT = {"exe", "msi", "apk", "sh", "bat", "cmd", "ps1", "vbs", "js", "jar", "scr", "com", "dll", "elf",
                 "docm", "xlsm", "pptm", "dotm", "xlam"}
EXPOSED = {"FEMALE_BREAST_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "BUTTOCKS_EXPOSED", "ANUS_EXPOSED"}
FAMILY_EXT = {"pdf": {"pdf"}, "png": {"png"}, "jpeg": {"jpg", "jpeg"}, "gif": {"gif"}, "webp": {"webp"}, "wav": {"wav"},
              "ogg": {"ogg", "opus"}, "mp3": {"mp3"}, "flac": {"flac"}, "mp4": {"mp4", "mov", "3gp", "m4a", "aac"},
              "webm": {"webm", "mkv"}, "docx": {"docx", "docm", "dotm"}, "xlsx": {"xlsx", "xlsm", "xlam"}, "pptx": {"pptx", "pptm"},
              "zip": {"zip", "odt", "ods"}, "apk": {"apk"}, "jar": {"jar"}, "exe": {"exe", "msi", "dll", "scr", "com"},
              "elf": {"elf"}, "ole": {"doc", "xls", "ppt", "msi"}, "rtf": {"rtf"}, "script": {"sh", "bat", "cmd", "ps1", "vbs", "js"},
              "text": {"txt", "csv", "json", "md", "log", "sh", "bat", "cmd", "ps1", "vbs", "js"}}
MIME = {"pdf": "application/pdf", "png": "image/png", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp",
        "wav": "audio/wav", "ogg": "audio/ogg", "mp3": "audio/mpeg", "flac": "audio/flac", "mp4": "video/mp4", "webm": "video/webm",
        "text": "text/plain", "rtf": "application/rtf"}
EXEC_FAMILIES = {"exe", "elf", "apk", "jar", "script"}

_tox = None
_nude = None


def detect_family(data):
    h = data[:16]
    if h.startswith(b"%PDF"): return "pdf"
    if h.startswith(b"\x89PNG\r\n\x1a\n"): return "png"
    if h.startswith(b"\xff\xd8\xff"): return "jpeg"
    if h.startswith(b"GIF8"): return "gif"
    if h.startswith(b"RIFF") and data[8:12] == b"WEBP": return "webp"
    if h.startswith(b"RIFF") and data[8:12] == b"WAVE": return "wav"
    if h.startswith(b"OggS"): return "ogg"
    if h.startswith(b"ID3") or h[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"): return "mp3"
    if h.startswith(b"fLaC"): return "flac"
    if data[4:8] == b"ftyp": return "mp4"
    if h.startswith(b"\x1a\x45\xdf\xa3"): return "webm"
    if h.startswith(b"MZ"): return "exe"
    if h.startswith(b"\x7fELF"): return "elf"
    if h.startswith(b"\xd0\xcf\x11\xe0"): return "ole"
    if h.startswith(b"{\\rtf"): return "rtf"
    if h.startswith(b"#!"): return "script"
    if h.startswith(b"PK\x03\x04"):
        try:
            names = zipfile.ZipFile(io.BytesIO(data)).namelist()
        except zipfile.BadZipFile:
            return "zip"
        if "AndroidManifest.xml" in names or "classes.dex" in names: return "apk"
        if any(n.startswith("word/") for n in names): return "docx"
        if any(n.startswith("xl/") for n in names): return "xlsx"
        if any(n.startswith("ppt/") for n in names): return "pptx"
        if "META-INF/MANIFEST.MF" in names: return "jar"
        return "zip"
    try:
        data[:4096].decode("utf-8")
        return "text"
    except UnicodeDecodeError:
        return "unknown"


def has_macros(data):
    try:
        return any(n.lower().endswith("vbaproject.bin") for n in zipfile.ZipFile(io.BytesIO(data)).namelist())
    except zipfile.BadZipFile:
        return False


def file_guard(name, data):
    """Returns (family, mime, flags, severity, risk_reason)."""
    ext = os.path.splitext(name or "")[1].lstrip(".").lower()
    fam = detect_family(data)
    flags, sev, why = [], 0, []
    if ext in HIGH_RISK_EXT or fam in EXEC_FAMILIES:
        flags.append("hazard"); sev = 2; why.append("executable or script")
    if fam in ("docx", "xlsx", "pptx", "ole") and (ext in {"docm", "xlsm", "pptm", "dotm", "xlam"} or has_macros(data)):
        flags.append("macro"); sev = 2; why.append("document with macros")
    if ext and fam not in ("unknown", "zip", "text") and ext not in FAMILY_EXT.get(fam, set()):
        flags.append("mismatch"); sev = max(sev, 2 if fam in EXEC_FAMILIES else 1)
        why.append(f"named .{ext} but the content is {fam}")
    if fam == "unknown":
        flags.append("unknown_binary"); sev = max(sev, 1); why.append("unrecognised binary")
    return fam, MIME.get(fam, "application/octet-stream"), flags, sev, "; ".join(why)


def text_scan(text):
    global _tox
    if not text or not text.strip():
        return [], 0, 0.0
    if _tox is None:
        from profanity_check import predict_prob
        _tox = predict_prob
    p = float(_tox([text])[0])
    if p >= 0.9: return ["toxic"], 2, p
    if p >= 0.7: return ["toxic"], 1, p
    return [], 0, p


def image_scan(path):
    """Returns (flags, severity, top_score, labels)."""
    global _nude
    if _nude is None:
        from nudenet import NudeDetector
        _nude = NudeDetector()
    hits = [d for d in _nude.detect(path) if d["class"] in EXPOSED and d["score"] >= 0.45]
    if not hits:
        return [], 0, 0.0, []
    return ["nudity"], 2, max(d["score"] for d in hits), sorted({d["class"] for d in hits})
