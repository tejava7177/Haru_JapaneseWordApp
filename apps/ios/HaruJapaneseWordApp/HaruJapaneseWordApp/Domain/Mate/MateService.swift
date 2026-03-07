import Foundation

final class MateService {
    private let repository: MateRepositoryProtocol
    private let appUserIdProvider: () -> String
    private static var didCleanup: Bool = false
    static let maxActiveMatesPerUser = 3

    init(repository: MateRepositoryProtocol, appUserIdProvider: @escaping () -> String) {
        self.repository = repository
        self.appUserIdProvider = appUserIdProvider
    }

    func cleanupIfNeeded(now: Date = Date()) {
        if Self.didCleanup { return }
        repository.cleanupExpiredRooms(now: now)
        Self.didCleanup = true
    }

    func getActiveRooms(userId: String? = nil) -> [MateRoom] {
        do {
            return try repository.fetchActiveRooms(for: userId ?? appUserIdProvider())
        } catch {
            return []
        }
    }

    func createInvite(userId: String? = nil) throws -> String {
        let actorId = userId ?? appUserIdProvider()
        return try repository.createInviteCode(for: actorId, now: Date())
    }

    func join(userId: String? = nil, inviteCode: String) throws -> MateRoom {
        let actorId = userId ?? appUserIdProvider()
        return try repository.joinByInviteCode(inviteCode: inviteCode, joinerId: actorId, now: Date())
    }

    func end(roomId: Int, userId: String? = nil) throws {
        let actorId = userId ?? appUserIdProvider()
        try repository.endRoom(roomId: roomId, requestedBy: actorId)
    }

    func daysSinceLastInteraction(room: MateRoom, now: Date = Date()) -> Int {
        DateKey.daysBetweenKST(from: room.lastInteractionAt, to: now)
    }

    func sendPoke(roomId: Int, currentUserId: String) async -> Result<MatePoke, Error> {
        do {
            let poke = try repository.sendPoke(roomId: roomId, fromUserId: currentUserId, now: Date())
            return .success(poke)
        } catch {
            return .failure(error)
        }
    }

    func fetchLatestPoke(roomId: Int) async -> MatePoke? {
        do {
            return try repository.fetchLatestPoke(roomId: roomId)
        } catch {
            return nil
        }
    }

    func canSendPokeToday(roomId: Int, currentUserId: String) async -> Bool {
        do {
            return try repository.hasSentPokeToday(roomId: roomId, fromUserId: currentUserId, now: Date()) == false
        } catch {
            return false
        }
    }

    func refreshRoom(roomId: Int) async -> MateRoom? {
        do {
            let rooms = try repository.fetchActiveRooms(for: appUserIdProvider())
            return rooms.first(where: { $0.id == roomId })
        } catch {
            return nil
        }
    }
}
