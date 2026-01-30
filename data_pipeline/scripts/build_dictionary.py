import json
import os
from collections import defaultdict

from jmdict_parser import iter_entries
from sqlite_writer import SQLiteWriter
from utils import (
    dedupe_pairs,
    ensure_override_file,
    filter_meanings,
    load_csv_pairs,
    load_override,
    normalize_text,
    write_two_column_csv,
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_DIR = os.path.join(BASE_DIR, "input")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
SCRIPTS_DIR = os.path.join(BASE_DIR, "scripts")

JLPT_INPUT = {
    "N5": os.path.join(INPUT_DIR, "n5.csv"),
    "N4": os.path.join(INPUT_DIR, "n4.csv"),
}
JLPT_OUTPUT = {
    "N5": os.path.join(INPUT_DIR, "jlpt_n5.csv"),
    "N4": os.path.join(INPUT_DIR, "jlpt_n4.csv"),
}

KOR_OVERRIDE_PATH = os.path.join(INPUT_DIR, "kor_override.csv")
JMDICT_PATH = os.path.join(INPUT_DIR, "JMdict_e.xml")
DB_PATH = os.path.join(OUTPUT_DIR, "jlpt_starter.sqlite")
REPORT_PATH = os.path.join(OUTPUT_DIR, "coverage_report.json")


def build_jlpt_csvs():
    results = {}
    for level, src in JLPT_INPUT.items():
        print(f"[1] Loading {level} source: {src}")
        pairs = load_csv_pairs(src)
        pairs = dedupe_pairs(pairs)
        out_path = JLPT_OUTPUT[level]
        print(f"[1] Writing {level} list: {out_path} ({len(pairs)} rows)")
        write_two_column_csv(out_path, pairs)
        results[level] = pairs
    return results


def ensure_override_csv():
    created = ensure_override_file(KOR_OVERRIDE_PATH)
    if created:
        print(f"[2] Created override template: {KOR_OVERRIDE_PATH}")
    else:
        print(f"[2] Override file exists: {KOR_OVERRIDE_PATH}")


def collect_jmdict_glosses(target_sets):
    found = {"N5": set(), "N4": set()}
    glosses = {"N5": defaultdict(list), "N4": defaultdict(list)}

    print(f"[3] Parsing JMdict: {JMDICT_PATH}")
    for expressions, readings, kor_glosses in iter_entries(JMDICT_PATH):
        if not readings:
            continue
        if not expressions:
            expressions = readings
        exprs = [normalize_text(x) for x in expressions if x]
        reads = [normalize_text(x) for x in readings if x]
        if not exprs or not reads:
            continue
        for expr in exprs:
            for reading in reads:
                key = (expr, reading)
                for level in ("N5", "N4"):
                    if key not in target_sets[level]:
                        continue
                    found[level].add(key)
                    if not kor_glosses:
                        continue
                    bucket = glosses[level][key]
                    for gloss in kor_glosses:
                        g = normalize_text(gloss)
                        if not g or g in bucket:
                            continue
                        bucket.append(g)
    return found, glosses


def build_database(targets, found_in_jmdict, glosses, overrides):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    included = {"N5": set(), "N4": set()}
    missing_kor = {"N5": set(), "N4": set()}

    with SQLiteWriter(DB_PATH) as db:
        for level in ("N5", "N4"):
            print(f"[3] Inserting {level} words into DB")
            for expr, reading in targets[level]:
                override_key = (level, expr, reading)
                if override_key in overrides:
                    meanings = overrides[override_key]
                else:
                    meanings = glosses[level].get((expr, reading), [])
                meanings = filter_meanings(meanings)
                if not meanings:
                    if (expr, reading) in found_in_jmdict[level]:
                        missing_kor[level].add((expr, reading))
                    continue
                word_id = db.upsert_word(expr, reading, level)
                if word_id is None:
                    continue
                db.replace_meanings(word_id, meanings)
                included[level].add((expr, reading))
        db.commit()

    return included, missing_kor


def build_report(targets, found_in_jmdict, included, missing_kor):
    report = {}
    for level in ("N5", "N4"):
        total_listed = len(targets[level])
        found = len(found_in_jmdict[level])
        included_count = len(included[level])
        missing_in_jmdict = [
            {"expression": e, "reading": r}
            for (e, r) in targets[level]
            if (e, r) not in found_in_jmdict[level]
        ]
        missing_kor_list = [
            {"expression": e, "reading": r}
            for (e, r) in targets[level]
            if (e, r) in missing_kor[level]
        ]
        report[level] = {
            "total_listed": total_listed,
            "found_in_jmdict": found,
            "included_in_db": included_count,
            "missing_in_jmdict": missing_in_jmdict,
            "missing_kor": missing_kor_list,
        }
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"[4] Wrote coverage report: {REPORT_PATH}")


def main():
    print("[0] Build start")
    targets = build_jlpt_csvs()
    target_sets = {level: set(pairs) for level, pairs in targets.items()}
    ensure_override_csv()
    overrides = load_override(KOR_OVERRIDE_PATH)
    if overrides:
        print(f"[2] Loaded overrides: {len(overrides)}")
    else:
        print("[2] No overrides loaded")

    if not os.path.exists(JMDICT_PATH):
        raise FileNotFoundError(f"JMdict not found: {JMDICT_PATH}")

    found_in_jmdict, glosses = collect_jmdict_glosses(target_sets)
    included, missing_kor = build_database(targets, found_in_jmdict, glosses, overrides)
    build_report(targets, found_in_jmdict, included, missing_kor)
    print("[0] Build complete")


if __name__ == "__main__":
    main()
