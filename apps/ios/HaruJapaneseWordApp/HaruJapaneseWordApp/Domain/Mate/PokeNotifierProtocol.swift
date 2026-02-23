import Foundation

struct PokeNotificationResult: Hashable {
    let didSchedule: Bool
    let isAuthorized: Bool
}

protocol PokeNotifierProtocol {
    func notifyPoke(receiverId: String, message: String, wordId: Int?) async -> PokeNotificationResult
}
