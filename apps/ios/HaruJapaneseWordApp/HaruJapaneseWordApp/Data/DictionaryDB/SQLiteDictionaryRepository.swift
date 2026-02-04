import Foundation
import SQLite3

final class SQLiteDictionaryRepository: DictionaryRepository {
    enum RepositoryError: Error {
        case databaseNotFound
        case fileCopyFailed(message: String)
        case schemaVerificationFailed(message: String)
        case recoveryFailed(message: String)
    }

    private var db: SQLiteDB
    private let openFlags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    private var hasLoggedFirstFetch: Bool = false

    init(bundle: Bundle = .main) throws {
        let bundledURL = bundle.url(
            forResource: "jlpt_starter",
            withExtension: "sqlite",
            subdirectory: "Dictionary"
        ) ?? bundle.url(forResource: "jlpt_starter", withExtension: "sqlite")

        print("[DB] bundled path=\(bundledURL?.path ?? "nil") \(SQLiteDictionaryRepository.fileInfo(for: bundledURL))")

        guard let sourceURL = bundledURL else {
            throw RepositoryError.databaseNotFound
        }

        let writableURL = try SQLiteDictionaryRepository.writableDatabaseURL()
        print("[DB] writable path=\(writableURL.path) \(SQLiteDictionaryRepository.fileInfo(for: writableURL))")

        try SQLiteDictionaryRepository.copyBundledDatabaseIfNeeded(
            from: sourceURL,
            to: writableURL,
            force: false
        )
        print("[DB] writable path=\(writableURL.path) \(SQLiteDictionaryRepository.fileInfo(for: writableURL))")

        self.db = try SQLiteDB(path: writableURL.path, flags: openFlags)
        print("[DB] open flags=READWRITE")
        configureJournalMode(db: db)
        try verifySchemaOrRecover(bundledURL: sourceURL, writableURL: writableURL)
        try logDataCounts(db: db)
    }

    func fetchWords(level: JLPTLevel, limit: Int?, offset: Int?) throws -> [WordSummary] {
        if hasLoggedFirstFetch == false {
            print("[DB] fetchWords level=\(level.rawValue)")
            hasLoggedFirstFetch = true
        }
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
            let id = SQLiteDB.columnInt(statement, 0)
            let expression = SQLiteDB.columnText(statement, 1) ?? ""
            let reading = SQLiteDB.columnText(statement, 2) ?? ""
            let meanings = SQLiteDB.columnText(statement, 3) ?? ""
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
            let id = SQLiteDB.columnInt(statement, 0)
            let expression = SQLiteDB.columnText(statement, 1) ?? ""
            let reading = SQLiteDB.columnText(statement, 2) ?? ""
            let meanings = SQLiteDB.columnText(statement, 3) ?? ""
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

        let id = SQLiteDB.columnInt(wordStatement, 0)
        let expression = SQLiteDB.columnText(wordStatement, 1) ?? ""
        let reading = SQLiteDB.columnText(wordStatement, 2) ?? ""

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
            if let text = SQLiteDB.columnText(meaningStatement, 0) {
                meanings.append(text)
            }
        }

        return WordDetail(
            id: id,
            expression: expression,
            reading: reading,
            meanings: meanings
        )
    }

    func fetchWordSummary(wordId: Int) throws -> WordSummary? {
        let sql = """
        SELECT w.id, w.expression, w.reading,
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
        let expression = SQLiteDB.columnText(statement, 1) ?? ""
        let reading = SQLiteDB.columnText(statement, 2) ?? ""
        let meanings = SQLiteDB.columnText(statement, 3) ?? ""
        return WordSummary(id: id, expression: expression, reading: reading, meanings: meanings)
    }

    func randomWord(level: JLPTLevel) throws -> WordSummary? {
        let sql = """
        SELECT w.id, w.expression, w.reading,
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
        let expression = SQLiteDB.columnText(statement, 1) ?? ""
        let reading = SQLiteDB.columnText(statement, 2) ?? ""
        let meanings = SQLiteDB.columnText(statement, 3) ?? ""
        return WordSummary(id: id, expression: expression, reading: reading, meanings: meanings)
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

    private func randomWordId(level: JLPTLevel, excluding ids: Set<Int>) throws -> Int? {
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

    private static func writableDatabaseURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dirURL = baseURL.appendingPathComponent("DictionaryDB", isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL.appendingPathComponent("jlpt_starter.sqlite", isDirectory: false)
    }

    private static func fileInfo(for url: URL?) -> String {
        guard let url else {
            return "exists=false size=0 modified=nil"
        }
        let path = url.path
        let exists = FileManager.default.fileExists(atPath: path)
        guard exists else {
            return "exists=false size=0 modified=nil"
        }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let modified = attrs[.modificationDate] as? Date
            let formatter = ISO8601DateFormatter()
            let modifiedString = modified.map { formatter.string(from: $0) } ?? "nil"
            return "exists=true size=\(size) modified=\(modifiedString)"
        } catch {
            return "exists=true size=0 modified=error"
        }
    }

    private static func copyBundledDatabaseIfNeeded(from bundledURL: URL, to writableURL: URL, force: Bool) throws {
        let fileManager = FileManager.default
        if force, fileManager.fileExists(atPath: writableURL.path) {
            try fileManager.removeItem(at: writableURL)
        }
        if !fileManager.fileExists(atPath: writableURL.path) {
            do {
                try fileManager.copyItem(at: bundledURL, to: writableURL)
            } catch {
                throw RepositoryError.fileCopyFailed(message: "copy failed: \(error)")
            }
        }
    }

    private func configureJournalMode(db: SQLiteDB) {
        if let before = try? readSingleText(sql: "PRAGMA journal_mode;", db: db) {
            print("[DB] journal_mode(before)=\(before)")
        }
        if let result = try? readSingleText(sql: "PRAGMA journal_mode=DELETE;", db: db) {
            print("[DB] journal_mode(set)=\(result)")
        }
        if let after = try? readSingleText(sql: "PRAGMA journal_mode;", db: db) {
            print("[DB] journal_mode(after)=\(after)")
        }
    }

    private func verifySchemaOrRecover(bundledURL: URL, writableURL: URL) throws {
        do {
            let verification = try verifySchema()
            if verification.hasRequiredTables == false {
                print("[DB] has_required_tables=false")
                print("[DB] recovery: closing db before replacing file")
                self.db.close()
                print("[DB] recovery: deleting writable db and recopying from bundle")
                try SQLiteDictionaryRepository.copyBundledDatabaseIfNeeded(
                    from: bundledURL,
                    to: writableURL,
                    force: true
                )
                print("[DB] writable path=\(writableURL.path) \(SQLiteDictionaryRepository.fileInfo(for: writableURL))")
                let recoveredDB = try SQLiteDB(path: writableURL.path, flags: openFlags)
                print("[DB] open flags=READWRITE (recovered)")
                configureJournalMode(db: recoveredDB)
                let recoveredVerification = try verifySchema(using: recoveredDB)
                if recoveredVerification.hasRequiredTables == false {
                    throw RepositoryError.recoveryFailed(
                        message: "recovery failed: required tables missing"
                    )
                }
                self.db = recoveredDB
                try logDataCounts(db: recoveredDB)
            } else {
                print("[DB] has_required_tables=true")
            }
        } catch {
            throw RepositoryError.schemaVerificationFailed(message: "\(error)")
        }
    }

    private struct SchemaVerification {
        let userVersion: Int
        let hasRequiredTables: Bool
    }

    private func verifySchema(using database: SQLiteDB? = nil) throws -> SchemaVerification {
        let database = database ?? db

        let userVersion = try readSingleInt(sql: "PRAGMA user_version;", db: database)
        print("[DB] user_version=\(userVersion)")

        if let integrity = try? readSingleText(sql: "PRAGMA integrity_check;", db: database) {
            print("[DB] integrity_check=\(integrity)")
        }

        let tables = try readAllText(sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;", db: database)
        print("[DB] tables=\(tables)")

        let required = try readAllText(
            sql: "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('word','meaning');",
            db: database
        )
        let hasRequired = required.contains("word") && required.contains("meaning")
        print("[DB] has_required_tables=\(hasRequired)")
        return SchemaVerification(userVersion: userVersion, hasRequiredTables: hasRequired)
    }

    private func readSingleText(sql: String, db: SQLiteDB? = nil) throws -> String {
        let database = db ?? self.db
        let statement = try database.prepare(sql)
        defer { database.finalize(statement) }
        guard try database.step(statement) else {
            return ""
        }
        return SQLiteDB.columnText(statement, 0) ?? ""
    }

    private func readSingleInt(sql: String, db: SQLiteDB? = nil) throws -> Int {
        let database = db ?? self.db
        let statement = try database.prepare(sql)
        defer { database.finalize(statement) }
        guard try database.step(statement) else {
            return 0
        }
        return SQLiteDB.columnInt(statement, 0)
    }

    private func readAllText(sql: String, db: SQLiteDB? = nil) throws -> [String] {
        let database = db ?? self.db
        let statement = try database.prepare(sql)
        defer { database.finalize(statement) }
        var results: [String] = []
        while try database.step(statement) {
            if let value = SQLiteDB.columnText(statement, 0) {
                results.append(value)
            }
        }
        return results
    }

    private func readPairs(sql: String, db: SQLiteDB? = nil) throws -> [(String, Int)] {
        let database = db ?? self.db
        let statement = try database.prepare(sql)
        defer { database.finalize(statement) }
        var results: [(String, Int)] = []
        while try database.step(statement) {
            let key = SQLiteDB.columnText(statement, 0) ?? ""
            let value = SQLiteDB.columnInt(statement, 1)
            results.append((key, value))
        }
        return results
    }

    private func logDataCounts(db: SQLiteDB) throws {
        let total = try readSingleInt(sql: "SELECT COUNT(*) FROM word;", db: db)
        print("[DB] word_count=\(total)")
        let byLevel = try readPairs(sql: "SELECT level, COUNT(*) FROM word GROUP BY level;", db: db)
        print("[DB] by_level=\(byLevel)")
    }
}
