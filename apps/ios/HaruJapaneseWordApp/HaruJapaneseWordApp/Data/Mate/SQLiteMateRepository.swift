import Foundation
import SQLite3

final class SQLiteMateRepository: MateRepositoryProtocol {
    enum MateRepositoryError: Error {
        case roomAlreadyExists
        case invalidInviteCode
        case roomAlreadyMatched
        case cannotJoinOwnInvite
        case senderNotInRoom
        case alreadyPokedToday
    }

    private let dbPath: String

    init() {
        self.dbPath = Self.writableDatabaseURL().path
        ensureSchema()
    }

    func fetchActiveRoom(for userId: String) -> MateRoom? {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            SELECT id, user_a_id, user_b_id, invite_code, created_at, last_interaction_at, is_active
            FROM mate_room
            WHERE is_active = 1 AND (user_a_id = ? OR user_b_id = ?)
            ORDER BY id DESC
            LIMIT 1;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(userId, to: 1, in: stmt)
            try db.bind(userId, to: 2, in: stmt)
            if try db.step(stmt) {
                return Self.readRoom(from: stmt)
            }
        } catch {
            print("[SQLiteMateRepository] fetchActiveRoom failed: \(error)")
        }
        return nil
    }

    func fetchActiveRooms(for userId: String) -> [MateRoom] {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            SELECT id, user_a_id, user_b_id, invite_code, created_at, last_interaction_at, is_active
            FROM mate_room
            WHERE is_active = 1 AND (user_a_id = ? OR user_b_id = ?)
            ORDER BY id DESC;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(userId, to: 1, in: stmt)
            try db.bind(userId, to: 2, in: stmt)

            var rooms: [MateRoom] = []
            while try db.step(stmt) {
                rooms.append(Self.readRoom(from: stmt))
            }
            return rooms
        } catch {
            print("[SQLiteMateRepository] fetchActiveRooms failed: \(error)")
            return []
        }
    }

    func createInviteCode(for userId: String, now: Date) -> String {
        if let room = fetchActiveRoom(for: userId) {
            return room.inviteCode
        }
        let inviteCode = generateInviteCode()
        let nowEpoch = Int(now.timeIntervalSince1970)
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            INSERT INTO mate_room (user_a_id, user_b_id, invite_code, created_at, last_interaction_at, is_active)
            VALUES (?, ?, ?, ?, ?, 1);
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(userId, to: 1, in: stmt)
            try db.bind("", to: 2, in: stmt)
            try db.bind(inviteCode, to: 3, in: stmt)
            try db.bind(nowEpoch, to: 4, in: stmt)
            try db.bind(nowEpoch, to: 5, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] createInviteCode failed: \(error)")
        }
        return inviteCode
    }

    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date) throws -> MateRoom {
        if fetchActiveRoom(for: joinerId) != nil {
            throw MateRepositoryError.roomAlreadyExists
        }
        guard let room = fetchRoomByInvite(inviteCode: inviteCode) else {
            throw MateRepositoryError.invalidInviteCode
        }
        if room.userBId.isEmpty == false {
            throw MateRepositoryError.roomAlreadyMatched
        }
        if room.userAId == joinerId {
            throw MateRepositoryError.cannotJoinOwnInvite
        }
        print("[SQLiteMateRepository] joinByInviteCode write_begin userId=\(joinerId) inviteCode=\(inviteCode)")
        var db: SQLiteDB?
        do {
            db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db?.close() }
            let sql = """
            UPDATE mate_room
            SET user_b_id = ?
            WHERE id = ?;
            """
            let stmt = try db!.prepare(sql)
            defer { db!.finalize(stmt) }
            try db!.bind(joinerId, to: 1, in: stmt)
            try db!.bind(room.id, to: 2, in: stmt)
            _ = try db!.step(stmt)
        } catch {
            let sqliteCode = SQLiteDB.errorCode(from: db?.rawHandle)
            let sqliteMessage = SQLiteDB.errorMessage(from: db?.rawHandle)
            print(
                "[SQLiteMateRepository] joinByInviteCode failed: \(error.localizedDescription) " +
                    "sqlite_code=\(sqliteCode) sqlite_message=\(sqliteMessage)"
            )
        }
        if let updated = fetchActiveRoom(for: joinerId) {
            print("MATE_ROOM_WRITE_OK roomId=\(updated.id) userA=\(updated.userAId) userB=\(updated.userBId)")
            return updated
        }
        return room
    }

    func endRoom(roomId: Int, reason: String) {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = "UPDATE mate_room SET is_active = 0 WHERE id = ?;"
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(roomId, to: 1, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] endRoom failed: \(error)")
        }
    }

    func fetchRoomForUser(userId: String) throws -> MateRoom? {
        fetchActiveRoom(for: userId)
    }

    func hasSentPokeToday(roomId: Int, fromUserId: String, now: Date) throws -> Bool {
        let range = dayEpochRange(for: now)
        let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { db.close() }
        return try hasSentPokeToday(
            in: db,
            roomId: roomId,
            fromUserId: fromUserId,
            startEpoch: range.start,
            endEpoch: range.end
        )
    }

    func sendPoke(roomId: Int, fromUserId: String, now: Date) throws -> MatePoke {
        guard let room = fetchRoomById(roomId) else {
            throw MatePokeError.senderNotInRoom
        }
        let toUserId: String
        if room.userAId == fromUserId {
            toUserId = room.userBId
        } else if room.userBId == fromUserId {
            toUserId = room.userAId
        } else {
            throw MatePokeError.senderNotInRoom
        }
        guard toUserId.isEmpty == false else {
            throw MatePokeError.senderNotInRoom
        }

        let nowEpoch = Int(now.timeIntervalSince1970)
        let range = dayEpochRange(for: now)
        let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { db.close() }

        guard let handle = db.rawHandle else { throw MatePokeError.noActiveRoom }
        if sqlite3_exec(handle, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) != SQLITE_OK {
            throw SQLiteDB.SQLiteError.stepFailed(message: SQLiteDB.errorMessage(from: handle))
        }
        var committed = false
        defer {
            if committed == false {
                _ = sqlite3_exec(handle, "ROLLBACK", nil, nil, nil)
            }
        }

        let alreadySent = try hasSentPokeToday(
            in: db,
            roomId: roomId,
            fromUserId: fromUserId,
            startEpoch: range.start,
            endEpoch: range.end
        )
        if alreadySent {
            throw MatePokeError.alreadyPokedToday
        }

        let insertSql = """
        INSERT INTO mate_poke (room_id, from_user_id, to_user_id, created_at)
        VALUES (?, ?, ?, ?);
        """
        let insertStmt = try db.prepare(insertSql)
        defer { db.finalize(insertStmt) }
        try db.bind(roomId, to: 1, in: insertStmt)
        try db.bind(fromUserId, to: 2, in: insertStmt)
        try db.bind(toUserId, to: 3, in: insertStmt)
        try db.bind(nowEpoch, to: 4, in: insertStmt)
        _ = try db.step(insertStmt)

        let touchSql = "UPDATE mate_room SET last_interaction_at = ? WHERE id = ?;"
        let touchStmt = try db.prepare(touchSql)
        defer { db.finalize(touchStmt) }
        try db.bind(nowEpoch, to: 1, in: touchStmt)
        try db.bind(roomId, to: 2, in: touchStmt)
        _ = try db.step(touchStmt)

        if sqlite3_exec(handle, "COMMIT", nil, nil, nil) != SQLITE_OK {
            throw SQLiteDB.SQLiteError.stepFailed(message: SQLiteDB.errorMessage(from: handle))
        }
        committed = true

        let pokeId = Int(sqlite3_last_insert_rowid(handle))
        return MatePoke(id: pokeId, roomId: roomId, fromUserId: fromUserId, toUserId: toUserId, createdAt: now)
    }

    func fetchLatestPoke(roomId: Int) throws -> MatePoke? {
        let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { db.close() }
        let sql = """
        SELECT id, room_id, from_user_id, to_user_id, created_at
        FROM mate_poke
        WHERE room_id = ?
        ORDER BY created_at DESC
        LIMIT 1;
        """
        let stmt = try db.prepare(sql)
        defer { db.finalize(stmt) }
        try db.bind(roomId, to: 1, in: stmt)
        if try db.step(stmt) {
            return Self.readPoke(from: stmt)
        }
        return nil
    }

    func touchInteraction(roomId: Int, at: Date) throws {
        let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { db.close() }
        let sql = "UPDATE mate_room SET last_interaction_at = ? WHERE id = ?;"
        let stmt = try db.prepare(sql)
        defer { db.finalize(stmt) }
        try db.bind(Int(at.timeIntervalSince1970), to: 1, in: stmt)
        try db.bind(roomId, to: 2, in: stmt)
        _ = try db.step(stmt)
    }

    func cleanupExpiredRooms(now: Date) {
        let cutoff = Int(now.timeIntervalSince1970 - 7 * 24 * 60 * 60)
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            UPDATE mate_room
            SET is_active = 0
            WHERE is_active = 1 AND last_interaction_at <= ?;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(cutoff, to: 1, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] cleanupExpiredRooms failed: \(error)")
        }
    }

    private func fetchRoomById(_ roomId: Int) -> MateRoom? {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            SELECT id, user_a_id, user_b_id, invite_code, created_at, last_interaction_at, is_active
            FROM mate_room
            WHERE id = ?;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(roomId, to: 1, in: stmt)
            if try db.step(stmt) {
                return Self.readRoom(from: stmt)
            }
        } catch {
            print("[SQLiteMateRepository] fetchRoomById failed: \(error)")
        }
        return nil
    }

    private func fetchRoomByInvite(inviteCode: String) -> MateRoom? {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            SELECT id, user_a_id, user_b_id, invite_code, created_at, last_interaction_at, is_active
            FROM mate_room
            WHERE invite_code = ? AND is_active = 1
            ORDER BY id DESC
            LIMIT 1;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(inviteCode, to: 1, in: stmt)
            if try db.step(stmt) {
                return Self.readRoom(from: stmt)
            }
        } catch {
            print("[SQLiteMateRepository] fetchRoomByInvite failed: \(error)")
        }
        return nil
    }

    private func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        while true {
            let code = String((0..<6).map { _ in chars.randomElement()! })
            if inviteCodeExists(code) == false {
                return code
            }
        }
    }

    private func inviteCodeExists(_ code: String) -> Bool {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = "SELECT COUNT(*) FROM mate_room WHERE invite_code = ? AND is_active = 1;"
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(code, to: 1, in: stmt)
            if try db.step(stmt) {
                return SQLiteDB.columnInt(stmt, 0) > 0
            }
        } catch {
            print("[SQLiteMateRepository] inviteCodeExists failed: \(error)")
        }
        return false
    }

    private func ensureSchema() {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let roomSql = """
            CREATE TABLE IF NOT EXISTS mate_room (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_a_id TEXT NOT NULL,
                user_b_id TEXT NOT NULL,
                invite_code TEXT NOT NULL UNIQUE,
                created_at INTEGER NOT NULL,
                last_poke_at TEXT NULL,
                ended_at TEXT NULL,
                last_interaction_at INTEGER NOT NULL,
                is_active INTEGER NOT NULL
            );
            """
            let roomStmt = try db.prepare(roomSql)
            defer { db.finalize(roomStmt) }
            _ = try db.step(roomStmt)

            let pokeSql = """
            CREATE TABLE IF NOT EXISTS mate_poke (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id INTEGER NOT NULL,
                from_user_id TEXT NOT NULL,
                to_user_id TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );
            """
            let pokeStmt = try db.prepare(pokeSql)
            defer { db.finalize(pokeStmt) }
            _ = try db.step(pokeStmt)

            let dailySql = """
            CREATE TABLE IF NOT EXISTS mate_daily_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                date_key TEXT NOT NULL,
                did_study INTEGER NOT NULL DEFAULT 0,
                UNIQUE(user_id, date_key)
            );
            """
            let dailyStmt = try db.prepare(dailySql)
            defer { db.finalize(dailyStmt) }
            _ = try db.step(dailyStmt)

            try ensureRoomColumns(db)
            try ensurePokeColumns(db)
            try ensurePokeIndices(db)
        } catch {
            print("[SQLiteMateRepository] ensureSchema failed: \(error)")
        }
    }

    private func ensureRoomColumns(_ db: SQLiteDB) throws {
        let columns = try columnNames(tableName: "mate_room", db: db)
        guard columns.contains("last_interaction_at") == false else { return }
        let alterSql = "ALTER TABLE mate_room ADD COLUMN last_interaction_at INTEGER NOT NULL DEFAULT 0;"
        let alterStmt = try db.prepare(alterSql)
        defer { db.finalize(alterStmt) }
        _ = try db.step(alterStmt)
    }

    private func ensurePokeColumns(_ db: SQLiteDB) throws {
        var columns = try columnNames(tableName: "mate_poke", db: db)

        if columns.contains("from_user_id") == false {
            let stmt = try db.prepare("ALTER TABLE mate_poke ADD COLUMN from_user_id TEXT;")
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
            columns.insert("from_user_id")
        }
        if columns.contains("to_user_id") == false {
            let stmt = try db.prepare("ALTER TABLE mate_poke ADD COLUMN to_user_id TEXT;")
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
            columns.insert("to_user_id")
        }
        if columns.contains("created_at") == false {
            let stmt = try db.prepare("ALTER TABLE mate_poke ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0;")
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
            columns.insert("created_at")
        }

        if columns.contains("sender_id") {
            let stmt = try db.prepare(
                "UPDATE mate_poke SET from_user_id = COALESCE(from_user_id, sender_id) WHERE from_user_id IS NULL OR from_user_id = '';"
            )
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
        }
        if columns.contains("receiver_id") {
            let stmt = try db.prepare(
                "UPDATE mate_poke SET to_user_id = COALESCE(to_user_id, receiver_id) WHERE to_user_id IS NULL OR to_user_id = '';"
            )
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
        }
    }

    private func ensurePokeIndices(_ db: SQLiteDB) throws {
        let indexSqlList = [
            "CREATE INDEX IF NOT EXISTS idx_mate_poke_room_created ON mate_poke(room_id, created_at);",
            "CREATE INDEX IF NOT EXISTS idx_mate_poke_from_day ON mate_poke(from_user_id, created_at);"
        ]
        for sql in indexSqlList {
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            _ = try db.step(stmt)
        }
    }

    private func columnNames(tableName: String, db: SQLiteDB) throws -> Set<String> {
        let stmt = try db.prepare("PRAGMA table_info(\(tableName));")
        defer { db.finalize(stmt) }
        var names: Set<String> = []
        while try db.step(stmt) {
            if let name = SQLiteDB.columnText(stmt, 1) {
                names.insert(name)
            }
        }
        return names
    }

    private func dayEpochRange(for now: Date) -> (start: Int, end: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) else {
            let epoch = Int(now.timeIntervalSince1970)
            return (epoch, epoch)
        }
        return (Int(start.timeIntervalSince1970), Int(end.timeIntervalSince1970))
    }

    private func hasSentPokeToday(
        in db: SQLiteDB,
        roomId: Int,
        fromUserId: String,
        startEpoch: Int,
        endEpoch: Int
    ) throws -> Bool {
        let sql = """
        SELECT COUNT(*)
        FROM mate_poke
        WHERE room_id = ?
          AND from_user_id = ?
          AND created_at BETWEEN ? AND ?;
        """
        let stmt = try db.prepare(sql)
        defer { db.finalize(stmt) }
        try db.bind(roomId, to: 1, in: stmt)
        try db.bind(fromUserId, to: 2, in: stmt)
        try db.bind(startEpoch, to: 3, in: stmt)
        try db.bind(endEpoch, to: 4, in: stmt)
        if try db.step(stmt) {
            return SQLiteDB.columnInt(stmt, 0) > 0
        }
        return false
    }

    private static func readRoom(from stmt: OpaquePointer) -> MateRoom {
        let id = SQLiteDB.columnInt(stmt, 0)
        let userAId = SQLiteDB.columnText(stmt, 1) ?? ""
        let userBId = SQLiteDB.columnText(stmt, 2) ?? ""
        let inviteCode = SQLiteDB.columnText(stmt, 3) ?? ""
        let createdAt = Date(timeIntervalSince1970: TimeInterval(SQLiteDB.columnInt(stmt, 4)))
        let lastInteractionAt = Date(timeIntervalSince1970: TimeInterval(SQLiteDB.columnInt(stmt, 5)))
        let isActive = SQLiteDB.columnInt(stmt, 6) == 1
        return MateRoom(
            id: id,
            userAId: userAId,
            userBId: userBId,
            inviteCode: inviteCode,
            createdAt: createdAt,
            lastInteractionAt: lastInteractionAt,
            isActive: isActive
        )
    }

    private static func readPoke(from stmt: OpaquePointer) -> MatePoke {
        MatePoke(
            id: SQLiteDB.columnInt(stmt, 0),
            roomId: SQLiteDB.columnInt(stmt, 1),
            fromUserId: SQLiteDB.columnText(stmt, 2) ?? "",
            toUserId: SQLiteDB.columnText(stmt, 3) ?? "",
            createdAt: Date(timeIntervalSince1970: TimeInterval(SQLiteDB.columnInt(stmt, 4)))
        )
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
