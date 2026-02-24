import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var hasSeenOnboarding: Bool
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var appleUserId: String?

    private let userDefaults: UserDefaults

    private let homeDeckLevelKey = "settings_home_deck_level"
    private let onboardingKey = "has_seen_onboarding"
    private let isSignedInKey = "auth_is_signed_in"
    private let appleUserIdKey = "auth_apple_user_id"
    private let mateUserIdKey = "mate_user_id"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
        self.hasSeenOnboarding = userDefaults.bool(forKey: onboardingKey)
        self.isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        self.appleUserId = userDefaults.string(forKey: appleUserIdKey)
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        var updated = settings
        updated.homeDeckLevel = level
        settings = updated
        save(settings: updated)
    }

    func save(settings: AppSettings) {
        userDefaults.set(settings.homeDeckLevel.rawValue, forKey: homeDeckLevelKey)
        userDefaults.set(settings.mateUserId, forKey: mateUserIdKey)
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
    }

    func signIn(appleUserId: String) {
        self.appleUserId = appleUserId
        isSignedIn = true
        userDefaults.set(true, forKey: isSignedInKey)
        userDefaults.set(appleUserId, forKey: appleUserIdKey)
        signInForMate(userId: appleUserId)
    }

    func signOut() {
        appleUserId = nil
        isSignedIn = false
        userDefaults.set(false, forKey: isSignedInKey)
        userDefaults.removeObject(forKey: appleUserIdKey)
        signOutForMate()
    }

    func signInForMate(userId: String) {
        var updated = settings
        updated.mateUserId = userId
        settings = updated
        save(settings: updated)
    }

    func signOutForMate() {
        guard settings.mateUserId.isEmpty == false else { return }
        var updated = settings
        updated.mateUserId = ""
        settings = updated
        save(settings: updated)
    }

    var isMateLoggedIn: Bool { settings.isMateLoggedIn }
    var mateUserId: String { settings.mateUserId }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateUserId = userDefaults.string(forKey: "mate_user_id") ?? ""
        return AppSettings(homeDeckLevel: level, mateUserId: mateUserId)
    }
}
