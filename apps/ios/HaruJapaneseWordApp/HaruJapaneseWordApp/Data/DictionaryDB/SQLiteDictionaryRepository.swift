import Foundation
import SQLite3

final class SQLiteDictionaryRepository: DictionaryRepository {
    enum RepositoryError: Error {
        case databaseNotFound
    }

    private let db: SQLiteDB

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(
            forResource: "jlpt_starter",
            withExtension: "sqlite",
            subdirectory: "Dictionary"
        ) ?? bundle.url(forResource: "jlpt_starter", withExtension: "sqlite") else {
            throw RepositoryError.databaseNotFound
        }
        self.db = try SQLiteDB(path: url.path)
    }

    func fetchWords(level: JLPTLevel, limit: Int?, offset: Int?) throws -> [WordSummary] {
        let sql = """
        SELECT w.id, w.expression, w.reading,
               GROUP_CONCAT(m.text, ' / ') AS meanings
        FROM word w
        LEFT JOIN meaning m ON m.word_id = w.id
        WHERE w.level = ?
        GROUP BY w.id
        ORDER BY w.expression
        LIMIT ? OFFSET ?;
        """

        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }

        try db.bind(level.rawValue, to: 1, in: statement)
        try db.bind(limit ?? -1, to: 2, in: statement)
        try db.bind(offset ?? 0, to: 3, in: statement)

        var results: [WordSummary] = []
        while try db.step(statement) {
            let id = Int(sqlite3_column_int(statement, 0))
            let expression = SQLiteDictionaryRepository.columnText(statement, index: 1)
            let reading = SQLiteDictionaryRepository.columnText(statement, index: 2)
            let meanings = SQLiteDictionaryRepository.columnText(statement, index: 3)
            results.append(
                WordSummary(
                    id: id,
                    expression: expression,
                    reading: reading,
                    meanings: meanings
                )
            )
        }
        return results
    }

    func searchWords(level: JLPTLevel, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        let sql = """
        SELECT w.id, w.expression, w.reading,
               GROUP_CONCAT(m.text, ' / ') AS meanings
        FROM word w
        LEFT JOIN meaning m ON m.word_id = w.id
        WHERE w.level = ? AND (w.expression LIKE ? OR w.reading LIKE ?)
        GROUP BY w.id
        ORDER BY w.expression
        LIMIT ? OFFSET ?;
        """

        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }

        let likeQuery = "%\(query)%"
        try db.bind(level.rawValue, to: 1, in: statement)
        try db.bind(likeQuery, to: 2, in: statement)
        try db.bind(likeQuery, to: 3, in: statement)
        try db.bind(limit ?? -1, to: 4, in: statement)
        try db.bind(offset ?? 0, to: 5, in: statement)

        var results: [WordSummary] = []
        while try db.step(statement) {
            let id = Int(sqlite3_column_int(statement, 0))
            let expression = SQLiteDictionaryRepository.columnText(statement, index: 1)
            let reading = SQLiteDictionaryRepository.columnText(statement, index: 2)
            let meanings = SQLiteDictionaryRepository.columnText(statement, index: 3)
            results.append(
                WordSummary(
                    id: id,
                    expression: expression,
                    reading: reading,
                    meanings: meanings
                )
            )
        }
        return results
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        let wordSql = """
        SELECT w.id, w.expression, w.reading
        FROM word w
        WHERE w.id = ?;
        """

        let wordStatement = try db.prepare(wordSql)
        defer { db.finalize(wordStatement) }

        try db.bind(wordId, to: 1, in: wordStatement)

        guard try db.step(wordStatement) else {
            return nil
        }

        let id = Int(sqlite3_column_int(wordStatement, 0))
        let expression = SQLiteDictionaryRepository.columnText(wordStatement, index: 1)
        let reading = SQLiteDictionaryRepository.columnText(wordStatement, index: 2)

        let meaningSql = """
        SELECT m.text
        FROM meaning m
        WHERE m.word_id = ?
        ORDER BY m.ord;
        """

        let meaningStatement = try db.prepare(meaningSql)
        defer { db.finalize(meaningStatement) }

        try db.bind(wordId, to: 1, in: meaningStatement)

        var meanings: [String] = []
        while try db.step(meaningStatement) {
            let text = SQLiteDictionaryRepository.columnText(meaningStatement, index: 0)
            meanings.append(text)
        }

        return WordDetail(
            id: id,
            expression: expression,
            reading: reading,
            meanings: meanings
        )
    }

    private static func columnText(_ statement: OpaquePointer, index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: cString)
    }
}
