import Foundation

struct StubMateRepository: MateRepositoryProtocol {
    func getActiveRoom(userId: String) throws -> MateRoom? { nil }
    func getLatestRoom(userId: String) throws -> MateRoom? { nil }
    func createRoom(userId: String, mateUserId: String, mateNickname: String, startDate: Date) throws -> MateRoom {
        MateRoom(
            id: UUID().uuidString,
            userId: userId,
            mateUserId: mateUserId,
            mateNickname: mateNickname,
            startDate: DateKey.isoString(from: startDate),
            endDate: DateKey.isoString(from: DateKey.addingDays(30, to: startDate)),
            status: .active
        )
    }
    func updateRoomStatus(roomId: String, status: MateRoom.Status) throws { }
    func getTodayStatus(userId: String, date: String) throws -> Bool { false }
    func setTodayLearned(userId: String, date: String, learned: Bool) throws { }
    func canPoke(senderId: String, receiverId: String, date: String) throws -> Bool { true }
    func createPoke(senderId: String, receiverId: String, date: String, wordId: Int?) throws -> MatePoke {
        MatePoke(id: UUID().uuidString, senderId: senderId, receiverId: receiverId, date: date, wordId: wordId, createdAt: DateKey.isoString())
    }
    func latestLearnedDate(userId: String) throws -> String? { nil }
}
