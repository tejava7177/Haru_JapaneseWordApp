import Foundation

struct MateRoom: Hashable, Identifiable {
    let id: Int
    let userAId: String
    let userBId: String
    let inviteCode: String
    let createdAt: Date
    let lastInteractionAt: Date
    let isActive: Bool

    var hasMate: Bool {
        userBId.isEmpty == false
    }
}
