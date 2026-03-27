import Foundation
import Combine

final class AppSettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var hasSeenOnboarding: Bool
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var isDarkModeEnabled: Bool
    @Published private(set) var appleUserId: String?
    @Published private(set) var appleEmail: String?
    @Published private(set) var appleDisplayName: String?
    @Published private(set) var serverUserId: String?
    @Published private(set) var apnsDeviceToken: String?
    @Published private(set) var profileRefreshTick: Int = 0

    private let userDefaults: UserDefaults

    private let homeDeckLevelKey = "settings_home_deck_level"
    private let onboardingKey = "hasSeenOnboarding"
    private let legacyOnboardingKey = "has_seen_onboarding"
    private let isSignedInKey = "auth_is_signed_in"
    private let darkModeEnabledKey = "appearance_is_dark_mode_enabled"
    private let appleUserIdKey = "auth_apple_user_id"
    private let appleEmailKey = "auth_apple_email"
    private let appleDisplayNameKey = "auth_apple_display_name"
    private let serverUserIdKey = "auth_server_user_id"
    private let apnsDeviceTokenKey = "push_apns_device_token"
    private let registeredAPNSDeviceTokenKey = "push_registered_apns_device_token"
    private let registeredAPNSUserIdKey = "push_registered_apns_user_id"
    private let mateUserIdKey = "mate_user_id"
    private static let learningNotificationEnabledKey = "settings_learning_notification_enabled"
    private static let learningNotificationTimeMinutesKey = "settings_learning_notification_time_minutes"
    private static let learningNotificationRepeatEnabledKey = "settings_learning_notification_repeat_enabled"
    private static let learningNotificationRepeatStartMinutesKey = "settings_learning_notification_repeat_start_minutes"
    private static let learningNotificationRepeatEndMinutesKey = "settings_learning_notification_repeat_end_minutes"
    private static let learningNotificationRepeatIntervalMinutesKey = "settings_learning_notification_repeat_interval_minutes"
    private static let petalNotificationEnabledKey = "settings_petal_notification_enabled"

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
        self.hasSeenOnboarding = userDefaults.object(forKey: onboardingKey) as? Bool
            ?? userDefaults.bool(forKey: legacyOnboardingKey)
        self.isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        self.isDarkModeEnabled = userDefaults.bool(forKey: darkModeEnabledKey)
        self.appleUserId = userDefaults.string(forKey: appleUserIdKey)
        self.appleEmail = userDefaults.string(forKey: appleEmailKey)
        self.appleDisplayName = userDefaults.string(forKey: appleDisplayNameKey)
        self.serverUserId = userDefaults.string(forKey: serverUserIdKey)
        self.apnsDeviceToken = userDefaults.string(forKey: apnsDeviceTokenKey)

        migrateLegacyStoredServerUserIdIfNeeded()

        if let activeServerUserId = serverUserId, activeServerUserId.isEmpty == false {
            ensureProfileExists(for: activeServerUserId)
            var updated = settings
            updated.mateUserId = activeServerUserId
            updated.homeDeckLevel = profileLevel(for: activeServerUserId)
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
        userDefaults.set(settings.isLearningNotificationEnabled, forKey: Self.learningNotificationEnabledKey)
        userDefaults.set(settings.learningNotificationSettings.notificationTimeMinutes, forKey: Self.learningNotificationTimeMinutesKey)
        userDefaults.set(settings.learningNotificationSettings.isRepeating, forKey: Self.learningNotificationRepeatEnabledKey)
        userDefaults.set(settings.learningNotificationSettings.repeatStartMinutes, forKey: Self.learningNotificationRepeatStartMinutesKey)
        userDefaults.set(settings.learningNotificationSettings.repeatEndMinutes, forKey: Self.learningNotificationRepeatEndMinutesKey)
        userDefaults.set(settings.learningNotificationSettings.repeatInterval.rawValue, forKey: Self.learningNotificationRepeatIntervalMinutesKey)
        userDefaults.set(settings.isPetalNotificationEnabled, forKey: Self.petalNotificationEnabledKey)
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
        userDefaults.removeObject(forKey: legacyOnboardingKey)
    }

    func signIn(
        appleUserId: String,
        email: String?,
        displayName: String?,
        serverUserId: String,
        nickname: String?,
        learningLevel: JLPTLevel?
    ) {
        let trimmedServerUserId = serverUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedServerUserId.isEmpty == false else { return }

        self.appleUserId = appleUserId
        self.serverUserId = trimmedServerUserId
        if let email {
            self.appleEmail = email
            userDefaults.set(email, forKey: appleEmailKey)
        }
        if let displayName, displayName.isEmpty == false {
            self.appleDisplayName = displayName
            userDefaults.set(displayName, forKey: appleDisplayNameKey)
        }
        isSignedIn = true
        userDefaults.set(true, forKey: isSignedInKey)
        userDefaults.set(appleUserId, forKey: appleUserIdKey)
        userDefaults.set(trimmedServerUserId, forKey: serverUserIdKey)

        ensureProfileExists(for: trimmedServerUserId)
        if let nickname, nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            userDefaults.set(nickname, forKey: mateProfileKey(userId: trimmedServerUserId, field: "display_name"))
        } else if let displayName, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            userDefaults.set(displayName, forKey: mateProfileKey(userId: trimmedServerUserId, field: "display_name"))
        }
        if let learningLevel {
            userDefaults.set(learningLevel.rawValue, forKey: mateProfileKey(userId: trimmedServerUserId, field: "jlpt_level"))
        }

        let resolvedLevel = learningLevel ?? profileLevel(for: trimmedServerUserId)
        let updated = AppSettings(
            homeDeckLevel: resolvedLevel,
            mateUserId: trimmedServerUserId,
            isLearningNotificationEnabled: settings.isLearningNotificationEnabled,
            learningNotificationSettings: settings.learningNotificationSettings,
            isPetalNotificationEnabled: settings.isPetalNotificationEnabled,
            petalNotificationSettings: settings.petalNotificationSettings
        )
        settings = updated
        save(settings: updated)
        notifyProfileDidChange()
        print("[AppleSignIn] state persisted")
    }

    func signOut() {
        appleUserId = nil
        appleEmail = nil
        appleDisplayName = nil
        serverUserId = nil
        isSignedIn = false
        userDefaults.set(false, forKey: isSignedInKey)
        userDefaults.removeObject(forKey: appleUserIdKey)
        userDefaults.removeObject(forKey: appleEmailKey)
        userDefaults.removeObject(forKey: appleDisplayNameKey)
        userDefaults.removeObject(forKey: serverUserIdKey)
        clearDeviceTokenServerRegistration()
        signOutForMate()
    }

    func signInForMate(userId: String) {
        let resolvedServerUserId = resolvedServerUserId(for: userId) ?? userId
        ensureProfileExists(for: resolvedServerUserId)
        serverUserId = resolvedServerUserId
        userDefaults.set(resolvedServerUserId, forKey: serverUserIdKey)
        let resolvedLevel = profileLevel(for: resolvedServerUserId)
        let updated = AppSettings(
            homeDeckLevel: resolvedLevel,
            mateUserId: resolvedServerUserId,
            isLearningNotificationEnabled: settings.isLearningNotificationEnabled,
            learningNotificationSettings: settings.learningNotificationSettings,
            isPetalNotificationEnabled: settings.isPetalNotificationEnabled,
            petalNotificationSettings: settings.petalNotificationSettings
        )
        guard updated != settings else { return }
        settings = updated
        save(settings: updated)
    }

    func signInForMateDevSlot(_ slot: MateDevSlot) {
        signInForMate(userId: slot.userId)
    }

    func signOutForMate() {
        serverUserId = nil
        userDefaults.removeObject(forKey: serverUserIdKey)
        guard settings.mateUserId.isEmpty == false else { return }
        var updated = settings
        updated.mateUserId = ""
        guard updated != settings else { return }
        settings = updated
        save(settings: updated)
    }

    func setDarkModeEnabled(_ enabled: Bool) {
        guard isDarkModeEnabled != enabled else { return }
        isDarkModeEnabled = enabled
        userDefaults.set(enabled, forKey: darkModeEnabledKey)
    }

    func setLearningNotificationEnabled(_ enabled: Bool) {
        guard settings.isLearningNotificationEnabled != enabled else { return }
        var updated = settings
        updated.isLearningNotificationEnabled = enabled
        settings = updated
        save(settings: updated)
    }

    func updateLearningNotificationSettings(_ learningNotificationSettings: LearningNotificationSettings) {
        guard settings.learningNotificationSettings != learningNotificationSettings else { return }
        var updated = settings
        updated.learningNotificationSettings = learningNotificationSettings
        settings = updated
        save(settings: updated)
    }

    func updatePetalNotificationSettings(_ petalNotificationSettings: PetalNotificationSettings) {
        guard settings.petalNotificationSettings != petalNotificationSettings else { return }
        var updated = settings
        updated.petalNotificationSettings = petalNotificationSettings
        settings = updated
        save(settings: updated)
    }

    func setAPNSDeviceToken(_ token: String?) {
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedToken = trimmedToken?.isEmpty == false ? trimmedToken : nil
        guard apnsDeviceToken != normalizedToken else { return }

        apnsDeviceToken = normalizedToken
        if let normalizedToken {
            userDefaults.set(normalizedToken, forKey: apnsDeviceTokenKey)
        } else {
            userDefaults.removeObject(forKey: apnsDeviceTokenKey)
        }

        if registeredDeviceToken != normalizedToken {
            clearDeviceTokenServerRegistration()
        }
    }

    func markDeviceTokenRegisteredToServer(token: String, userId: String) {
        userDefaults.set(token, forKey: registeredAPNSDeviceTokenKey)
        userDefaults.set(userId, forKey: registeredAPNSUserIdKey)
    }

    func clearDeviceTokenServerRegistration() {
        userDefaults.removeObject(forKey: registeredAPNSDeviceTokenKey)
        userDefaults.removeObject(forKey: registeredAPNSUserIdKey)
    }

    var registeredDeviceToken: String? {
        userDefaults.string(forKey: registeredAPNSDeviceTokenKey)
    }

    var registeredDeviceTokenUserId: String? {
        userDefaults.string(forKey: registeredAPNSUserIdKey)
    }

    func hasRegisteredDeviceTokenToServer(token: String, userId: String) -> Bool {
        registeredDeviceToken == token && registeredDeviceTokenUserId == userId
    }

    var isMateLoggedIn: Bool { serverUserId?.isEmpty == false }
    var hasAuthenticatedSession: Bool { isSignedIn || isMateLoggedIn }
    var hasResolvedServerSession: Bool { serverUserId?.isEmpty == false }
    var mateUserId: String { settings.mateUserId }
    var currentBackendUserId: String? {
        serverUserId
    }

    func profileLevel(for userId: String) -> JLPTLevel {
        profile(for: userId).jlptLevel
    }

    func updateProfileLevel(_ level: JLPTLevel, for userId: String) {
        updateProfileJLPTLevel(level, for: userId)
    }

    func profile(for userId: String) -> MateUserProfile {
        guard userId.isEmpty == false else {
            return MateUserProfile(
                userId: "",
                displayName: "",
                bio: "",
                instagramId: "",
                jlptLevel: .n5,
                profileImageUrl: nil,
                avatarData: nil
            )
        }

        let candidateUserIds = candidateProfileUserIds(for: userId)
        let displayName = firstStoredString(for: candidateUserIds, field: "display_name") ?? defaultDisplayName(for: userId)
        let bio = firstStoredString(for: candidateUserIds, field: "bio") ?? ""
        let instagramId = firstStoredString(for: candidateUserIds, field: "instagram_id") ?? ""
        let profileImageUrl = firstStoredString(for: candidateUserIds, field: "profile_image_url")
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
            profileImageUrl: profileImageUrl,
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
        notifyProfileDidChange()
    }

    func updateCurrentMateBio(_ bio: String) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(bio, forKey: mateProfileKey(userId: current.userId, field: "bio"))
        notifyProfileDidChange()
    }

    func updateCurrentMateInstagramId(_ instagramId: String) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(instagramId, forKey: mateProfileKey(userId: current.userId, field: "instagram_id"))
        notifyProfileDidChange()
    }

    func updateCurrentMateJLPTLevel(_ level: JLPTLevel) {
        guard let current = currentMateProfile() else { return }
        updateProfileJLPTLevel(level, for: current.userId)
        notifyProfileDidChange()
    }

    func updateCurrentMateProfileImageUrl(_ profileImageUrl: String?) {
        guard let current = currentMateProfile() else { return }
        _ = setOptionalStringIfNeeded(profileImageUrl, forKey: mateProfileKey(userId: current.userId, field: "profile_image_url"))
        notifyProfileDidChange()
    }

    func updateCurrentMateAvatarData(_ avatarData: Data?) {
        guard let current = currentMateProfile() else { return }
        userDefaults.set(avatarData, forKey: mateProfileKey(userId: current.userId, field: "avatar_data"))
        notifyProfileDidChange()
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
        profileImageUrl: String?,
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
        didChange = setOptionalStringIfNeeded(
            profileImageUrl,
            forKey: mateProfileKey(userId: userId, field: "profile_image_url")
        ) || didChange
        if let avatarData {
            didChange = setDataIfNeeded(avatarData, forKey: mateProfileKey(userId: userId, field: "avatar_data")) || didChange
        }
        if let randomMatchingEnabled {
            didChange = setBoolIfNeeded(randomMatchingEnabled, forKey: mateProfileKey(userId: userId, field: randomMatchingEnabledField)) || didChange
        }

        if settings.mateUserId == userId, let jlptLevel {
            let updated = AppSettings(
                homeDeckLevel: jlptLevel,
                mateUserId: settings.mateUserId,
                isLearningNotificationEnabled: settings.isLearningNotificationEnabled,
                learningNotificationSettings: settings.learningNotificationSettings,
                isPetalNotificationEnabled: settings.isPetalNotificationEnabled,
                petalNotificationSettings: settings.petalNotificationSettings
            )
            if updated != settings {
                settings = updated
                save(settings: updated)
                didChange = true
            }
        }

        if didChange {
            notifyProfileDidChange()
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
        hasSeenOnboarding = userDefaults.object(forKey: onboardingKey) as? Bool
            ?? userDefaults.bool(forKey: legacyOnboardingKey)
        isSignedIn = userDefaults.bool(forKey: isSignedInKey)
        isDarkModeEnabled = userDefaults.bool(forKey: darkModeEnabledKey)
        appleUserId = userDefaults.string(forKey: appleUserIdKey)
        appleEmail = userDefaults.string(forKey: appleEmailKey)
        appleDisplayName = userDefaults.string(forKey: appleDisplayNameKey)
        serverUserId = userDefaults.string(forKey: serverUserIdKey)
        apnsDeviceToken = userDefaults.string(forKey: apnsDeviceTokenKey)
    }

    private static func loadSettings(userDefaults: UserDefaults) -> AppSettings {
        let levelRaw = userDefaults.string(forKey: "settings_home_deck_level") ?? JLPTLevel.n5.rawValue
        let level = JLPTLevel(rawValue: levelRaw) ?? .n5
        let mateUserId = userDefaults.string(forKey: "mate_user_id") ?? ""
        let isLearningNotificationEnabled = userDefaults.bool(forKey: Self.learningNotificationEnabledKey)
        let notificationTimeMinutes = userDefaults.object(forKey: Self.learningNotificationTimeMinutesKey) as? Int
            ?? (20 * 60)
        let isRepeating = userDefaults.bool(forKey: Self.learningNotificationRepeatEnabledKey)
        let repeatStartMinutes = userDefaults.object(forKey: Self.learningNotificationRepeatStartMinutesKey) as? Int
            ?? (9 * 60)
        let repeatEndMinutes = userDefaults.object(forKey: Self.learningNotificationRepeatEndMinutesKey) as? Int
            ?? (21 * 60)
        let repeatIntervalMinutes = userDefaults.object(forKey: Self.learningNotificationRepeatIntervalMinutesKey) as? Int
            ?? LearningNotificationSettings.RepeatInterval.oneHour.rawValue
        let repeatInterval = LearningNotificationSettings.RepeatInterval(rawValue: repeatIntervalMinutes) ?? .oneHour
        let isPetalNotificationEnabled = userDefaults.bool(forKey: Self.petalNotificationEnabledKey)
        let learningNotificationSettings = LearningNotificationSettings(
            isEnabled: isLearningNotificationEnabled,
            notificationTimeMinutes: notificationTimeMinutes,
            isRepeating: isRepeating,
            repeatStartMinutes: repeatStartMinutes,
            repeatEndMinutes: repeatEndMinutes,
            repeatInterval: repeatInterval
        )
        return AppSettings(
            homeDeckLevel: level,
            mateUserId: mateUserId,
            learningNotificationSettings: learningNotificationSettings,
            petalNotificationSettings: PetalNotificationSettings(isEnabled: isPetalNotificationEnabled)
        )
    }

    private func ensureProfileExists(for userId: String) {
        guard userId.isEmpty == false else { return }
        let displayNameKey = mateProfileKey(userId: userId, field: "display_name")
        guard userDefaults.string(forKey: displayNameKey) == nil else { return }

        userDefaults.set(defaultDisplayName(for: userId), forKey: displayNameKey)
        userDefaults.set("", forKey: mateProfileKey(userId: userId, field: "bio"))
        userDefaults.set("", forKey: mateProfileKey(userId: userId, field: "instagram_id"))
        userDefaults.removeObject(forKey: mateProfileKey(userId: userId, field: "profile_image_url"))
        userDefaults.removeObject(forKey: mateProfileKey(userId: userId, field: "avatar_data"))
        userDefaults.set(false, forKey: mateProfileKey(userId: userId, field: randomMatchingEnabledField))
        let levelRaw = loadLegacyProfileLevelRaw(for: userId) ?? JLPTLevel.n5.rawValue
        userDefaults.set(levelRaw, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))
    }

    private func updateProfileJLPTLevel(_ level: JLPTLevel, for userId: String) {
        guard userId.isEmpty == false else { return }
        let didChange = setStringIfNeeded(level.rawValue, forKey: mateProfileKey(userId: userId, field: "jlpt_level"))

        if settings.mateUserId == userId {
            let updated = AppSettings(
                homeDeckLevel: level,
                mateUserId: settings.mateUserId,
                isLearningNotificationEnabled: settings.isLearningNotificationEnabled,
                learningNotificationSettings: settings.learningNotificationSettings,
                isPetalNotificationEnabled: settings.isPetalNotificationEnabled,
                petalNotificationSettings: settings.petalNotificationSettings
            )
            if updated != settings {
                settings = updated
                save(settings: updated)
            } else if didChange == false {
                return
            }
        }
    }

    private func notifyProfileDidChange() {
        profileRefreshTick &+= 1
    }

    private func setStringIfNeeded(_ value: String, forKey key: String) -> Bool {
        guard userDefaults.string(forKey: key) != value else { return false }
        userDefaults.set(value, forKey: key)
        return true
    }

    private func setOptionalStringIfNeeded(_ value: String?, forKey key: String) -> Bool {
        let currentValue = userDefaults.string(forKey: key)
        if currentValue == value {
            return false
        }
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
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

        if normalized.allSatisfy(\.isNumber) {
            return Array(Set([normalized] + BackendUserIDMapper.candidateRawUserIds(forBackendUserId: Int(normalized) ?? -1)))
        }

        if let backendUserId = BackendUserIDMapper.backendUserId(for: normalized).flatMap(Int.init) {
            return Array(Set([normalized] + BackendUserIDMapper.candidateRawUserIds(forBackendUserId: backendUserId)))
        }

        return [normalized]
    }

    private func migrateLegacyStoredServerUserIdIfNeeded() {
        if let storedServerUserId = serverUserId?.trimmingCharacters(in: .whitespacesAndNewlines),
           storedServerUserId.isEmpty == false {
            if settings.mateUserId != storedServerUserId {
                var updated = settings
                updated.mateUserId = storedServerUserId
                settings = updated
            }
            return
        }

        let legacyUserId = settings.mateUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard legacyUserId.isEmpty == false, legacyUserId.allSatisfy(\.isNumber) else { return }

        serverUserId = legacyUserId
        userDefaults.set(legacyUserId, forKey: serverUserIdKey)

        var updated = settings
        updated.mateUserId = legacyUserId
        settings = updated
        save(settings: updated)
    }

    private func resolvedServerUserId(for rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        if trimmed.allSatisfy(\.isNumber) {
            return trimmed
        }
        return BackendUserIDMapper.backendUserId(for: trimmed)
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
