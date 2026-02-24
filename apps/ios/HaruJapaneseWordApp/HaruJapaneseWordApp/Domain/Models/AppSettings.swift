import Foundation

struct AppSettings: Hashable {
    var homeDeckLevel: JLPTLevel
    var mateUserId: String = ""

    var isMateLoggedIn: Bool {
        mateUserId.isEmpty == false
    }
}
