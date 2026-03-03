import Foundation

enum MatePokeError: Error, Equatable {
    case alreadyPokedToday
    case senderNotInRoom
    case noActiveRoom
}

protocol MateRepositoryProtocol {
    func cleanupExpiredRooms(now: Date)
    func fetchActiveRoom(for userId: String) -> MateRoom?
    func fetchActiveRooms(for userId: String) -> [MateRoom]
    func createInviteCode(for userId: String, now: Date) -> String
    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date) throws -> MateRoom
    func endRoom(roomId: Int, reason: String)

    func fetchRoomForUser(userId: String) throws -> MateRoom?
    func hasSentPokeToday(roomId: Int, fromUserId: String, now: Date) throws -> Bool
    func sendPoke(roomId: Int, fromUserId: String, now: Date) throws -> MatePoke
    func fetchLatestPoke(roomId: Int) throws -> MatePoke?
    func touchInteraction(roomId: Int, at: Date) throws
}

final class StubMateRepository: MateRepositoryProtocol {
    func cleanupExpiredRooms(now: Date) { }
    func fetchActiveRoom(for userId: String) -> MateRoom? { nil }
    func fetchActiveRooms(for userId: String) -> [MateRoom] { [] }
    func createInviteCode(for userId: String, now: Date) -> String { "" }
    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date) throws -> MateRoom { throw MatePokeError.noActiveRoom }
    func endRoom(roomId: Int, reason: String) { }
    func fetchRoomForUser(userId: String) throws -> MateRoom? { nil }
    func hasSentPokeToday(roomId: Int, fromUserId: String, now: Date) throws -> Bool { false }
    func sendPoke(roomId: Int, fromUserId: String, now: Date) throws -> MatePoke { throw MatePokeError.noActiveRoom }
    func fetchLatestPoke(roomId: Int) throws -> MatePoke? { nil }
    func touchInteraction(roomId: Int, at: Date) throws { }
}
