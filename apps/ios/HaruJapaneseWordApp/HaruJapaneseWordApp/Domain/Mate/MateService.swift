import Foundation

final class MateService {
    private let repository: MateRepositoryProtocol
    private let appUserIdProvider: () -> String
    private static var didCleanup: Bool = false

    init(repository: MateRepositoryProtocol, appUserIdProvider: @escaping () -> String) {
        self.repository = repository
        self.appUserIdProvider = appUserIdProvider
    }

    func cleanupIfNeeded(now: Date = Date()) {
        if Self.didCleanup { return }
        repository.cleanupExpiredRooms(now: now)
        Self.didCleanup = true
    }

    func loadActiveRoom() -> MateRoom? {
        repository.fetchActiveRoom(for: appUserIdProvider())
    }

    func loadActiveRooms() -> [MateRoom] {
        repository.fetchActiveRooms(for: appUserIdProvider())
    }

    func createInviteCode() -> String {
        repository.createInviteCode(for: appUserIdProvider(), now: Date())
    }

    func joinByInviteCode(_ inviteCode: String) throws -> MateRoom {
        try repository.joinByInviteCode(inviteCode: inviteCode, joinerId: appUserIdProvider(), now: Date())
    }

    func endRoom(roomId: Int, reason: String) {
        repository.endRoom(roomId: roomId, reason: reason)
    }

    func daysSinceLastInteraction(room: MateRoom, now: Date = Date()) -> Int {
        DateKey.daysBetweenKST(from: room.lastInteractionAt, to: now)
    }

    func sendPoke(currentUserId: String) async -> Result<MatePoke, Error> {
        do {
            guard let room = try repository.fetchRoomForUser(userId: currentUserId), room.hasMate else {
                return .failure(MatePokeError.noActiveRoom)
            }
            let poke = try repository.sendPoke(roomId: room.id, fromUserId: currentUserId, now: Date())
            return .success(poke)
        } catch {
            return .failure(error)
        }
    }

    func fetchLatestPoke() async -> MatePoke? {
        do {
            let userId = appUserIdProvider()
            guard let room = try repository.fetchRoomForUser(userId: userId), room.hasMate else {
                return nil
            }
            return try repository.fetchLatestPoke(roomId: room.id)
        } catch {
            return nil
        }
    }

    func canSendPokeToday(currentUserId: String) async -> Bool {
        do {
            guard let room = try repository.fetchRoomForUser(userId: currentUserId), room.hasMate else {
                return false
            }
            return try repository.hasSentPokeToday(roomId: room.id, fromUserId: currentUserId, now: Date()) == false
        } catch {
            return false
        }
    }

    func refreshRoom() async -> MateRoom? {
        do {
            return try repository.fetchRoomForUser(userId: appUserIdProvider())
        } catch {
            return nil
        }
    }
}
