import sqlite3


class SQLiteWriter:
    def __init__(self, path):
        self.path = path
        self.conn = sqlite3.connect(path)
        self.conn.execute("PRAGMA journal_mode=WAL;")
        self.conn.execute("PRAGMA synchronous=NORMAL;")
        self.conn.execute("PRAGMA foreign_keys=ON;")
        self.create_schema()

    def create_schema(self):
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS word(
                id INTEGER PRIMARY KEY,
                expression TEXT NOT NULL,
                reading TEXT NOT NULL,
                level TEXT NOT NULL CHECK(level IN ('N5','N4')),
                UNIQUE(expression, reading, level)
            );
            CREATE TABLE IF NOT EXISTS meaning(
                id INTEGER PRIMARY KEY,
                word_id INTEGER NOT NULL,
                text TEXT NOT NULL,
                ord INTEGER NOT NULL,
                FOREIGN KEY(word_id) REFERENCES word(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_word_expression ON word(expression);
            CREATE INDEX IF NOT EXISTS idx_word_reading ON word(reading);
            """
        )

    def upsert_word(self, expression, reading, level):
        self.conn.execute(
            "INSERT OR IGNORE INTO word(expression, reading, level) VALUES (?, ?, ?)",
            (expression, reading, level),
        )
        cur = self.conn.execute(
            "SELECT id FROM word WHERE expression=? AND reading=? AND level=?",
            (expression, reading, level),
        )
        row = cur.fetchone()
        return row[0] if row else None

    def replace_meanings(self, word_id, meanings):
        self.conn.execute("DELETE FROM meaning WHERE word_id=?", (word_id,))
        self.conn.executemany(
            "INSERT INTO meaning(word_id, text, ord) VALUES (?, ?, ?)",
            [(word_id, text, i + 1) for i, text in enumerate(meanings)],
        )

    def commit(self):
        self.conn.commit()

    def close(self):
        self.conn.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        if exc is None:
            self.conn.commit()
        else:
            self.conn.rollback()
        self.conn.close()
