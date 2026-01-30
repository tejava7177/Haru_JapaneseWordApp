import csv
import os
import unicodedata


def normalize_text(text):
    if text is None:
        return ""
    normalized = unicodedata.normalize("NFKC", text)
    normalized = normalized.replace("\ufeff", "")
    return normalized.strip()


def dedupe_pairs(pairs):
    seen = set()
    out = []
    for expr, reading in pairs:
        key = (expr, reading)
        if key in seen:
            continue
        seen.add(key)
        out.append(key)
    return out


def load_csv_pairs(path):
    pairs = []
    with open(path, encoding="utf-8") as f:
        reader = csv.reader(f)
        try:
            first = next(reader)
        except StopIteration:
            return []
        header = [normalize_text(c).lower() for c in first]
        if "expression" in header and "reading" in header:
            expr_idx = header.index("expression")
            read_idx = header.index("reading")
        else:
            expr_idx = 0
            read_idx = 1
            if len(first) > read_idx:
                pairs.append((normalize_text(first[expr_idx]), normalize_text(first[read_idx])))
        for row in reader:
            if not row:
                continue
            if expr_idx >= len(row) or read_idx >= len(row):
                continue
            expr = normalize_text(row[expr_idx])
            reading = normalize_text(row[read_idx])
            if not expr or not reading:
                continue
            pairs.append((expr, reading))
    return dedupe_pairs([p for p in pairs if p[0] and p[1]])


def write_two_column_csv(path, pairs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["expression", "reading"])
        writer.writerows(pairs)


def split_meanings(text):
    if not text:
        return []
    normalized = normalize_text(text)
    for sep in [";", "/", "|", "·", "、", ","]:
        normalized = normalized.replace(sep, ";")
    raw = [normalize_text(x) for x in normalized.split(";")]
    out = []
    seen = set()
    for item in raw:
        if not item:
            continue
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def filter_meanings(meanings, max_len=30, max_items=3):
    out = []
    for m in meanings:
        if not m:
            continue
        if len(m) > max_len:
            continue
        if m in out:
            continue
        out.append(m)
        if len(out) >= max_items:
            break
    return out


def load_override(path):
    if not os.path.exists(path):
        return {}
    overrides = {}
    with open(path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            level_raw = normalize_text(row.get("level", ""))
            level = level_raw.upper()
            if level in ("JLPT_N5", "JLPT5", "N5"):
                level = "N5"
            elif level in ("JLPT_N4", "JLPT4", "N4"):
                level = "N4"
            expr = normalize_text(row.get("expression", ""))
            reading = normalize_text(row.get("reading", ""))
            meanings_ko = normalize_text(row.get("meanings_ko", ""))
            if not level or not expr or not reading:
                continue
            meanings = filter_meanings(split_meanings(meanings_ko))
            overrides[(level, expr, reading)] = meanings
    return overrides


def ensure_override_file(path):
    if os.path.exists(path):
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["level", "expression", "reading", "meanings_ko", "note"])
    return True
