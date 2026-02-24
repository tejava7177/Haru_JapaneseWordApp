import Foundation

final class MateService {
    private let repository: SQLiteMateRepository
    private let appUserIdProvider: () -> String
    private static var didCleanup: Bool = false

    init(repository: SQLiteMateRepository, appUserIdProvider: @escaping () -> String) {
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

    func createInviteCode() -> String {
        repository.createInviteCode(for: appUserIdProvider())
    }

    func joinByInviteCode(_ inviteCode: String) throws -> MateRoom {
        try repository.joinByInviteCode(inviteCode: inviteCode, joinerId: appUserIdProvider())
    }

    func endRoom(roomId: Int, reason: String) {
        repository.endRoom(roomId: roomId, reason: reason)
    }

    func daysSinceLastInteraction(room: MateRoom, now: Date = Date()) -> Int {
        DateKey.daysBetweenKST(from: room.lastInteractionAt, to: now)
    }
}
