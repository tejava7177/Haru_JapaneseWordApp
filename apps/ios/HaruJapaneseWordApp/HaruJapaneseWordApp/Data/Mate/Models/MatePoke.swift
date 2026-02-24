import Foundation

struct MatePoke: Hashable, Identifiable {
    let id: Int
    let roomId: Int
    let senderId: String
    let receiverId: String
    let wordId: Int
    let createdAt: Date
    let dateKeyKST: String
    let consumedAt: Date?

    var isPending: Bool {
        consumedAt == nil
    }
}
