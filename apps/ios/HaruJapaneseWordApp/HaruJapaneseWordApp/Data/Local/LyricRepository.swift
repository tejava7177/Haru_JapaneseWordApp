import Foundation

struct LyricRepository {
    private let database: DictionaryDatabase?

    init(database: DictionaryDatabase? = nil) {
        if let database {
            self.database = database
        } else {
            self.database = try? DictionaryDatabase.sharedDatabase()
        }
    }

    func getTodayLyric() throws -> LyricEntry? {
        guard let database else { return nil }
        return try database.read { db in
            let countSql = "SELECT COUNT(*) FROM lyric_entries;"
            let countStatement = try db.prepare(countSql)
            defer { db.finalize(countStatement) }
            guard try db.step(countStatement) else { return nil }
            let count = SQLiteDB.columnInt(countStatement, 0)
            guard count > 0 else { return nil }

            let sql = """
            SELECT id, inspired_by, ja_line, ko_line,
                   target_expression, target_reading, target_meaning_ko,
                   target_jlpt, tags
            FROM lyric_entries
            ORDER BY id
            LIMIT 1 OFFSET (
              ABS(CAST(STRFTIME('%j','now','localtime') AS INTEGER) * 997)
              % (SELECT COUNT(*) FROM lyric_entries)
            );
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            guard try db.step(statement) else { return nil }

            return LyricEntry(
                id: SQLiteDB.columnText(statement, 0) ?? "",
                inspiredBy: SQLiteDB.columnText(statement, 1) ?? "",
                jaLine: SQLiteDB.columnText(statement, 2) ?? "",
                koLine: SQLiteDB.columnText(statement, 3) ?? "",
                targetExpression: SQLiteDB.columnText(statement, 4) ?? "",
                targetReading: SQLiteDB.columnText(statement, 5) ?? "",
                targetMeaningKo: SQLiteDB.columnText(statement, 6) ?? "",
                targetJlpt: SQLiteDB.columnText(statement, 7) ?? "",
                tags: SQLiteDB.columnText(statement, 8) ?? ""
            )
        }
    }
}
