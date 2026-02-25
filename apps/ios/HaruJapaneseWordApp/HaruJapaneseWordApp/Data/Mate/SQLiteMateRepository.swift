import Foundation
import SQLite3

final class SQLiteMateRepository {
    enum MateRepositoryError: Error {
        case roomAlreadyExists
        case invalidInviteCode
        case roomAlreadyMatched
        case cannotJoinOwnInvite
        case senderNotInRoom
        case cannotSendPoke
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

    func createInviteCode(for userId: String, now: Date = Date()) -> String {
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

    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date = Date()) throws -> MateRoom {
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

    func canSendPoke(room: MateRoom, senderId: String, todayKey: String) -> Bool {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let pendingSql = """
            SELECT COUNT(*)
            FROM mate_poke
            WHERE room_id = ? AND sender_id = ? AND consumed_at IS NULL;
            """
            let pendingStmt = try db.prepare(pendingSql)
            defer { db.finalize(pendingStmt) }
            try db.bind(room.id, to: 1, in: pendingStmt)
            try db.bind(senderId, to: 2, in: pendingStmt)
            if try db.step(pendingStmt) {
                let count = SQLiteDB.columnInt(pendingStmt, 0)
                if count > 0 {
                    return false
                }
            }

            let dailySql = """
            SELECT COUNT(*)
            FROM mate_poke
            WHERE room_id = ? AND sender_id = ? AND date_key_kst = ?;
            """
            let dailyStmt = try db.prepare(dailySql)
            defer { db.finalize(dailyStmt) }
            try db.bind(room.id, to: 1, in: dailyStmt)
            try db.bind(senderId, to: 2, in: dailyStmt)
            try db.bind(todayKey, to: 3, in: dailyStmt)
            if try db.step(dailyStmt) {
                let count = SQLiteDB.columnInt(dailyStmt, 0)
                if count > 0 {
                    return false
                }
            }
        } catch {
            print("[SQLiteMateRepository] canSendPoke failed: \(error)")
        }
        return true
    }

    func sendPoke(roomId: Int, senderId: String, wordId: Int, now: Date, todayKey: String) throws {
        guard let room = fetchRoomById(roomId) else {
            throw MateRepositoryError.senderNotInRoom
        }
        let receiverId: String
        if room.userAId == senderId {
            receiverId = room.userBId
        } else if room.userBId == senderId {
            receiverId = room.userAId
        } else {
            throw MateRepositoryError.senderNotInRoom
        }
        if canSendPoke(room: room, senderId: senderId, todayKey: todayKey) == false {
            throw MateRepositoryError.cannotSendPoke
        }
        let nowEpoch = Int(now.timeIntervalSince1970)
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            INSERT INTO mate_poke (room_id, sender_id, receiver_id, word_id, created_at, date_key_kst, consumed_at)
            VALUES (?, ?, ?, ?, ?, ?, NULL);
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(roomId, to: 1, in: stmt)
            try db.bind(senderId, to: 2, in: stmt)
            try db.bind(receiverId, to: 3, in: stmt)
            try db.bind(wordId, to: 4, in: stmt)
            try db.bind(nowEpoch, to: 5, in: stmt)
            try db.bind(todayKey, to: 6, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] sendPoke failed: \(error)")
        }
        touchLastInteraction(roomId: roomId, at: now)
    }

    func fetchInboxPokes(userId: String) -> [MatePoke] {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = """
            SELECT id, room_id, sender_id, receiver_id, word_id, created_at, date_key_kst, consumed_at
            FROM mate_poke
            WHERE receiver_id = ? AND consumed_at IS NULL
            ORDER BY created_at DESC;
            """
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(userId, to: 1, in: stmt)
            var result: [MatePoke] = []
            while try db.step(stmt) {
                let id = SQLiteDB.columnInt(stmt, 0)
                let roomId = SQLiteDB.columnInt(stmt, 1)
                let senderId = SQLiteDB.columnText(stmt, 2) ?? ""
                let receiverId = SQLiteDB.columnText(stmt, 3) ?? ""
                let wordId = SQLiteDB.columnInt(stmt, 4)
                let createdAt = Date(timeIntervalSince1970: TimeInterval(SQLiteDB.columnInt(stmt, 5)))
                let dateKey = SQLiteDB.columnText(stmt, 6) ?? ""
                let consumedEpoch = SQLiteDB.columnInt(stmt, 7)
                let consumedAt = consumedEpoch > 0 ? Date(timeIntervalSince1970: TimeInterval(consumedEpoch)) : nil
                result.append(
                    MatePoke(
                        id: id,
                        roomId: roomId,
                        senderId: senderId,
                        receiverId: receiverId,
                        wordId: wordId,
                        createdAt: createdAt,
                        dateKeyKST: dateKey,
                        consumedAt: consumedAt
                    )
                )
            }
            return result
        } catch {
            print("[SQLiteMateRepository] fetchInboxPokes failed: \(error)")
            return []
        }
    }

    func markPokeConsumed(pokeId: Int, consumedAt: Date) {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = "UPDATE mate_poke SET consumed_at = ? WHERE id = ?;"
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(Int(consumedAt.timeIntervalSince1970), to: 1, in: stmt)
            try db.bind(pokeId, to: 2, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] markPokeConsumed failed: \(error)")
        }
    }

    func touchLastInteraction(roomId: Int, at: Date) {
        do {
            let db = try SQLiteDB(path: dbPath, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            defer { db.close() }
            let sql = "UPDATE mate_room SET last_interaction_at = ? WHERE id = ?;"
            let stmt = try db.prepare(sql)
            defer { db.finalize(stmt) }
            try db.bind(Int(at.timeIntervalSince1970), to: 1, in: stmt)
            try db.bind(roomId, to: 2, in: stmt)
            _ = try db.step(stmt)
        } catch {
            print("[SQLiteMateRepository] touchLastInteraction failed: \(error)")
        }
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
                created_at TEXT NOT NULL,
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
                sender_id TEXT NOT NULL,
                word_id INTEGER NOT NULL,
                created_at TEXT NOT NULL,
                receiver_id TEXT NOT NULL,
                date_key_kst TEXT NOT NULL,
                consumed_at INTEGER
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

            let checkSql = """
            SELECT name
            FROM sqlite_master
            WHERE type='table' AND name IN ('mate_room','mate_poke','mate_daily_status')
            ORDER BY name;
            """
            let checkStmt = try db.prepare(checkSql)
            defer { db.finalize(checkStmt) }
            var tables: [String] = []
            while try db.step(checkStmt) {
                if let name = SQLiteDB.columnText(checkStmt, 0) {
                    tables.append(name)
                }
            }
            let hasRoom = tables.contains("mate_room")
            let hasPoke = tables.contains("mate_poke")
            let hasDaily = tables.contains("mate_daily_status")
            print("[SQLiteMateRepository] mate_tables=\(tables)")
            print("[SQLiteMateRepository] mate_room_exists=\(hasRoom) mate_poke_exists=\(hasPoke) mate_daily_status_exists=\(hasDaily)")
        } catch {
            print("[SQLiteMateRepository] ensureSchema failed: \(error)")
        }
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
