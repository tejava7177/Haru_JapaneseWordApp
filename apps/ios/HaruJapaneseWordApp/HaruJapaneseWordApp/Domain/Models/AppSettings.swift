import Foundation

struct AppSettings: Hashable {
    var homeDeckLevel: JLPTLevel
    var mateUserId: String = ""
    var learningNotificationSettings: LearningNotificationSettings = LearningNotificationSettings()

    init(
        homeDeckLevel: JLPTLevel,
        mateUserId: String = "",
        isLearningNotificationEnabled: Bool = false,
        learningNotificationSettings: LearningNotificationSettings? = nil
    ) {
        self.homeDeckLevel = homeDeckLevel
        self.mateUserId = mateUserId

        if var learningNotificationSettings {
            learningNotificationSettings.isEnabled = isLearningNotificationEnabled || learningNotificationSettings.isEnabled
            self.learningNotificationSettings = learningNotificationSettings
        } else {
            var defaultSettings = LearningNotificationSettings()
            defaultSettings.isEnabled = isLearningNotificationEnabled
            self.learningNotificationSettings = defaultSettings
        }
    }

    var isLearningNotificationEnabled: Bool {
        get { learningNotificationSettings.isEnabled }
        set { learningNotificationSettings.isEnabled = newValue }
    }

    var isMateLoggedIn: Bool {
        mateUserId.isEmpty == false
    }
}
