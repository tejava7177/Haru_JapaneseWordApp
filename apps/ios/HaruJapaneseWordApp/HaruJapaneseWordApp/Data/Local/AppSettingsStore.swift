import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var hasSeenOnboarding: Bool

    private let userDefaults: UserDefaults
    private let profileStore: UserProfileStore

    private static let homeDeckLevelKey = "settings_home_deck_level"
    private static let mateEnabledKey = "settings_mate_enabled"
    private static let onboardingKey = "has_seen_onboarding"
    private static let isSignedInKey = "auth_is_signed_in"
    private static let appleUserIdKey = "auth_apple_user_id"
    private static let appUserIdKey = "auth_app_user_id"
    private static let nicknameKey = "auth_nickname"
    private static let jlptLevelKey = "auth_jlpt_level"

    init(userDefaults: UserDefaults = .standard, profileStore: UserProfileStore = UserProfileStore()) {
        self.userDefaults = userDefaults
        self.profileStore = profileStore
        self.settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
        self.hasSeenOnboarding = userDefaults.bool(forKey: Self.onboardingKey)
        ensureAppUserIdExists()
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        var updated = settings
        updated.homeDeckLevel = level
        settings = updated
        save(settings: updated)
    }

    func updateMateEnabled(_ enabled: Bool) {
        var updated = settings
        updated.isMateEnabled = enabled
        settings = updated
        save(settings: updated)
    }

    func signIn(appleUserId: String) {
        _ = KeychainStore.saveString(key: Self.appleUserIdKey, value: appleUserId)
        var updated = settings
        updated.appleUserId = appleUserId
        updated.isSignedIn = true
        userDefaults.set(true, forKey: Self.isSignedInKey)
        userDefaults.set(appleUserId, forKey: Self.appleUserIdKey)
        if updated.appUserId.isEmpty {
            updated.appUserId = UUID().uuidString
        }
        settings = updated
        userDefaults.set(updated.appUserId, forKey: Self.appUserIdKey)
        save(settings: updated)
    }

    func completeProfile(nickname: String, jlptLevel: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = settings
        updated.nickname = trimmed
        updated.jlptLevel = jlptLevel
        settings = updated
        profileStore.updateNickname(trimmed)
        save(settings: updated)
    }

    func updateNickname(_ nickname: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = settings
        updated.nickname = trimmed
        settings = updated
        profileStore.updateNickname(trimmed)
        save(settings: updated)
    }

    func updateJLPTLevel(_ level: String) {
        var updated = settings
        updated.jlptLevel = level
        settings = updated
        save(settings: updated)
    }

    func signOut() {
        _ = KeychainStore.delete(key: Self.appleUserIdKey)
        var updated = settings
        updated.isSignedIn = false
        updated.appleUserId = nil
        userDefaults.set(false, forKey: Self.isSignedInKey)
        userDefaults.removeObject(forKey: Self.appleUserIdKey)
        settings = updated
        save(settings: updated)
    }

    func save(settings: AppSettings) {
        userDefaults.set(settings.homeDeckLevel.rawValue, forKey: Self.homeDeckLevelKey)
        userDefaults.set(settings.isMateEnabled, forKey: Self.mateEnabledKey)
        userDefaults.set(settings.isSignedIn, forKey: Self.isSignedInKey)
        userDefaults.set(settings.appleUserId, forKey: Self.appleUserIdKey)
        userDefaults.set(settings.appUserId, forKey: Self.appUserIdKey)
        userDefaults.set(settings.nickname, forKey: Self.nicknameKey)
        userDefaults.set(settings.jlptLevel, forKey: Self.jlptLevelKey)
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: Self.onboardingKey)
    }

    func ensureAppUserIdExists() -> String {
        if settings.appUserId.isEmpty == false {
            return settings.appUserId
        }
        let id = UUID().uuidString
        var updated = settings
        updated.appUserId = id
        settings = updated
        userDefaults.set(id, forKey: Self.appUserIdKey)
        return id
    }

    var isSignedIn: Bool { settings.isSignedIn }
    var appleUserId: String? { settings.appleUserId }
    var appUserId: String { settings.appUserId }
    var nickname: String { settings.nickname }
    var jlptLevel: String { settings.jlptLevel }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: Self.homeDeckLevelKey) ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateEnabled = userDefaults.bool(forKey: Self.mateEnabledKey)

        let cachedAppleUserId = userDefaults.string(forKey: Self.appleUserIdKey)
        let keychainAppleUserId = KeychainStore.loadString(key: Self.appleUserIdKey)
        let appleUserId = keychainAppleUserId ?? cachedAppleUserId
        let isSignedIn = keychainAppleUserId != nil

        let storedAppUserId = userDefaults.string(forKey: Self.appUserIdKey) ?? ""
        if storedAppUserId.isEmpty {
            let newId = UUID().uuidString
            userDefaults.set(newId, forKey: Self.appUserIdKey)
            return AppSettings(
                homeDeckLevel: level,
                isMateEnabled: mateEnabled,
                isSignedIn: isSignedIn,
                appleUserId: appleUserId,
                appUserId: newId,
                nickname: userDefaults.string(forKey: Self.nicknameKey) ?? "",
                jlptLevel: userDefaults.string(forKey: Self.jlptLevelKey) ?? JLPTLevel.n5.rawValue
            )
        }

        return AppSettings(
            homeDeckLevel: level,
            isMateEnabled: mateEnabled,
            isSignedIn: isSignedIn,
            appleUserId: appleUserId,
            appUserId: storedAppUserId,
            nickname: userDefaults.string(forKey: Self.nicknameKey) ?? "",
            jlptLevel: userDefaults.string(forKey: Self.jlptLevelKey) ?? JLPTLevel.n5.rawValue
        )
    }
}
