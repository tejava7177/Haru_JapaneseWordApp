import Foundation

enum MatePokeError: Error, Equatable {
    case alreadyPokedToday
    case senderNotInRoom
    case noActiveRoom
}

protocol MateRepositoryProtocol {
    func cleanupExpiredRooms(now: Date)
    func fetchActiveRooms(for userId: String) throws -> [MateRoom]
    func countActiveRooms(for userId: String) throws -> Int
    func existsActiveRoom(between user1: String, and user2: String) throws -> Bool
    func createInviteCode(for userId: String, now: Date) throws -> String
    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date) throws -> MateRoom
    func endRoom(roomId: Int, requestedBy userId: String) throws

    func hasSentPokeToday(roomId: Int, fromUserId: String, now: Date) throws -> Bool
    func sendPoke(roomId: Int, fromUserId: String, now: Date) throws -> MatePoke
    func fetchLatestPoke(roomId: Int) throws -> MatePoke?
    func touchInteraction(roomId: Int, at: Date) throws
}

final class StubMateRepository: MateRepositoryProtocol {
    func cleanupExpiredRooms(now: Date) { }
    func fetchActiveRooms(for userId: String) throws -> [MateRoom] { [] }
    func countActiveRooms(for userId: String) throws -> Int { 0 }
    func existsActiveRoom(between user1: String, and user2: String) throws -> Bool { false }
    func createInviteCode(for userId: String, now: Date) throws -> String { "" }
    func joinByInviteCode(inviteCode: String, joinerId: String, now: Date) throws -> MateRoom { throw MatePokeError.noActiveRoom }
    func endRoom(roomId: Int, requestedBy userId: String) throws { }
    func hasSentPokeToday(roomId: Int, fromUserId: String, now: Date) throws -> Bool { false }
    func sendPoke(roomId: Int, fromUserId: String, now: Date) throws -> MatePoke { throw MatePokeError.noActiveRoom }
    func fetchLatestPoke(roomId: Int) throws -> MatePoke? { nil }
    func touchInteraction(roomId: Int, at: Date) throws { }
}
