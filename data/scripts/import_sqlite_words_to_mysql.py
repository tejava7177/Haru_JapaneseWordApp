#!/usr/bin/env python3
import argparse
import os
import sqlite3
import subprocess
import sys
from collections import Counter
from pathlib import Path


DEFAULT_SQLITE_PATH = Path(
    "apps/ios/HaruJapaneseWordApp/HaruJapaneseWordApp/Resources/Dictionary/jlpt_starter.sqlite"
)
VALID_LEVELS = {"N5", "N4", "N3", "N2", "N1"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import local SQLite JLPT words/meanings into MySQL word/meaning tables."
    )
    parser.add_argument("--sqlite-path", default=str(DEFAULT_SQLITE_PATH))
    parser.add_argument("--mysql-host", default=os.getenv("MYSQL_HOST", "127.0.0.1"))
    parser.add_argument("--mysql-port", type=int, default=int(os.getenv("MYSQL_PORT", "3306")))
    parser.add_argument("--mysql-user", default=os.getenv("MYSQL_USER", "root"))
    parser.add_argument("--mysql-password", default=os.getenv("MYSQL_PASSWORD", "root1234"))
    parser.add_argument("--mysql-database", default=os.getenv("MYSQL_DATABASE", "haru"))
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument(
        "--skip-empty-meanings",
        action="store_true",
        default=True,
        help="Skip words that do not have any meaning row in SQLite. Enabled by default.",
    )
    return parser.parse_args()


def sql_quote(value: str | None) -> str:
    if value is None:
        return "NULL"
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\0", "\\0")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\x1a", "\\Z")
    )
    return f"'{escaped}'"


def chunked(values: list[tuple], size: int):
    for index in range(0, len(values), size):
        yield values[index:index + size]


def load_sqlite_rows(sqlite_path: Path):
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    try:
        words = [
            (
                int(row["id"]),
                row["expression"],
                row["reading"],
                row["level"],
            )
            for row in conn.execute(
                """
                SELECT id, expression, reading, level
                FROM word
                ORDER BY id ASC
                """
            )
        ]
        meanings = [
            (
                int(row["id"]),
                int(row["word_id"]),
                row["text"],
                int(row["ord"]),
            )
            for row in conn.execute(
                """
                SELECT id, word_id, text, ord
                FROM meaning
                ORDER BY id ASC
                """
            )
        ]
    finally:
        conn.close()

    return words, meanings


def validate_rows(words: list[tuple], meanings: list[tuple]):
    level_counts = Counter()
    meaning_counts = Counter()

    for word_id, expression, reading, level in words:
        if level not in VALID_LEVELS:
            raise ValueError(f"Unsupported level for word_id={word_id}: {level}")
        if not expression or not reading:
            raise ValueError(f"Missing expression/reading for word_id={word_id}")
        level_counts[level] += 1

    for _, word_id, text, ord_value in meanings:
        if not text:
            raise ValueError(f"Empty meaning text for word_id={word_id}")
        if ord_value < 0:
            raise ValueError(f"Negative meaning ord for word_id={word_id}")
        meaning_counts[word_id] += 1

    return level_counts, meaning_counts


def build_import_sql(words: list[tuple], meanings: list[tuple], batch_size: int, skip_empty_meanings: bool) -> str:
    meaning_counts = Counter(word_id for _, word_id, _, _ in meanings)
    filtered_words = words
    if skip_empty_meanings:
        filtered_words = [word for word in words if meaning_counts[word[0]] > 0]

    sql_parts = [
        "SET NAMES utf8mb4;",
        "SET FOREIGN_KEY_CHECKS=0;",
    ]

    for batch in chunked(filtered_words, batch_size):
        values_sql = ",\n".join(
            f"({word_id}, {sql_quote(expression)}, {sql_quote(reading)}, {sql_quote(level)})"
            for word_id, expression, reading, level in batch
        )
        sql_parts.append(
            "INSERT INTO word (id, expression, reading, level)\n"
            f"VALUES\n{values_sql}\n"
            "ON DUPLICATE KEY UPDATE\n"
            "expression = VALUES(expression),\n"
            "reading = VALUES(reading),\n"
            "level = VALUES(level);"
        )

    for batch in chunked(meanings, batch_size):
        values_sql = ",\n".join(
            f"({meaning_id}, {word_id}, {sql_quote(text)}, {ord_value})"
            for meaning_id, word_id, text, ord_value in batch
        )
        sql_parts.append(
            "INSERT INTO meaning (id, word_id, text, ord)\n"
            f"VALUES\n{values_sql}\n"
            "ON DUPLICATE KEY UPDATE\n"
            "word_id = VALUES(word_id),\n"
            "text = VALUES(text),\n"
            "ord = VALUES(ord);"
        )

    sql_parts.extend(
        [
            "SET FOREIGN_KEY_CHECKS=1;",
            "SELECT level, COUNT(*) AS count FROM word GROUP BY level ORDER BY level;",
            "SELECT COUNT(*) AS count FROM meaning;",
        ]
    )

    return "\n\n".join(sql_parts), filtered_words


def run_mysql(sql: str, args: argparse.Namespace) -> str:
    cmd = [
        "mysql",
        f"--host={args.mysql_host}",
        f"--port={args.mysql_port}",
        f"--user={args.mysql_user}",
        f"--password={args.mysql_password}",
        "--default-character-set=utf8mb4",
        "--batch",
        "--raw",
        args.mysql_database,
    ]
    result = subprocess.run(
        cmd,
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        print("[Import][ERROR] mysql returncode=", result.returncode, file=sys.stderr)
        print("[Import][ERROR] stderr:", result.stderr, file=sys.stderr)
        print("[Import][ERROR] stdout:", result.stdout, file=sys.stderr)
        raise RuntimeError("mysql import failed")
    return result.stdout


def main() -> int:
    args = parse_args()
    sqlite_path = Path(args.sqlite_path)
    if not sqlite_path.exists():
        print(f"SQLite file not found: {sqlite_path}", file=sys.stderr)
        return 1

    words, meanings = load_sqlite_rows(sqlite_path)
    level_counts, meaning_counts = validate_rows(words, meanings)
    missing_meanings = [word for word in words if meaning_counts[word[0]] == 0]

    print(f"[Import] sqlite word count={len(words)}")
    print(f"[Import] sqlite meaning count={len(meanings)}")
    print(f"[Import] sqlite level counts={dict(sorted(level_counts.items()))}")
    if missing_meanings:
        ids = ", ".join(str(word[0]) for word in missing_meanings[:10])
        print(f"[Import] words without meaning rows={len(missing_meanings)} ids={ids}")

    import_sql, filtered_words = build_import_sql(
        words=words,
        meanings=meanings,
        batch_size=args.batch_size,
        skip_empty_meanings=args.skip_empty_meanings,
    )
    print(f"[Import] import word count={len(filtered_words)}")
    print(f"[Import] import meaning count={len(meanings)}")

    output = run_mysql(import_sql, args)
    print("[Import] mysql result:")
    print(output.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
