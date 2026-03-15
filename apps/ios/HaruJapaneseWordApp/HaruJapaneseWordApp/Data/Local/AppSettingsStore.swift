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
    private let randomMatchingEnabledField = "random_matching_enabled"
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.github.simjuheun.HaruJapaneseWordApp"

    enum MateDevSlot: String {
        case A
        case B
        case C
        case D

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
        guard settings.homeDeckLevel != level else { return }
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
        let resolvedLevel = profileLevel(for: userId)
        let updated = AppSettings(homeDeckLevel: resolvedLevel, mateUserId: userId)
        guard updated != settings else { return }
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
        guard updated != settings else { return }
        settings = updated
        save(settings: updated)
    }

    var isMateLoggedIn: Bool { settings.isMateLoggedIn }
    var mateUserId: String { settings.mateUserId }
    var currentBackendUserId: String? {
        BackendUserIDMapper.backendUserId(for: settings.mateUserId, displayName: currentMateProfile()?.displayName)
    }

    func profileLevel(for userId: String) -> JLPTLevel {
        profile(for: userId).jlptLevel
    }

    func updateProfileLevel(_ level: JLPTLevel, for userId: String) {
        updateProfileJLPTLevel(level, for: userId)
    }

    func profile(for userId: String) -> MateUserProfile {
        guard userId.isEmpty == false else {
            return MateUserProfile(userId: "", displayName: "", bio: "", instagramId: "", jlptLevel: .n5, avatarData: nil)
        }

        let candidateUserIds = candidateProfileUserIds(for: userId)
        let displayName = firstStoredString(for: candidateUserIds, field: "display_name") ?? defaultDisplayName(for: userId)
        let bio = firstStoredString(for: candidateUserIds, field: "bio") ?? ""
        let instagramId = firstStoredString(for: candidateUserIds, field: "instagram_id") ?? ""
        let avatarData = firstStoredData(for: candidateUserIds, field: "avatar_data")
        let levelRaw = firstStoredString(for: candidateUserIds, field: "jlpt_level")
            ?? candidateUserIds.lazy.compactMap(loadLegacyProfileLevelRaw(for:)).first
            ?? JLPTLevel.n5.rawValue
        let jlptLevel = JLPTLevel(rawValue: levelRaw) ?? .n5

        return MateUserProfile(
            userId: userId,
            displayName: displayName,
            bio: bio,
            instagramId: instagramId,
            jlptLevel: jlptLevel,
            avatarData: avatarData
        )
    }

    func currentMateProfile() -> MateUserProfile? {
        guard settings.mateUserId.isEmpty == false else { return nil }
        return profile(for: settings.mateUserId)
    }

    func preferredDisplayName(forBackendUserId backendUserId: Int?) -> String? {
        guard let backendUserId else { return nil }

        let candidateUserIds = Array(
            Set([String(backendUserId)] + BackendUserIDMapper.candidateRawUserIds(forBackendUserId: backendUserId))
        )

        for userId in candidateUserIds {
            let profile = profile(for: userId)
            let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard displayName.isEmpty == false else { continue }
            return displayName
        }

        return nil
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

    func updateCurrentMateAvatarData(_ avatarData: Data?) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(avatarData, forKey: mateProfileKey(userId: current.userId, field: "avatar_data"))
    }

    func isRandomMatchingEnabled(for userId: String) -> Bool {
        guard userId.isEmpty == false else { return false }
        return userDefaults.bool(forKey: mateProfileKey(userId: userId, field: randomMatchingEnabledField))
    }

    func currentMateRandomMatchingEnabled() -> Bool {
        guard let current = currentMateProfile() else { return false }
        return isRandomMatchingEnabled(for: current.userId)
    }

    func updateCurrentMateRandomMatchingEnabled(_ enabled: Bool) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(enabled, forKey: mateProfileKey(userId: current.userId, field: randomMatchingEnabledField))
    }

    func applyServerProfile(
        userId: String,
        nickname: String?,
        bio: String?,
        instagramId: String?,
        jlptLevel: JLPTLevel?,
        avatarData: Data?,
        randomMatchingEnabled: Bool?
    ) -> Bool {
        guard userId.isEmpty == false else { return false }

        var didChange = false

        if let nickname {
            didChange = setStringIfNeeded(nickname, forKey: mateProfileKey(userId: userId, field: "display_name")) || didChange
        }
        if let bio {
            didChange = setStringIfNeeded(bio, forKey: mateProfileKey(userId: userId, field: "bio")) || didChange
        }
        if let instagramId {
            didChange = setStringIfNeeded(instagramId, forKey: mateProfileKey(userId: userId, field: "instagram_id")) || didChange
        }
        if let jlptLevel {
            didChange = setStringIfNeeded(jlptLevel.rawValue, forKey: mateProfileKey(userId: userId, field: "jlpt_level")) || didChange
        }
        if let avatarData {
            didChange = setDataIfNeeded(avatarData, forKey: mateProfileKey(userId: userId, field: "avatar_data")) || didChange
        }
        if let randomMatchingEnabled {
            didChange = setBoolIfNeeded(randomMatchingEnabled, forKey: mateProfileKey(userId: userId, field: randomMatchingEnabledField)) || didChange
        }

        if settings.mateUserId == userId, let jlptLevel {
            let updated = AppSettings(homeDeckLevel: jlptLevel, mateUserId: settings.mateUserId)
            if updated != settings {
                settings = updated
                save(settings: updated)
                didChange = true
            }
        }

        return didChange
    }

    func clearLocalStateForDevelopment() {
        let preservedBaseURL = userDefaults.string(forKey: "haru_api_base_url")
        userDefaults.removePersistentDomain(forName: bundleIdentifier)
        if let preservedBaseURL {
            userDefaults.set(preservedBaseURL, forKey: "haru_api_base_url")
        }
        Self.deleteWritableSQLiteIfNeeded()

        settings = AppSettingsStore.loadSettings(userDefaults: userDefaults)
        hasSeenOnboarding = userDefaults.bool(forKey: onboardingKey)
        isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        appleUserId = userDefaults.string(forKey: appleUserIdKey)
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
        userDefaults.removeObject(forKey: mateProfileKey(userId: userId, field: "avatar_data"))
        userDefaults.set(false, forKey: mateProfileKey(userId: userId, field: randomMatchingEnabledField))
        let levelRaw = loadLegacyProfileLevelRaw(for: userId) ?? JLPTLevel.n5.rawValue
        userDefaults.set(levelRaw, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))
    }

    private func updateProfileJLPTLevel(_ level: JLPTLevel, for userId: String) {
        guard userId.isEmpty == false else { return }
        let didChange = setStringIfNeeded(level.rawValue, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))

        if settings.mateUserId == userId {
            let updated = AppSettings(homeDeckLevel: level, mateUserId: settings.mateUserId)
            if updated != settings {
                settings = updated
                save(settings: updated)
            } else if didChange == false {
                return
            }
        }
    }

    private func setStringIfNeeded(_ value: String, forKey key: String) -> Bool {
        guard userDefaults.string(forKey: key) != value else { return false }
        userDefaults.set(value, forKey: key)
        return true
    }

    private func setDataIfNeeded(_ value: Data, forKey key: String) -> Bool {
        guard userDefaults.data(forKey: key) != value else { return false }
        userDefaults.set(value, forKey: key)
        return true
    }

    private func setBoolIfNeeded(_ value: Bool, forKey key: String) -> Bool {
        let object = userDefaults.object(forKey: key) as? Bool
        guard object != value else { return false }
        userDefaults.set(value, forKey: key)
        return true
    }

    private func defaultDisplayName(for userId: String) -> String {
        if userId.hasPrefix("DEV-"), let suffix = userId.split(separator: "-").last, suffix.isEmpty == false {
            return String(suffix)
        }
        return userId
    }

    private func candidateProfileUserIds(for userId: String) -> [String] {
        let normalized = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return [] }

        if let backendUserId = BackendUserIDMapper.backendUserId(for: normalized).flatMap(Int.init) {
            return Array(Set([normalized] + BackendUserIDMapper.candidateRawUserIds(forBackendUserId: backendUserId)))
        }

        return [normalized]
    }

    private func firstStoredString(for userIds: [String], field: String) -> String? {
        for userId in userIds {
            if let value = userDefaults.string(forKey: mateProfileKey(userId: userId, field: field)) {
                return value
            }
        }
        return nil
    }

    private func firstStoredData(for userIds: [String], field: String) -> Data? {
        for userId in userIds {
            if let value = userDefaults.data(forKey: mateProfileKey(userId: userId, field: field)) {
                return value
            }
        }
        return nil
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

    private static func deleteWritableSQLiteIfNeeded() {
        let fileManager = FileManager.default
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        guard let dirURL = baseURL?.appendingPathComponent("DictionaryDB", isDirectory: true) else { return }

        let databaseURL = dirURL.appendingPathComponent("jlpt_starter.sqlite", isDirectory: false)
        let sidecarURLs = [
            databaseURL,
            databaseURL.appendingPathExtension("shm"),
            databaseURL.appendingPathExtension("wal")
        ]

        for url in sidecarURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}
