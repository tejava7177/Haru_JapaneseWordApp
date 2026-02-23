import Foundation

protocol MateRepositoryProtocol {
    func getActiveRoom(userId: String) throws -> MateRoom?
    func getLatestRoom(userId: String) throws -> MateRoom?
    func createRoom(userId: String, mateUserId: String, mateNickname: String, startDate: Date) throws -> MateRoom
    func updateRoomStatus(roomId: String, status: MateRoom.Status) throws
    func getTodayStatus(userId: String, date: String) throws -> Bool
    func setTodayLearned(userId: String, date: String, learned: Bool) throws
    func canPoke(senderId: String, receiverId: String, date: String) throws -> Bool
    func createPoke(senderId: String, receiverId: String, date: String, wordId: Int?) throws -> MatePoke
    func latestLearnedDate(userId: String) throws -> String?
}
