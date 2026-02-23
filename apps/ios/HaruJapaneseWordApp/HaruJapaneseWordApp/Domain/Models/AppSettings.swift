import Foundation

struct AppSettings: Hashable {
    var homeDeckLevel: JLPTLevel
    var isMateEnabled: Bool
    var isSignedIn: Bool
    var appleUserId: String?
    var appUserId: String
    var nickname: String
    var jlptLevel: String
}
