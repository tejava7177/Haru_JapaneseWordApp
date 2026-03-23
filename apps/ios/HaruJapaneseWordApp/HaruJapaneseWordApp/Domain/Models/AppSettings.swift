import Foundation

struct AppSettings: Hashable {
    var homeDeckLevel: JLPTLevel
    var mateUserId: String = ""
    var isLearningNotificationEnabled: Bool = false

    var isMateLoggedIn: Bool {
        mateUserId.isEmpty == false
    }
}
