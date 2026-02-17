import Foundation

final class SQLiteDictionaryRepository: DictionaryRepository {
    enum RepositoryError: Error {
        case databaseUnavailable
    }

    private let database: DictionaryDatabase
    private var hasLoggedFirstFetch: Bool = false

    init() throws {
        self.database = try DictionaryDatabase.sharedDatabase()
    }

    func fetchWords(level: JLPTLevel?, limit: Int?, offset: Int?) throws -> [WordSummary] {
        if hasLoggedFirstFetch == false {
            let levelLabel = level?.rawValue ?? "ALL"
            print("[DB] fetchWords level=\(levelLabel)")
            hasLoggedFirstFetch = true
        }
        return try database.read { db in
            var sqlParts: [String] = [
                """
                SELECT w.id, w.level, w.expression, w.reading,
                       GROUP_CONCAT(m.text, ' / ') AS meanings
                FROM word w
                LEFT JOIN meaning m ON m.word_id = w.id
                """
            ]
            if level != nil {
                sqlParts.append("WHERE w.level = ?")
            }
            sqlParts.append(
                """
                GROUP BY w.id
                ORDER BY w.expression
                LIMIT ? OFFSET ?;
                """
            )
            let sql = sqlParts.joined(separator: "\n")

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            var bindIndex: Int32 = 1
            if let level {
                try db.bind(level.rawValue, to: bindIndex, in: statement)
                bindIndex += 1
            }
            try db.bind(limit ?? -1, to: bindIndex, in: statement)
            bindIndex += 1
            try db.bind(offset ?? 0, to: bindIndex, in: statement)

            var results: [WordSummary] = []
            while try db.step(statement) {
                let id = SQLiteDB.columnInt(statement, 0)
                let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
                let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
                let expression = SQLiteDB.columnText(statement, 2) ?? ""
                let reading = SQLiteDB.columnText(statement, 3) ?? ""
                let meanings = SQLiteDB.columnText(statement, 4) ?? ""
                results.append(
                    WordSummary(
                        id: id,
                        level: levelValue,
                        expression: expression,
                        reading: reading,
                        meanings: meanings
                    )
                )
            }
            return results
        }
    }

    func searchWords(level: JLPTLevel?, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        return try database.read { db in
            var sqlParts: [String] = [
                """
                SELECT w.id, w.level, w.expression, w.reading,
                       GROUP_CONCAT(m.text, ' / ') AS meanings
                FROM word w
                LEFT JOIN meaning m ON m.word_id = w.id
                """
            ]
            if level != nil {
                sqlParts.append("WHERE w.level = ? AND (w.expression LIKE ? OR w.reading LIKE ? OR m.text LIKE ?)")
            } else {
                sqlParts.append("WHERE (w.expression LIKE ? OR w.reading LIKE ? OR m.text LIKE ?)")
            }
            sqlParts.append(
                """
                GROUP BY w.id
                ORDER BY w.expression
                LIMIT ? OFFSET ?;
                """
            )
            let sql = sqlParts.joined(separator: "\n")

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            let likeQuery = "%\(query)%"
            var bindIndex: Int32 = 1
            if let level {
                try db.bind(level.rawValue, to: bindIndex, in: statement)
                bindIndex += 1
            }
            try db.bind(likeQuery, to: bindIndex, in: statement)
            bindIndex += 1
            try db.bind(likeQuery, to: bindIndex, in: statement)
            bindIndex += 1
            try db.bind(likeQuery, to: bindIndex, in: statement)
            bindIndex += 1
            try db.bind(limit ?? -1, to: bindIndex, in: statement)
            bindIndex += 1
            try db.bind(offset ?? 0, to: bindIndex, in: statement)

            var results: [WordSummary] = []
            while try db.step(statement) {
                let id = SQLiteDB.columnInt(statement, 0)
                let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
                let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
                let expression = SQLiteDB.columnText(statement, 2) ?? ""
                let reading = SQLiteDB.columnText(statement, 3) ?? ""
                let meanings = SQLiteDB.columnText(statement, 4) ?? ""
                results.append(
                    WordSummary(
                        id: id,
                        level: levelValue,
                        expression: expression,
                        reading: reading,
                        meanings: meanings
                    )
                )
            }
            return results
        }
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        return try database.read { db in
            let wordSql = """
            SELECT w.id, w.level, w.expression, w.reading
            FROM word w
            WHERE w.id = ?;
            """

            let wordStatement = try db.prepare(wordSql)
            defer { db.finalize(wordStatement) }

            try db.bind(wordId, to: 1, in: wordStatement)

            guard try db.step(wordStatement) else {
                return nil
            }

            let id = SQLiteDB.columnInt(wordStatement, 0)
            let levelRaw = SQLiteDB.columnText(wordStatement, 1) ?? JLPTLevel.n5.rawValue
            let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
            let expression = SQLiteDB.columnText(wordStatement, 2) ?? ""
            let reading = SQLiteDB.columnText(wordStatement, 3) ?? ""

            let meaningSql = """
            SELECT m.ord, m.text
            FROM meaning m
            WHERE m.word_id = ?
            ORDER BY m.ord;
            """

            let meaningStatement = try db.prepare(meaningSql)
            defer { db.finalize(meaningStatement) }

            try db.bind(wordId, to: 1, in: meaningStatement)

            var meanings: [Meaning] = []
            while try db.step(meaningStatement) {
                let ord = SQLiteDB.columnInt(meaningStatement, 0)
                let text = SQLiteDB.columnText(meaningStatement, 1) ?? ""
                meanings.append(Meaning(ord: ord, text: text))
            }

            return WordDetail(
                id: id,
                level: levelValue,
                expression: expression,
                reading: reading,
                meanings: meanings
            )
        }
    }

    func fetchWordSummary(wordId: Int) throws -> WordSummary? {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            WHERE w.id = ?
            GROUP BY w.id
            LIMIT 1;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(wordId, to: 1, in: statement)

            guard try db.step(statement) else {
                return nil
            }

            let id = SQLiteDB.columnInt(statement, 0)
            let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
            let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
            let expression = SQLiteDB.columnText(statement, 2) ?? ""
            let reading = SQLiteDB.columnText(statement, 3) ?? ""
            let meanings = SQLiteDB.columnText(statement, 4) ?? ""
            return WordSummary(id: id, level: levelValue, expression: expression, reading: reading, meanings: meanings)
        }
    }

    func randomWord(level: JLPTLevel) throws -> WordSummary? {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            WHERE w.level = ?
            GROUP BY w.id
            ORDER BY RANDOM()
            LIMIT 1;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(level.rawValue, to: 1, in: statement)

            guard try db.step(statement) else {
                return nil
            }

            let id = SQLiteDB.columnInt(statement, 0)
            let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
            let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
            let expression = SQLiteDB.columnText(statement, 2) ?? ""
            let reading = SQLiteDB.columnText(statement, 3) ?? ""
            let meanings = SQLiteDB.columnText(statement, 4) ?? ""
            return WordSummary(id: id, level: levelValue, expression: expression, reading: reading, meanings: meanings)
        }
    }

    func randomWordIds(level: JLPTLevel, count: Int, excluding ids: Set<Int>) throws -> [Int] {
        let maxAttempts = 50
        var results: [Int] = []
        var exclusion = ids
        var attempts = 0

        while results.count < count && attempts < maxAttempts {
            attempts += 1
            if let id = try randomWordId(level: level, excluding: exclusion) {
                results.append(id)
                exclusion.insert(id)
            } else {
                break
            }
        }
        return results
    }

    func findByExpression(_ expression: String) throws -> WordSummary? {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            WHERE w.expression = ?
            GROUP BY w.id
            LIMIT 1;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(expression, to: 1, in: statement)

            guard try db.step(statement) else {
                return nil
            }

            let id = SQLiteDB.columnInt(statement, 0)
            let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
            let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
            let expr = SQLiteDB.columnText(statement, 2) ?? ""
            let reading = SQLiteDB.columnText(statement, 3) ?? ""
            let meanings = SQLiteDB.columnText(statement, 4) ?? ""
            return WordSummary(id: id, level: levelValue, expression: expr, reading: reading, meanings: meanings)
        }
    }

    func getRandomWords(limit: Int, excludingExpression: String?) throws -> [WordSummary] {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            WHERE (? IS NULL OR w.expression != ?)
            GROUP BY w.id
            ORDER BY RANDOM()
            LIMIT ?;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(excludingExpression, to: 1, in: statement)
            try db.bind(excludingExpression, to: 2, in: statement)
            try db.bind(limit, to: 3, in: statement)

            var results: [WordSummary] = []
            while try db.step(statement) {
                let id = SQLiteDB.columnInt(statement, 0)
                let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
                let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
                let expr = SQLiteDB.columnText(statement, 2) ?? ""
                let reading = SQLiteDB.columnText(statement, 3) ?? ""
                let meanings = SQLiteDB.columnText(statement, 4) ?? ""
                results.append(
                    WordSummary(id: id, level: levelValue, expression: expr, reading: reading, meanings: meanings)
                )
            }
            return results
        }
    }

    func fetchRecommendedWords(level: JLPTLevel, limit: Int) throws -> [WordSummary] {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            LEFT JOIN user_word_state s ON s.word_id = w.id
            WHERE w.level = ?
              AND NOT (
                s.is_checked = 1
                AND s.checked_at IS NOT NULL
                AND s.checked_at > DATETIME('now', '-30 days')
              )
            GROUP BY w.id
            ORDER BY RANDOM()
            LIMIT ?;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(level.rawValue, to: 1, in: statement)
            try db.bind(limit, to: 2, in: statement)

            var results: [WordSummary] = []
            while try db.step(statement) {
                let id = SQLiteDB.columnInt(statement, 0)
                let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
                let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
                let expression = SQLiteDB.columnText(statement, 2) ?? ""
                let reading = SQLiteDB.columnText(statement, 3) ?? ""
                let meanings = SQLiteDB.columnText(statement, 4) ?? ""
                results.append(
                    WordSummary(id: id, level: levelValue, expression: expression, reading: reading, meanings: meanings)
                )
            }
            return results
        }
    }

    func fetchRecommendedWords(
        containing kanji: String,
        currentLevel: JLPTLevel,
        excluding wordId: Int,
        limit: Int
    ) throws -> [WordSummary] {
        return try database.read { db in
            let sql = """
            SELECT w.id, w.level, w.expression, w.reading,
                   GROUP_CONCAT(m.text, ' / ') AS meanings
            FROM word w
            LEFT JOIN meaning m ON m.word_id = w.id
            WHERE w.expression LIKE '%' || ? || '%'
              AND w.id != ?
            GROUP BY w.id
            ORDER BY ABS(CASE w.level
                WHEN 'N1' THEN 1
                WHEN 'N2' THEN 2
                WHEN 'N3' THEN 3
                WHEN 'N4' THEN 4
                WHEN 'N5' THEN 5
                ELSE 5
            END - ?) ASC,
            LENGTH(w.expression) ASC,
            w.id ASC
            LIMIT ?;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            let levelRank = currentLevel.rank
            try db.bind(kanji, to: 1, in: statement)
            try db.bind(wordId, to: 2, in: statement)
            try db.bind(levelRank, to: 3, in: statement)
            try db.bind(limit, to: 4, in: statement)

            var results: [WordSummary] = []
            while try db.step(statement) {
                let id = SQLiteDB.columnInt(statement, 0)
                let levelRaw = SQLiteDB.columnText(statement, 1) ?? JLPTLevel.n5.rawValue
                let levelValue = JLPTLevel(rawValue: levelRaw) ?? .n5
                let expression = SQLiteDB.columnText(statement, 2) ?? ""
                let reading = SQLiteDB.columnText(statement, 3) ?? ""
                let meanings = SQLiteDB.columnText(statement, 4) ?? ""
                results.append(
                    WordSummary(id: id, level: levelValue, expression: expression, reading: reading, meanings: meanings)
                )
            }
            return results
        }
    }

    func fetchCheckedStates(wordIds: [Int]) throws -> Set<Int> {
        guard wordIds.isEmpty == false else { return [] }
        return try database.read { db in
            let placeholders = Array(repeating: "?", count: wordIds.count).joined(separator: ", ")
            let sql = """
            SELECT word_id
            FROM user_word_state
            WHERE word_id IN (\(placeholders))
              AND is_checked = 1;
            """

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            for (index, id) in wordIds.enumerated() {
                try db.bind(id, to: Int32(index + 1), in: statement)
            }

            var result: Set<Int> = []
            while try db.step(statement) {
                result.insert(SQLiteDB.columnInt(statement, 0))
            }
            return result
        }
    }

    func setChecked(wordId: Int, checked: Bool) throws {
        let sql: String
        if checked {
            sql = """
            INSERT INTO user_word_state(word_id, is_checked, checked_at, updated_at)
            VALUES(?, 1, DATETIME('now'), DATETIME('now'))
            ON CONFLICT(word_id) DO UPDATE SET
              is_checked = 1,
              checked_at = DATETIME('now'),
              updated_at = DATETIME('now');
            """
        } else {
            sql = """
            INSERT INTO user_word_state(word_id, is_checked, checked_at, updated_at)
            VALUES(?, 0, NULL, DATETIME('now'))
            ON CONFLICT(word_id) DO UPDATE SET
              is_checked = 0,
              checked_at = NULL,
              updated_at = DATETIME('now');
            """
        }

        try database.read { db in
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(wordId, to: 1, in: statement)
            _ = try db.step(statement)
        }
    }

    private func randomWordId(level: JLPTLevel, excluding ids: Set<Int>) throws -> Int? {
        return try database.read { db in
            var sql = """
            SELECT w.id
            FROM word w
            WHERE w.level = ?
            """

            let sortedIds = ids.sorted()
            if sortedIds.isEmpty == false {
                let placeholders = Array(repeating: "?", count: sortedIds.count).joined(separator: ", ")
                sql += "\nAND w.id NOT IN (\(placeholders))"
            }

            sql += "\nORDER BY RANDOM()\nLIMIT 1;"

            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }

            try db.bind(level.rawValue, to: 1, in: statement)
            if sortedIds.isEmpty == false {
                for (index, id) in sortedIds.enumerated() {
                    try db.bind(id, to: Int32(index + 2), in: statement)
                }
            }

            guard try db.step(statement) else {
                return nil
            }

            return SQLiteDB.columnInt(statement, 0)
        }
    }
}
