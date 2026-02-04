import Foundation

struct UserProfile: Hashable {
    var nickname: String
    var bio: String
    var instagramId: String
    var avatarData: Data?
}
