import Foundation
import SQLite3

final class SQLiteDB {

    enum SQLiteError: Error {
        case openFailed(message: String)
        case prepareFailed(message: String)
        case bindFailed(message: String)
        case stepFailed(message: String)
    }

    // sqlite3_bind_text destructor: "SQLite가 문자열을 복사해서 보관"
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let db: OpaquePointer?

    init(path: String) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil)
        if result != SQLITE_OK {
            let message = SQLiteDB.errorMessage(from: handle)
            if let handle { sqlite3_close(handle) }
            throw SQLiteError.openFailed(message: message)
        }
        self.db = handle
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        guard let db else {
            throw SQLiteError.prepareFailed(message: "Database not opened")
        }
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        if result != SQLITE_OK {
            let message = SQLiteDB.errorMessage(from: db)
            throw SQLiteError.prepareFailed(message: message)
        }
        // statement가 nil이면 prepare 실패로 봐야 함
        guard let stmt = statement else {
            throw SQLiteError.prepareFailed(message: "sqlite3_prepare_v2 returned nil statement")
        }
        return stmt
    }

    func finalize(_ statement: OpaquePointer) {
        sqlite3_finalize(statement)
    }

    func bind(_ value: Int, to index: Int32, in statement: OpaquePointer) throws {
        let result = sqlite3_bind_int(statement, index, Int32(value))
        if result != SQLITE_OK {
            let message = SQLiteDB.errorMessage(from: db)
            throw SQLiteError.bindFailed(message: message)
        }
    }

    func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) throws {
        if let value {
            // String -> UTF8 CString 포인터로 안전하게 바인딩
            try value.withCString { cString in
                let result = sqlite3_bind_text(statement, index, cString, -1, SQLiteDB.sqliteTransient)
                if result != SQLITE_OK {
                    let message = SQLiteDB.errorMessage(from: db)
                    throw SQLiteError.bindFailed(message: message)
                }
            }
        } else {
            let result = sqlite3_bind_null(statement, index)
            if result != SQLITE_OK {
                let message = SQLiteDB.errorMessage(from: db)
                throw SQLiteError.bindFailed(message: message)
            }
        }
    }

    /// true: SQLITE_ROW (row 있음), false: SQLITE_DONE (끝)
    func step(_ statement: OpaquePointer) throws -> Bool {
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            let message = SQLiteDB.errorMessage(from: db)
            throw SQLiteError.stepFailed(message: message)
        }
    }

    static func errorMessage(from db: OpaquePointer?) -> String {
        guard let db, let cString = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: cString)
    }
}
