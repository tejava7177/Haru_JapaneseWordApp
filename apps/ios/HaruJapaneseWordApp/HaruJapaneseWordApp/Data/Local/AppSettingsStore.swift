import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let userDefaults: UserDefaults

    private let homeDeckLevelKey = "settings_home_deck_level"
    private let excludeDaysKey = "settings_exclude_days"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        settings = AppSettings(homeDeckLevel: level, excludeDays: settings.excludeDays)
        save(settings: settings)
    }

    func updateExcludeDays(_ days: Int) {
        settings = AppSettings(homeDeckLevel: settings.homeDeckLevel, excludeDays: days)
        save(settings: settings)
    }

    func save(settings: AppSettings) {
        userDefaults.set(settings.homeDeckLevel.rawValue, forKey: homeDeckLevelKey)
        userDefaults.set(settings.excludeDays, forKey: excludeDaysKey)
    }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let days = userDefaults.integer(forKey: "settings_exclude_days")
        let excludeDays = [7, 14, 30].contains(days) ? days : 7
        return AppSettings(homeDeckLevel: level, excludeDays: excludeDays)
    }
}
