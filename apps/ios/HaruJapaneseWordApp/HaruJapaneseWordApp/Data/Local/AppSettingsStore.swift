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

    private let legacyProfileLevelsByUserIdKey = "settings_profile_levels_by_user_id"
    private let mateProfilePrefix = "mate_profile"

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

        if settings.mateUserId.isEmpty == false {
            ensureProfileExists(for: settings.mateUserId)
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
            updateCurrentMateJLPTLevel(level)
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
        ensureProfileExists(for: userId)
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
        profile(for: userId).jlptLevel
    }

    func updateProfileLevel(_ level: JLPTLevel, for userId: String) {
        updateProfileJLPTLevel(level, for: userId)
    }

    func profile(for userId: String) -> MateUserProfile {
        guard userId.isEmpty == false else {
            return MateUserProfile(userId: "", displayName: "", bio: "", instagramId: "", jlptLevel: .n5)
        }

        let displayName = userDefaults.string(forKey: mateProfileKey(userId: userId, field: "display_name"))
            ?? defaultDisplayName(for: userId)
        let bio = userDefaults.string(forKey: mateProfileKey(userId: userId, field: "bio")) ?? ""
        let instagramId = userDefaults.string(forKey: mateProfileKey(userId: userId, field: "instagram_id")) ?? ""
        let levelRaw = userDefaults.string(forKey: mateProfileKey(userId: userId, field: "jlpt_level"))
            ?? loadLegacyProfileLevelRaw(for: userId)
            ?? JLPTLevel.n5.rawValue
        let jlptLevel = JLPTLevel(rawValue: levelRaw) ?? .n5

        return MateUserProfile(
            userId: userId,
            displayName: displayName,
            bio: bio,
            instagramId: instagramId,
            jlptLevel: jlptLevel
        )
    }

    func currentMateProfile() -> MateUserProfile? {
        guard settings.mateUserId.isEmpty == false else { return nil }
        return profile(for: settings.mateUserId)
    }

    func updateCurrentMateDisplayName(_ name: String) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(name, forKey: mateProfileKey(userId: current.userId, field: "display_name"))
    }

    func updateCurrentMateBio(_ bio: String) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(bio, forKey: mateProfileKey(userId: current.userId, field: "bio"))
    }

    func updateCurrentMateInstagramId(_ instagramId: String) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(instagramId, forKey: mateProfileKey(userId: current.userId, field: "instagram_id"))
    }

    func updateCurrentMateJLPTLevel(_ level: JLPTLevel) {
        guard let current = currentMateProfile() else { return }
        updateProfileJLPTLevel(level, for: current.userId)
    }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateUserId = userDefaults.string(forKey: "mate_user_id") ?? ""
        return AppSettings(homeDeckLevel: level, mateUserId: mateUserId)
    }

    private func ensureProfileExists(for userId: String) {
        guard userId.isEmpty == false else { return }
        let displayNameKey = mateProfileKey(userId: userId, field: "display_name")
        guard userDefaults.string(forKey: displayNameKey) == nil else { return }

        userDefaults.set(defaultDisplayName(for: userId), forKey: displayNameKey)
        userDefaults.set("", forKey: mateProfileKey(userId: userId, field: "bio"))
        userDefaults.set("", forKey: mateProfileKey(userId: userId, field: "instagram_id"))
        let levelRaw = loadLegacyProfileLevelRaw(for: userId) ?? JLPTLevel.n5.rawValue
        userDefaults.set(levelRaw, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))
    }

    private func updateProfileJLPTLevel(_ level: JLPTLevel, for userId: String) {
        guard userId.isEmpty == false else { return }
        userDefaults.set(level.rawValue, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))

        if settings.mateUserId == userId {
            var updated = settings
            updated.homeDeckLevel = level
            settings = updated
            save(settings: updated)
        }
    }

    private func defaultDisplayName(for userId: String) -> String {
        if userId.hasPrefix("DEV-"), let suffix = userId.split(separator: "-").last, suffix.isEmpty == false {
            return String(suffix)
        }
        return userId
    }

    private func loadLegacyProfileLevelRaw(for userId: String) -> String? {
        guard let values = userDefaults.dictionary(forKey: legacyProfileLevelsByUserIdKey) as? [String: String] else {
            return nil
        }
        return values[userId]
    }

    private func mateProfileKey(userId: String, field: String) -> String {
        "\(mateProfilePrefix).\(userId).\(field)"
    }
}
