import Foundation

struct MatePoke: Hashable, Identifiable {
    let id: Int?
    let roomId: Int
    let fromUserId: String
    let toUserId: String
    let createdAt: Date
}
