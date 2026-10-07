"""자막 파일 파서: SRT / VTT / SMI / ASS -> [{"name": str, "cues": [[start_ms, end_ms, text], ...]}]"""
import os
import re

LANG_NAMES = {
    "ko": "한국어", "kor": "한국어", "kr": "한국어", "krcc": "한국어", "korean": "한국어",
    "en": "English", "eng": "English", "encc": "English", "english": "English",
    "ja": "日本語", "jp": "日本語", "jpn": "日本語", "jpcc": "日本語", "japanese": "日本語",
    "zh": "中文", "chi": "中文", "zho": "中文", "cn": "中文", "zhcc": "中文",
    "es": "Español", "fr": "Français", "de": "Deutsch", "ru": "Русский",
}
EXTS = (".srt", ".smi", ".sami", ".vtt", ".ass", ".ssa")

_TIME = re.compile(
    r"(?:(\d+):)?(\d+):(\d+)[.,](\d{1,3})\s*-->\s*(?:(\d+):)?(\d+):(\d+)[.,](\d{1,3})")
_TAG = re.compile(r"<[^>]+>|\{[^}]*\}")


def _decode(data: bytes) -> str:
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16", errors="replace")
    for enc in ("utf-8-sig", "cp949"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return data.decode("latin-1", errors="replace")


def _ms(h, m, s, frac):
    return (int(h or 0) * 3600 + int(m) * 60 + int(s)) * 1000 + int(frac.ljust(3, "0")[:3])


def _clean(t: str) -> str:
    t = t.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    t = re.sub(r"(?i)<br\s*/?>", "\n", t)
    t = _TAG.sub("", t)
    return "\n".join(x.strip() for x in t.strip().splitlines() if x.strip())


def parse_srt_vtt(text: str):
    cues = []
    for block in re.split(r"\r?\n\s*\r?\n", text.replace("﻿", "")):
        lines = block.strip().splitlines()
        for i, ln in enumerate(lines):
            m = _TIME.search(ln)
            if m:
                g = m.groups()
                body = _clean("\n".join(lines[i + 1:]))
                if body:
                    cues.append([_ms(g[0], g[1], g[2], g[3]), _ms(g[4], g[5], g[6], g[7]), body])
                break
    return cues


def parse_smi(text: str):
    """클래스(KRCC/ENCC 등)별로 분리해 {클래스: cues} 로 반환"""
    per = {}
    for m in re.finditer(r"<SYNC\s+Start\s*=\s*(\d+)[^>]*>(.*?)(?=<SYNC|\Z)", text, re.I | re.S):
        start = int(m.group(1))
        chunk = m.group(2)
        parts = re.split(r"(?i)<P\b", chunk)
        found = False
        for p in parts[1:]:
            cm = re.match(r"[^>]*?Class\s*=\s*[\"']?(\w+)", p, re.I)
            cls = cm.group(1).upper() if cm else "DEFAULT"
            body = _clean(p.split(">", 1)[1] if ">" in p else "")
            per.setdefault(cls, []).append((start, body))
            found = True
        if not found:
            per.setdefault("DEFAULT", []).append((start, _clean(chunk)))
    out = {}
    for cls, items in per.items():
        cues = []
        for i, (s, body) in enumerate(items):
            if not body:
                continue
            e = items[i + 1][0] if i + 1 < len(items) else s + 3000
            cues.append([s, max(e, s + 200), body])
        if cues:
            out[cls] = cues
    return out


def parse_ass(text: str):
    cues = []
    for ln in text.splitlines():
        if not ln.startswith("Dialogue:"):
            continue
        p = ln[9:].split(",", 9)
        if len(p) < 10:
            continue

        def t(x):
            h, m, s = x.strip().split(":")
            sec, _, cs = s.partition(".")
            return (int(h) * 3600 + int(m) * 60 + int(sec)) * 1000 + int((cs or "0").ljust(2, "0")[:2]) * 10

        try:
            body = _clean(p[9].replace("\\N", "\n").replace("\\n", "\n"))
            if body:
                cues.append([t(p[1]), t(p[2]), body])
        except ValueError:
            pass
    cues.sort(key=lambda c: c[0])
    return cues


def _label_from_filename(path: str, video_stem: str = "") -> str:
    stem = os.path.splitext(os.path.basename(path))[0]
    if video_stem and stem.lower().startswith(video_stem.lower()):
        rest = stem[len(video_stem):].strip(" ._-")
    else:
        rest = stem
    for tok in reversed(re.split(r"[.\-_ ]+", rest.lower())):
        if tok in LANG_NAMES:
            return LANG_NAMES[tok]
    return rest or stem


def load_file(path: str, video_stem: str = ""):
    with open(path, "rb") as f:
        text = _decode(f.read())
    ext = os.path.splitext(path)[1].lower()
    base = _label_from_filename(path, video_stem)
    tracks = []
    if ext in (".smi", ".sami"):
        for cls, cues in parse_smi(text).items():
            name = LANG_NAMES.get(cls.lower(), cls if cls != "DEFAULT" else base)
            tracks.append({"name": name, "cues": cues})
    else:
        cues = parse_ass(text) if ext in (".ass", ".ssa") else parse_srt_vtt(text)
        if cues:
            tracks.append({"name": base, "cues": cues})
    return tracks


def find_sidecars(video_path: str):
    folder = os.path.dirname(video_path)
    stem = os.path.splitext(os.path.basename(video_path))[0]
    tracks = []
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return tracks
    for n in names:
        low = n.lower()
        if low.endswith(EXTS) and low.startswith(stem.lower()):
            try:
                tracks += load_file(os.path.join(folder, n), stem)
            except Exception:
                pass
    return tracks
