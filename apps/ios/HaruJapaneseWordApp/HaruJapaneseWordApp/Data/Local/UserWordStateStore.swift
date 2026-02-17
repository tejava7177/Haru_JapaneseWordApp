import Foundation
import SQLite3

struct UserWordStateStore {
    private let dbPath: String

    init() {
        self.dbPath = Self.writableDatabaseURL().path
        ensureTable()
    }

    func isExcluded(wordId: Int, now: Date) -> Bool {
        let nowEpoch = Int(now.timeIntervalSince1970)
        return loadExcludedSet(nowEpoch: nowEpoch).contains(wordId)
    }

    func loadExcludedSet(now: Date) -> Set<Int> {
        loadExcludedSet(nowEpoch: Int(now.timeIntervalSince1970))
    }

    func setExcludedUntil(wordId: Int, until: Date?) {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }

            if let until {
                let sql = """
                INSERT INTO user_word_state(word_id, excluded_until)
                VALUES(?, ?)
                ON CONFLICT(word_id) DO UPDATE SET excluded_until=excluded.excluded_until;
                """
                let stmt = try db.prepare(sql)
                defer { db.finalize(stmt) }
                try db.bind(wordId, to: 1, in: stmt)
                try db.bind(Int(until.timeIntervalSince1970), to: 2, in: stmt)
                _ = try db.step(stmt)
            } else {
                let sql = "DELETE FROM user_word_state WHERE word_id = ?;"
                let stmt = try db.prepare(sql)
                defer { db.finalize(stmt) }
                try db.bind(wordId, to: 1, in: stmt)
                _ = try db.step(stmt)
            }
        } catch {
            print("[UserWordStateStore] failed to set excluded_until: \(error)")
        }
    }

    private func ensureTable() {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            CREATE TABLE IF NOT EXISTS user_word_state (
                word_id INTEGER PRIMARY KEY,
                excluded_until INTEGER
            );
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
        } catch {
            print("[UserWordStateStore] failed to ensure table: \(error)")
        }
    }

    private func loadExcludedSet(nowEpoch: Int) -> Set<Int> {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let cleanup = "DELETE FROM user_word_state WHERE excluded_until IS NOT NULL AND excluded_until <= ?;"
            let cleanupStmt = try db.prepare(cleanup)
            defer { db.finalize(cleanupStmt) }
            try db.bind(nowEpoch, to: 1, in: cleanupStmt)
            _ = try db.step(cleanupStmt)

            let sql = """
            SELECT word_id
            FROM user_word_state
            WHERE excluded_until IS NOT NULL AND excluded_until > ?;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(nowEpoch, to: 1, in: stmt)
            var result: Set<Int> = []
            while try db.step(stmt) {
                let id = SQLiteDB.columnInt(stmt, 0)
                result.insert(id)
            }
            return result
        } catch {
            print("[UserWordStateStore] failed to load excluded set: \(error)")
            return []
        }
    }

    private static func writableDatabaseURL() -> URL {
        let baseURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dirURL = baseURL?.appendingPathComponent("DictionaryDB", isDirectory: true)
        if let dirURL {
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            return dirURL.appendingPathComponent("jlpt_starter.sqlite", isDirectory: false)
        }
        return URL(fileURLWithPath: "jlpt_starter.sqlite")
    }
}
