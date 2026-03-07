import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var hasSeenOnboarding: Bool
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var appleUserId: String?
    @Published private(set) var profileLevelsByUserId: [String: String]

    private let userDefaults: UserDefaults

    private let homeDeckLevelKey = "settings_home_deck_level"
    private let onboardingKey = "has_seen_onboarding"
    private let isSignedInKey = "auth_is_signed_in"
    private let appleUserIdKey = "auth_apple_user_id"
    private let mateUserIdKey = "mate_user_id"
    private let profileLevelsByUserIdKey = "settings_profile_levels_by_user_id"

    enum MateDevSlot: String {
        case A
        case B
        case C

        var userId: String {
            "DEV-\(rawValue)"
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
        self.hasSeenOnboarding = userDefaults.bool(forKey: onboardingKey)
        self.isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        self.appleUserId = userDefaults.string(forKey: appleUserIdKey)
        self.profileLevelsByUserId = AppSettingsStore.loadProfileLevelsByUserId(userDefaults: userDefaults)

        if settings.mateUserId.isEmpty == false {
            var updated = settings
            updated.homeDeckLevel = profileLevel(for: settings.mateUserId)
            settings = updated
            save(settings: updated)
        }
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        var updated = settings
        updated.homeDeckLevel = level
        settings = updated
        save(settings: updated)

        if settings.mateUserId.isEmpty == false {
            saveProfileLevel(level, for: settings.mateUserId)
        }
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
        updated.homeDeckLevel = profileLevel(for: userId)
        settings = updated
        save(settings: updated)
    }

    func signInForMateDevSlot(_ slot: MateDevSlot) {
        signInForMate(userId: slot.userId)
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

    func profileLevel(for userId: String) -> JLPTLevel {
        guard userId.isEmpty == false else { return .n5 }
        let rawValue = profileLevelsByUserId[userId] ?? JLPTLevel.n5.rawValue
        return JLPTLevel(rawValue: rawValue) ?? .n5
    }

    func updateProfileLevel(_ level: JLPTLevel, for userId: String) {
        guard userId.isEmpty == false else { return }
        saveProfileLevel(level, for: userId)

        if settings.mateUserId == userId {
            var updated = settings
            updated.homeDeckLevel = level
            settings = updated
            save(settings: updated)
        }
    }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateUserId = userDefaults.string(forKey: "mate_user_id") ?? ""
        return AppSettings(homeDeckLevel: level, mateUserId: mateUserId)
    }

    private static func loadProfileLevelsByUserId(userDefaults: UserDefaults) -> [String: String] {
        guard let values = userDefaults.dictionary(forKey: "settings_profile_levels_by_user_id") as? [String: String] else {
            return [:]
        }
        return values
    }

    private func saveProfileLevel(_ level: JLPTLevel, for userId: String) {
        var updated = profileLevelsByUserId
        updated[userId] = level.rawValue
        profileLevelsByUserId = updated
        userDefaults.set(updated, forKey: profileLevelsByUserIdKey)
    }
}
