import Foundation

struct MatePoke: Identifiable, Hashable {
    let id: String
    let senderId: String
    let receiverId: String
    let date: String
    let wordId: Int?
    let createdAt: String
}
