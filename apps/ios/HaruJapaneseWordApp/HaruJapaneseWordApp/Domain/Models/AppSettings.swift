import Foundation

struct PetalNotificationSettings: Hashable {
    var isEnabled: Bool = false
}

struct AppSettings: Hashable {
    var homeDeckLevel: JLPTLevel
    var mateUserId: String = ""
    var learningNotificationSettings: LearningNotificationSettings = LearningNotificationSettings()
    var petalNotificationSettings: PetalNotificationSettings = PetalNotificationSettings()

    init(
        homeDeckLevel: JLPTLevel,
        mateUserId: String = "",
        isLearningNotificationEnabled: Bool = false,
        learningNotificationSettings: LearningNotificationSettings? = nil,
        isPetalNotificationEnabled: Bool = false,
        petalNotificationSettings: PetalNotificationSettings? = nil
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

        if var petalNotificationSettings {
            petalNotificationSettings.isEnabled = isPetalNotificationEnabled || petalNotificationSettings.isEnabled
            self.petalNotificationSettings = petalNotificationSettings
        } else {
            var defaultSettings = PetalNotificationSettings()
            defaultSettings.isEnabled = isPetalNotificationEnabled
            self.petalNotificationSettings = defaultSettings
        }
    }

    var isLearningNotificationEnabled: Bool {
        get { learningNotificationSettings.isEnabled }
        set { learningNotificationSettings.isEnabled = newValue }
    }

    var isMateLoggedIn: Bool {
        mateUserId.isEmpty == false
    }

    var isPetalNotificationEnabled: Bool {
        get { petalNotificationSettings.isEnabled }
        set { petalNotificationSettings.isEnabled = newValue }
    }

    var isAnyPushNotificationEnabled: Bool {
        isLearningNotificationEnabled || isPetalNotificationEnabled
    }
}
