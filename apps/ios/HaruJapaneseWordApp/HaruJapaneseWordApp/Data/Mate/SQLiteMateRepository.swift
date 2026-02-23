import Foundation

final class SQLiteMateRepository: MateRepositoryProtocol {
    private let database: DictionaryDatabase

    init(database: DictionaryDatabase? = nil) throws {
        if let database {
            self.database = database
        } else {
            self.database = try DictionaryDatabase.sharedDatabase()
        }
    }

    func getActiveRoom(userId: String) throws -> MateRoom? {
        try database.read { db in
            let sql = """
            SELECT id, user_id, mate_user_id, mate_nickname, start_date, end_date, status
            FROM mate_room
            WHERE user_id = ? AND status IN ('active', 'paused')
            ORDER BY start_date DESC
            LIMIT 1;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(userId, to: 1, in: statement)
            guard try db.step(statement) else { return nil }
            return mapRoom(statement: statement)
        }
    }

    func getLatestRoom(userId: String) throws -> MateRoom? {
        try database.read { db in
            let sql = """
            SELECT id, user_id, mate_user_id, mate_nickname, start_date, end_date, status
            FROM mate_room
            WHERE user_id = ?
            ORDER BY start_date DESC
            LIMIT 1;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(userId, to: 1, in: statement)
            guard try db.step(statement) else { return nil }
            return mapRoom(statement: statement)
        }
    }

    func createRoom(userId: String, mateUserId: String, mateNickname: String, startDate: Date) throws -> MateRoom {
        let id = UUID().uuidString
        let startOfDay = DateKey.startOfDay(for: startDate)
        let endDate = DateKey.addingDays(30, to: startOfDay)
        let startString = DateKey.isoString(from: startOfDay)
        let endString = DateKey.isoString(from: endDate)

        try database.read { db in
            let sql = """
            INSERT INTO mate_room (id, user_id, mate_user_id, mate_nickname, start_date, end_date, status)
            VALUES (?, ?, ?, ?, ?, ?, 'active');
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(id, to: 1, in: statement)
            try db.bind(userId, to: 2, in: statement)
            try db.bind(mateUserId, to: 3, in: statement)
            try db.bind(mateNickname, to: 4, in: statement)
            try db.bind(startString, to: 5, in: statement)
            try db.bind(endString, to: 6, in: statement)
            _ = try db.step(statement)
        }

        return MateRoom(
            id: id,
            userId: userId,
            mateUserId: mateUserId,
            mateNickname: mateNickname,
            startDate: startString,
            endDate: endString,
            status: .active
        )
    }

    func updateRoomStatus(roomId: String, status: MateRoom.Status) throws {
        try database.read { db in
            let sql = "UPDATE mate_room SET status = ? WHERE id = ?;"
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(status.rawValue, to: 1, in: statement)
            try db.bind(roomId, to: 2, in: statement)
            _ = try db.step(statement)
        }
    }

    func getTodayStatus(userId: String, date: String) throws -> Bool {
        try database.read { db in
            let sql = """
            SELECT learned
            FROM mate_daily_status
            WHERE user_id = ? AND date = ?
            LIMIT 1;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(userId, to: 1, in: statement)
            try db.bind(date, to: 2, in: statement)
            guard try db.step(statement) else { return false }
            let value = SQLiteDB.columnInt(statement, 0)
            return value == 1
        }
    }

    func setTodayLearned(userId: String, date: String, learned: Bool) throws {
        try database.read { db in
            let sql = """
            INSERT INTO mate_daily_status (user_id, date, learned)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id, date) DO UPDATE SET learned = excluded.learned;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(userId, to: 1, in: statement)
            try db.bind(date, to: 2, in: statement)
            try db.bind(learned ? 1 : 0, to: 3, in: statement)
            _ = try db.step(statement)
        }
    }

    func canPoke(senderId: String, receiverId: String, date: String) throws -> Bool {
        try database.read { db in
            let sql = """
            SELECT 1
            FROM mate_poke
            WHERE sender_id = ? AND receiver_id = ? AND date = ?
            LIMIT 1;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(senderId, to: 1, in: statement)
            try db.bind(receiverId, to: 2, in: statement)
            try db.bind(date, to: 3, in: statement)
            return (try db.step(statement)) == false
        }
    }

    func createPoke(senderId: String, receiverId: String, date: String, wordId: Int?) throws -> MatePoke {
        let id = UUID().uuidString
        let createdAt = DateKey.isoString()

        try database.read { db in
            let sql = """
            INSERT INTO mate_poke (id, sender_id, receiver_id, date, word_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(id, to: 1, in: statement)
            try db.bind(senderId, to: 2, in: statement)
            try db.bind(receiverId, to: 3, in: statement)
            try db.bind(date, to: 4, in: statement)
            if let wordId {
                try db.bind(wordId, to: 5, in: statement)
            } else {
                try db.bind(nil as String?, to: 5, in: statement)
            }
            try db.bind(createdAt, to: 6, in: statement)
            _ = try db.step(statement)
        }

        return MatePoke(
            id: id,
            senderId: senderId,
            receiverId: receiverId,
            date: date,
            wordId: wordId,
            createdAt: createdAt
        )
    }

    func latestLearnedDate(userId: String) throws -> String? {
        try database.read { db in
            let sql = """
            SELECT date
            FROM mate_daily_status
            WHERE user_id = ? AND learned = 1
            ORDER BY date DESC
            LIMIT 1;
            """
            let statement = try db.prepare(sql)
            defer { db.finalize(statement) }
            try db.bind(userId, to: 1, in: statement)
            guard try db.step(statement) else { return nil }
            return SQLiteDB.columnText(statement, 0)
        }
    }

    private func mapRoom(statement: OpaquePointer) -> MateRoom {
        let id = SQLiteDB.columnText(statement, 0) ?? ""
        let userId = SQLiteDB.columnText(statement, 1) ?? ""
        let mateUserId = SQLiteDB.columnText(statement, 2) ?? ""
        let mateNickname = SQLiteDB.columnText(statement, 3) ?? ""
        let startDate = SQLiteDB.columnText(statement, 4) ?? ""
        let endDate = SQLiteDB.columnText(statement, 5) ?? ""
        let statusRaw = SQLiteDB.columnText(statement, 6) ?? MateRoom.Status.active.rawValue
        let status = MateRoom.Status(rawValue: statusRaw) ?? .active
        return MateRoom(
            id: id,
            userId: userId,
            mateUserId: mateUserId,
            mateNickname: mateNickname,
            startDate: startDate,
            endDate: endDate,
            status: status
        )
    }
}
