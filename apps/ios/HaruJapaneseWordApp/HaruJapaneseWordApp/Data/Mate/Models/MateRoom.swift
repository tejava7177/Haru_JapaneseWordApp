import Foundation

struct MateRoom: Identifiable, Hashable {
    enum Status: String {
        case active
        case paused
        case expired
        case ended
    }

    let id: String
    let userId: String
    let mateUserId: String
    let mateNickname: String
    let startDate: String
    let endDate: String
    let status: Status
}
