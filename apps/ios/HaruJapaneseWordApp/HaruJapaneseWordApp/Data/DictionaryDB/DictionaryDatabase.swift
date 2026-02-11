import Foundation
import SQLite3

final class DictionaryDatabase {
    enum DatabaseError: Error {
        case bundledDatabaseNotFound
        case fileCopyFailed(message: String)
    }

    private static var shared: DictionaryDatabase?
    private static let lock = NSLock()

    static func sharedDatabase() throws -> DictionaryDatabase {
        lock.lock()
        defer { lock.unlock() }
        if let shared {
            return shared
        }
        let database = try DictionaryDatabase()
        shared = database
        return database
    }

    private let queue = DispatchQueue(label: "db.queue")
    private let db: SQLiteDB

    private init(bundle: Bundle = .main) throws {
        let bundledURL = bundle.url(
            forResource: "jlpt_starter",
            withExtension: "sqlite",
            subdirectory: "Dictionary"
        ) ?? bundle.url(forResource: "jlpt_starter", withExtension: "sqlite")

        print("[DB] bundled path=\(bundledURL?.path ?? "nil") \(DictionaryDatabase.fileInfo(for: bundledURL))")

        guard let sourceURL = bundledURL else {
            throw DatabaseError.bundledDatabaseNotFound
        }

        let writableURL = try DictionaryDatabase.writableDatabaseURL()
        print("[DB] writable path=\(writableURL.path) \(DictionaryDatabase.fileInfo(for: writableURL))")

        try DictionaryDatabase.bootstrapIfNeeded(bundledURL: sourceURL, writableURL: writableURL)
        print("[DB] writable path=\(writableURL.path) \(DictionaryDatabase.fileInfo(for: writableURL))")

        self.db = try SQLiteDB(path: writableURL.path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX)
        print("[DB] open flags=READWRITE")

        try queue.sync {
            let journalMode = try readSingleText(sql: "PRAGMA journal_mode=WAL;")
            print("[DB] journal_mode=\(journalMode)")
            try applyPragma("PRAGMA synchronous=NORMAL;")
            try applyPragma("PRAGMA foreign_keys=ON;")

            #if DEBUG
            try logDebugInfo()
            #endif
        }
    }

    func read<T>(_ work: (SQLiteDB) throws -> T) throws -> T {
        try queue.sync {
            try work(db)
        }
    }

    private func applyPragma(_ sql: String) throws {
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        _ = try db.step(statement)
    }

    #if DEBUG
    private func logDebugInfo() throws {
        let integrity = try readSingleText(sql: "PRAGMA integrity_check;")
        print("[DB] integrity_check=\(integrity)")

        let tables = try readAllText(sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
        print("[DB] tables=\(tables)")
        let lyricTable = "lyric_entries"
        print("[DB] has_lyric_entries=\(tables.contains(lyricTable))")
    }
    #endif

    private func readSingleText(sql: String) throws -> String {
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        guard try db.step(statement) else {
            return ""
        }
        return SQLiteDB.columnText(statement, 0) ?? ""
    }

    private func readAllText(sql: String) throws -> [String] {
        let statement = try db.prepare(sql)
        defer { db.finalize(statement) }
        var results: [String] = []
        while try db.step(statement) {
            if let value = SQLiteDB.columnText(statement, 0) {
                results.append(value)
            }
        }
        return results
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

    private static func bootstrapIfNeeded(bundledURL: URL, writableURL: URL) throws {
        let fileManager = FileManager.default
        #if DEBUG
        let forceCopy = true
        #else
        let forceCopy = false
        #endif

        if forceCopy {
            try removeDatabaseFiles(at: writableURL)
        }

        if forceCopy || fileManager.fileExists(atPath: writableURL.path) == false {
            do {
                try fileManager.copyItem(at: bundledURL, to: writableURL)
                print(
                    "[DB] copy success src=\(bundledURL.path) \(fileInfo(for: bundledURL)) " +
                        "dst=\(writableURL.path) \(fileInfo(for: writableURL))"
                )
            } catch {
                throw DatabaseError.fileCopyFailed(message: "copy failed: \(error)")
            }
        }
    }

    private static func removeDatabaseFiles(at writableURL: URL) throws {
        let fileManager = FileManager.default
        let basePath = writableURL.path
        let paths = [basePath, basePath + "-wal", basePath + "-shm"]
        for path in paths where fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
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
}
