import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var hasSeenOnboarding: Bool

    private let userDefaults: UserDefaults

    private let homeDeckLevelKey = "settings_home_deck_level"
    private let mateEnabledKey = "settings_mate_enabled"
    private let onboardingKey = "has_seen_onboarding"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
        self.hasSeenOnboarding = userDefaults.bool(forKey: onboardingKey)
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        settings = AppSettings(homeDeckLevel: level, isMateEnabled: settings.isMateEnabled)
        save(settings: settings)
    }

    func updateMateEnabled(_ enabled: Bool) {
        settings = AppSettings(homeDeckLevel: settings.homeDeckLevel, isMateEnabled: enabled)
        save(settings: settings)
    }

    func save(settings: AppSettings) {
        userDefaults.set(settings.homeDeckLevel.rawValue, forKey: homeDeckLevelKey)
        userDefaults.set(settings.isMateEnabled, forKey: mateEnabledKey)
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
    }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateEnabled = userDefaults.bool(forKey: "settings_mate_enabled")
        return AppSettings(homeDeckLevel: level, isMateEnabled: mateEnabled)
    }
}
