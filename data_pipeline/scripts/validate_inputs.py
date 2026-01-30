import csv
import os


REQUIRED_HEADERS = {"expression", "reading"}


def validate_csv(path):
    if not os.path.exists(path):
        print(f"[validate] Missing: {path}")
        return False
    with open(path, encoding="utf-8") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration:
            print(f"[validate] Empty file: {path}")
            return False
        header_norm = {h.strip().lower() for h in header}
        if not REQUIRED_HEADERS.issubset(header_norm):
            print(f"[validate] Bad header in {path}: {header}")
            return False
        for idx, row in enumerate(reader, start=2):
            if len(row) < 2:
                print(f"[validate] Row {idx} too short in {path}")
                return False
            if not row[0].strip() or not row[1].strip():
                print(f"[validate] Empty expression/reading at row {idx} in {path}")
                return False
    print(f"[validate] OK: {path}")
    return True


def main():
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    inputs = [
        os.path.join(base, "input", "n5.csv"),
        os.path.join(base, "input", "n4.csv"),
        os.path.join(base, "input", "jlpt_n5.csv"),
        os.path.join(base, "input", "jlpt_n4.csv"),
    ]
    ok = True
    for path in inputs:
        if os.path.exists(path):
            ok = validate_csv(path) and ok
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
