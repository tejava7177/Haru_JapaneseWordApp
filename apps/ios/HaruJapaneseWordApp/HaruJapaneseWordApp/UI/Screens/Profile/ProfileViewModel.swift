import Foundation
import PhotosUI
import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers
import UserNotifications

private enum AppleAuthFlowError: LocalizedError {
    case missingIdentityToken
    case missingServerUserId

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple 로그인 토큰을 확인하지 못했어요. 다시 시도해 주세요."
        case .missingServerUserId:
            return "서버 계정을 확인하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var nicknameDraft: String
    @Published var bioDraft: String
    @Published var instagramIdDraft: String
    @Published var settings: AppSettings
    @Published var selectedLearningLevel: JLPTLevel
    @Published var isDarkModeEnabled: Bool
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isResetAlertPresented: Bool = false
    @Published var isLocalResetAlertPresented: Bool = false
    @Published var learningLevelNotice: String?
    @Published var learningLevelErrorMessage: String?
    @Published var isUpdatingLearningLevel: Bool = false
    @Published var dailyWordsRegenerateNotice: String?
    @Published var dailyWordsRegenerateErrorMessage: String?
    @Published var isRegeneratingDailyWords: Bool = false
    @Published var isRandomMatchingEnabled: Bool = false
    @Published var isUpdatingRandomMatching: Bool = false
    @Published var randomMatchingErrorMessage: String?
    @Published var randomMatchingNotice: String?
    @Published var isLearningNotificationEnabled: Bool
    @Published var learningNotificationSettings: LearningNotificationSettings
    @Published var isUpdatingLearningNotification: Bool = false
    @Published var learningNotificationNotice: String?
    @Published var learningNotificationErrorMessage: String?
    @Published private(set) var learningNotificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isSigningInWithApple: Bool = false
    @Published var appleSignInNotice: String?
    @Published var appleSignInErrorMessage: String?
    @Published var localResetNotice: String?
    @Published var localResetErrorMessage: String?
    @Published var isRefreshingServerProfile: Bool = false
    @Published var profileSourceText: String = "source: local fallback"
    @Published var profileRefreshErrorMessage: String?
    @Published var isSavingProfile: Bool = false
    @Published var profileSaveErrorMessage: String?
    @Published var profileSaveSuccessMessage: String?
    @Published var avatarLoadErrorMessage: String?
    @Published private(set) var localAvatarPreviewData: Data?
    @Published private(set) var avatarImageRefreshKey: String = UUID().uuidString

    private let profileStore: UserProfileStore
    private let settingsStore: AppSettingsStore
    private let authAPIService: AuthAPIServiceProtocol
    private let profileAPIService: ProfileAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var hasLoadedProfile: Bool = false
    private var lastLoadedBackendUserId: String?

    init(
        settingsStore: AppSettingsStore,
        profileStore: UserProfileStore = UserProfileStore(),
        authAPIService: AuthAPIServiceProtocol = AuthAPIService(),
        profileAPIService: ProfileAPIServiceProtocol = ProfileAPIService()
    ) {
        self.profileStore = profileStore
        self.settingsStore = settingsStore
        self.authAPIService = authAPIService
        self.profileAPIService = profileAPIService

        let legacyProfile = profileStore.load()
        self.profile = legacyProfile
        self.nicknameDraft = legacyProfile.nickname
        self.bioDraft = legacyProfile.bio
        self.instagramIdDraft = legacyProfile.instagramId
        self.settings = settingsStore.settings
        self.selectedLearningLevel = settingsStore.settings.homeDeckLevel
        self.isDarkModeEnabled = settingsStore.isDarkModeEnabled
        self.isLearningNotificationEnabled = settingsStore.settings.isLearningNotificationEnabled
        self.learningNotificationSettings = settingsStore.settings.learningNotificationSettings

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                let shouldSyncDrafts = self?.settings.mateUserId != value.mateUserId
                self?.settings = value
                self?.isLearningNotificationEnabled = value.isLearningNotificationEnabled
                self?.learningNotificationSettings = value.learningNotificationSettings
                self?.syncProfileFromCurrentUser(syncDrafts: shouldSyncDrafts)
                self?.refreshCurrentUserProfileFromServer(triggerSource: "onChange")
            }
            .store(in: &cancellables)

        settingsStore.$isDarkModeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isDarkModeEnabled = value
            }
            .store(in: &cancellables)

        settingsStore.$profileRefreshTick
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncProfileFromCurrentUser()
            }
            .store(in: &cancellables)

        settingsStore.$isSignedIn
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        syncProfileFromCurrentUser(syncDrafts: true)
        refreshCurrentUserProfileFromServer(triggerSource: "init")
    }

    func onViewAppear() {
        refreshCurrentUserProfileFromServer(triggerSource: "onAppear")
        Task {
            await refreshLearningNotificationAuthorizationStatus()
            await resyncLearningNotificationScheduleIfNeeded()
        }
    }

    func saveProfileEdits() {
        guard isSavingProfile == false else {
            print("[ProfileEdit] save blocked reason=disabled")
            return
        }

        guard hasProfileDraftChanges else {
            print("[ProfileEdit] save blocked reason=noChanges")
            return
        }

        let trimmedNickname = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bioDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstagramId = instagramIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let backendUserId = settingsStore.currentBackendUserId,
              backendUserId.isEmpty == false else {
            print("[ProfileEdit] save blocked reason=noUserId")
            profileSaveErrorMessage = "현재 로그인 사용자 정보를 확인하지 못했어요."
            return
        }

        guard trimmedNickname.isEmpty == false else {
            print("[ProfileEdit] save blocked reason=emptyNickname")
            profileSaveErrorMessage = "닉네임을 입력해 주세요."
            return
        }

        profileSaveErrorMessage = nil
        profileSaveSuccessMessage = nil
        isSavingProfile = true

        print("[ProfileEdit] start save userId=\(backendUserId)")
        print("[ProfileEdit] request nickname=\(trimmedNickname) bioExists=\(trimmedBio.isEmpty == false) instagramExists=\(trimmedInstagramId.isEmpty == false)")

        Task {
            defer { isSavingProfile = false }

            do {
                let response = try await profileAPIService.updateUserProfile(
                    userId: backendUserId,
                    nickname: trimmedNickname,
                    bio: trimmedBio,
                    instagramId: trimmedInstagramId
                )
                let avatarData = await resolvedAvatarData(
                    from: response,
                    fallbackAvatarData: settingsStore.currentMateProfile()?.avatarData ?? profile.avatarData
                )
                applyServerProfile(response, avatarData: avatarData, forceDraftSync: true)
                profileStore.save(profile: profile)
                profileSaveSuccessMessage = "저장되었어요."
                print("[ProfileEdit] success nickname=\(profile.nickname)")
                print("[ProfileEdit] synced local profile")
            } catch {
                profileSaveErrorMessage = profileSaveErrorMessage(for: error)
                print("[ProfileEdit] failed error=\(error.localizedDescription)")
            }
        }
    }

    func updateProfileLevel(_ level: JLPTLevel) {
        guard isUpdatingLearningLevel == false else { return }
        guard selectedLearningLevel != level else { return }

        let previousLevel = selectedLearningLevel
        selectedLearningLevel = level
        learningLevelErrorMessage = nil
        learningLevelNotice = nil

        guard let backendUserId = settingsStore.currentBackendUserId else {
            applyLearningLevelLocally(level)
            learningLevelNotice = "학습 레벨이 저장되었어요. 내일부터 오늘 단어에 반영돼요."
            return
        }

        isUpdatingLearningLevel = true

        Task {
            do {
                _ = try await profileAPIService.updateLearningLevel(userId: backendUserId, level: level)
                applyLearningLevelLocally(level)
                learningLevelNotice = "학습 레벨이 저장되었어요. 내일부터 오늘 단어에 반영돼요."
            } catch {
                selectedLearningLevel = previousLevel
                syncProfileFromCurrentUser()
                learningLevelErrorMessage = error.localizedDescription
            }
            isUpdatingLearningLevel = false
        }
    }

    var isMateLoggedIn: Bool { settingsStore.isMateLoggedIn }
    var hasAuthenticatedSession: Bool { settingsStore.hasAuthenticatedSession }
    var hasResolvedServerSession: Bool { settingsStore.hasResolvedServerSession }
    var currentServerUserId: String? { settingsStore.serverUserId }
    var currentMateUserId: String { settingsStore.mateUserId }
    var currentProfile: UserProfile { profile }
    var avatarImageURLForDisplay: String? {
        cacheBustedImagePath(profile.profileImageUrl, token: avatarImageRefreshKey)
    }
    var hasProfileDraftChanges: Bool {
        normalizeProfileField(nicknameDraft) != normalizeProfileField(profile.nickname)
            || normalizeProfileField(bioDraft) != normalizeProfileField(profile.bio)
            || normalizeProfileField(instagramIdDraft) != normalizeProfileField(profile.instagramId)
    }
    var canSaveProfile: Bool {
        hasResolvedServerSession
            && isSavingProfile == false
            && nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && hasProfileDraftChanges
    }

    var serverUserIdPrefix: String {
        let value = currentServerUserId ?? ""
        guard value.isEmpty == false else { return "" }
        let prefixLength = min(8, value.count)
        return String(value.prefix(prefixLength))
    }

    func signInWithApple() {
        guard isSigningInWithApple == false else { return }

        isSigningInWithApple = true
        appleSignInErrorMessage = nil
        appleSignInNotice = nil

        Task {
            defer { isSigningInWithApple = false }

            do {
                let result = try await AppleSignInManager.shared.signIn()
                let displayName = PersonNameComponentsFormatter().string(from: result.fullName ?? PersonNameComponents())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedDisplayName = displayName.isEmpty ? nil : displayName

                print("[AppleAuth] start backend authentication")
                print("[AppleAuth] identityToken exists=\(result.identityToken != nil)")
                let identityToken = try identityTokenString(from: result.identityToken)
                print("[AppleAuth] request appleUserId=\(result.userId)")

                let response = try await authAPIService.authenticateWithApple(
                    AppleAuthRequest(
                        identityToken: identityToken,
                        appleUserId: result.userId,
                        email: result.email,
                        displayName: resolvedDisplayName
                    )
                )

                guard let userId = response.userId else {
                    throw AppleAuthFlowError.missingServerUserId
                }

                print("[AppleAuth] success userId=\(userId) isNewUser=\(response.isNewUser ?? false)")

                let resolvedLearningLevel = response.learningLevel
                let resolvedEmail = response.email ?? result.email
                let resolvedServerDisplayName = response.displayName ?? resolvedDisplayName
                let resolvedNickname = response.nickname ?? resolvedServerDisplayName

                settingsStore.signIn(
                    appleUserId: result.userId,
                    email: resolvedEmail,
                    displayName: resolvedServerDisplayName,
                    serverUserId: String(userId),
                    nickname: resolvedNickname,
                    learningLevel: resolvedLearningLevel
                )

                print("[AppleAuth] persisted serverUserId=\(userId)")
                refreshCurrentUserProfileFromServer(triggerSource: "appleAuth", force: true)
                appleSignInNotice = "Apple 로그인에 성공했어요."
                print("[AppleAuth] UI updated signedIn=\(settingsStore.isSignedIn) serverUserId=\(settingsStore.serverUserId ?? "nil")")
            } catch {
                settingsStore.signOut()
                appleSignInErrorMessage = errorMessage(for: error)
                print("[AppleAuth] failed error=\(error.localizedDescription)")
                print("[AppleAuth] UI updated signedIn=\(settingsStore.isSignedIn) serverUserId=\(settingsStore.serverUserId ?? "nil")")
            }
        }
    }

    func signInForMate(userId: String) {
        settingsStore.signInForMate(userId: userId)
    }

    func signInForMateDevSlot(_ slot: AppSettingsStore.MateDevSlot) {
        settingsStore.signInForMateDevSlot(slot)
    }

    func signOutForMate() {
        let currentServerUserId = settingsStore.serverUserId
        Task {
            await PushRegistrationManager.shared.unregisterDeviceTokenIfNeeded(userId: currentServerUserId)
        }
        settingsStore.signOut()
        print("[AppleSignIn] UI updated loggedIn=\(settingsStore.isSignedIn)")
    }

    func updateDarkModeEnabled(_ enabled: Bool) {
        settingsStore.setDarkModeEnabled(enabled)
    }

    func updateLearningNotificationEnabled(_ enabled: Bool) {
        print("[Notification] toggle changed enabled=\(enabled)")
        var updated = learningNotificationSettings
        updated.isEnabled = enabled
        commitLearningNotificationSettings(updated, showToggleNotice: true)
    }

    func updateLearningNotificationTime(_ date: Date) {
        var updated = learningNotificationSettings
        updated.notificationTimeMinutes = LearningNotificationSettings.minutes(from: date)
        commitLearningNotificationSettings(updated)
    }

    func updateLearningNotificationRepeating(_ enabled: Bool) {
        var updated = learningNotificationSettings
        updated.isRepeating = enabled
        if enabled, let preferredInterval = LearningNotificationSettings.preferredInterval(from: updated.availableRepeatIntervals) {
            updated.repeatInterval = preferredInterval
        }
        commitLearningNotificationSettings(updated)
    }

    func updateLearningNotificationRange(start: Date, end: Date) {
        var updated = learningNotificationSettings
        updated.repeatStartMinutes = LearningNotificationSettings.minutes(from: start)
        updated.repeatEndMinutes = LearningNotificationSettings.minutes(from: end)
        if let preferredInterval = resolvedRepeatInterval(for: updated) {
            updated.repeatInterval = preferredInterval
        }
        commitLearningNotificationSettings(updated)
    }

    func updateLearningNotificationRange(
        start: Date,
        end: Date,
        interval: LearningNotificationSettings.RepeatInterval?
    ) {
        var updated = learningNotificationSettings
        updated.repeatStartMinutes = LearningNotificationSettings.minutes(from: start)
        updated.repeatEndMinutes = LearningNotificationSettings.minutes(from: end)
        if let interval {
            updated.repeatInterval = interval
        }
        if let preferredInterval = resolvedRepeatInterval(for: updated) {
            updated.repeatInterval = preferredInterval
        }
        commitLearningNotificationSettings(updated)
    }

    func updateLearningNotificationInterval(_ interval: LearningNotificationSettings.RepeatInterval) {
        var updated = learningNotificationSettings
        updated.repeatInterval = interval
        commitLearningNotificationSettings(updated)
    }

    var availableLearningNotificationIntervals: [LearningNotificationSettings.RepeatInterval] {
        learningNotificationSettings.availableRepeatIntervals
    }

    var learningNotificationSummaryText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"

        if learningNotificationSettings.isRepeating {
            return "\(formatter.string(from: learningNotificationSettings.repeatStartTime)) ~ \(formatter.string(from: learningNotificationSettings.repeatEndTime))"
        }

        return formatter.string(from: learningNotificationSettings.notificationTime)
    }

    func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        avatarLoadErrorMessage = nil

        let supportedTypes = item.supportedContentTypes.map(\.identifier)
        print("[Profile] avatar load start supportedTypes=\(supportedTypes)")

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                print("[Profile] avatar load success via Data bytes=\(data.count)")
                await handleLoadedAvatarData(data)
                return
            }

            print("[Profile] avatar load via Data returned nil; falling back to Image")

            if let image = try await item.loadTransferable(type: Image.self) {
                let renderedData = renderImageToJPEGData(image)
                if let renderedData {
                    print("[Profile] avatar load success via Image fallback bytes=\(renderedData.count)")
                    await handleLoadedAvatarData(renderedData)
                    return
                }

                print("[Profile] avatar image fallback render failed")
            } else {
                print("[Profile] avatar load via Image returned nil")
            }
        } catch {
            print("[Profile] avatar load failed supportedTypes=\(supportedTypes) error=\(error.localizedDescription)")
            avatarLoadErrorMessage = "선택한 사진을 불러오지 못했어요. 다른 사진으로 다시 시도해 주세요."
            return
        }

        print("[Profile] avatar load failed no supported transferable result supportedTypes=\(supportedTypes)")
        avatarLoadErrorMessage = "선택한 사진을 불러오지 못했어요. 다른 사진으로 다시 시도해 주세요."
    }

    func regenerateTodayDailyWordsForDevelopment() {
        guard isRegeneratingDailyWords == false else { return }
        guard let backendUserId = settingsStore.currentBackendUserId else {
            dailyWordsRegenerateErrorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        isRegeneratingDailyWords = true
        dailyWordsRegenerateErrorMessage = nil
        dailyWordsRegenerateNotice = nil

        Task {
            do {
                _ = try await profileAPIService.regenerateTodayDailyWords(userId: backendUserId)
                NotificationCenter.default.post(name: .dailyWordsDidRegenerate, object: nil)
                dailyWordsRegenerateNotice = "오늘 단어를 다시 생성했어요."
            } catch {
                dailyWordsRegenerateErrorMessage = error.localizedDescription
            }
            isRegeneratingDailyWords = false
        }
    }

    func clearLearningLevelNotice() {
        learningLevelNotice = nil
    }

    func clearLearningLevelError() {
        learningLevelErrorMessage = nil
    }

    func clearDailyWordsRegenerateNotice() {
        dailyWordsRegenerateNotice = nil
    }

    func clearDailyWordsRegenerateError() {
        dailyWordsRegenerateErrorMessage = nil
    }

    func updateRandomMatchingEnabled(_ enabled: Bool) {
        guard isUpdatingRandomMatching == false else { return }
        guard let backendUserId = settingsStore.currentBackendUserId else {
            randomMatchingErrorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        let previousValue = isRandomMatchingEnabled
        isRandomMatchingEnabled = enabled
        randomMatchingErrorMessage = nil
        randomMatchingNotice = nil
        isUpdatingRandomMatching = true

        Task {
            do {
                let response = try await profileAPIService.updateRandomMatching(userId: backendUserId, enabled: enabled)
                let resolvedEnabled = response.enabled ?? enabled
                settingsStore.updateCurrentMateRandomMatchingEnabled(resolvedEnabled)
                isRandomMatchingEnabled = resolvedEnabled
                randomMatchingNotice = resolvedEnabled
                    ? "랜덤 매칭 노출을 켰어요."
                    : "랜덤 매칭 노출을 껐어요."
            } catch {
                isRandomMatchingEnabled = previousValue
                randomMatchingErrorMessage = error.localizedDescription
            }
            isUpdatingRandomMatching = false
        }
    }

    func clearRandomMatchingNotice() {
        randomMatchingNotice = nil
    }

    func clearRandomMatchingError() {
        randomMatchingErrorMessage = nil
    }

    func clearLearningNotificationNotice() {
        learningNotificationNotice = nil
    }

    func clearLearningNotificationError() {
        learningNotificationErrorMessage = nil
    }

    func clearAppleSignInNotice() {
        appleSignInNotice = nil
    }

    func clearAppleSignInError() {
        appleSignInErrorMessage = nil
    }

    func clearProfileSaveError() {
        profileSaveErrorMessage = nil
    }

    func clearProfileSaveSuccessMessage() {
        profileSaveSuccessMessage = nil
    }

    func clearLocalResetNotice() {
        localResetNotice = nil
    }

    func clearLocalResetError() {
        localResetErrorMessage = nil
    }

    func clearAvatarLoadError() {
        avatarLoadErrorMessage = nil
    }

    func resetLocalStateForDevelopment() {
        localResetErrorMessage = nil
        settingsStore.clearLocalStateForDevelopment()
        profile = profileStore.load()
        settings = settingsStore.settings
        selectedLearningLevel = settingsStore.settings.homeDeckLevel
        isLearningNotificationEnabled = settingsStore.settings.isLearningNotificationEnabled
        learningNotificationSettings = settingsStore.settings.learningNotificationSettings
        isRandomMatchingEnabled = false
        localResetNotice = "로컬 상태를 초기화했어요."
        localAvatarPreviewData = nil
        syncDraftsFromProfile()
    }

    private func syncProfileFromCurrentUser(syncDrafts: Bool = false) {
        if let mateProfile = settingsStore.currentMateProfile() {
            profileSourceText = "source: local fallback"
            profileRefreshErrorMessage = nil
            profile.nickname = mateProfile.displayName
            profile.bio = mateProfile.bio
            profile.instagramId = mateProfile.instagramId
            profile.profileImageUrl = mateProfile.profileImageUrl
            profile.avatarData = mateProfile.avatarData
            selectedLearningLevel = mateProfile.jlptLevel
            isRandomMatchingEnabled = settingsStore.currentMateRandomMatchingEnabled()
        } else {
            let legacyProfile = profileStore.load()
            print("[Profile] fallback to legacy local profile store")
            profileSourceText = "source: local fallback"
            profileRefreshErrorMessage = nil
            profile.nickname = legacyProfile.nickname
            profile.bio = legacyProfile.bio
            profile.instagramId = legacyProfile.instagramId
            profile.profileImageUrl = legacyProfile.profileImageUrl
            profile.avatarData = legacyProfile.avatarData
            selectedLearningLevel = settingsStore.settings.homeDeckLevel
            isRandomMatchingEnabled = false
        }
        profileStore.save(profile: profile)
        if syncDrafts {
            syncDraftsFromProfile()
        }
    }

    private func refreshCurrentUserProfileFromServer(triggerSource: String, force: Bool = false) {
        Task {
            await refreshCurrentUserProfileFromServerNow(triggerSource: triggerSource, force: force)
        }
    }

    private func commitLearningNotificationSettings(_ updatedSettings: LearningNotificationSettings, showToggleNotice: Bool = false) {
        guard isUpdatingLearningNotification == false else { return }
        guard updatedSettings.isRepeating == false || updatedSettings.hasValidRepeatingRange else {
            learningNotificationErrorMessage = "시작 시간은 종료 시간보다 늦을 수 없어요."
            return
        }
        guard updatedSettings.isRepeating == false || updatedSettings.availableRepeatIntervals.isEmpty == false else {
            learningNotificationErrorMessage = "시간 범위를 더 넓혀서 반복 간격을 선택해 주세요."
            return
        }
        guard updatedSettings.isRepeating == false || updatedSettings.availableRepeatIntervals.contains(updatedSettings.repeatInterval) else {
            learningNotificationErrorMessage = "현재 시간 범위에서 사용할 수 없는 반복 간격이에요."
            return
        }
        guard updatedSettings != learningNotificationSettings else { return }

        learningNotificationErrorMessage = nil
        learningNotificationNotice = nil
        isUpdatingLearningNotification = true

        let previousSettings = learningNotificationSettings

        Task {
            defer { isUpdatingLearningNotification = false }

            if updatedSettings.isEnabled {
                let granted = await NotificationManager.shared.requestAuthorizationIfNeeded()
                await refreshLearningNotificationAuthorizationStatus()

                guard granted else {
                    learningNotificationNotice = "알림 권한이 꺼져 있어요. 설정에서 알림을 허용해 주세요."
                    return
                }

                let didSchedule = await NotificationManager.shared.scheduleLearningReminders(using: updatedSettings)
                guard didSchedule else {
                    learningNotificationErrorMessage = "학습 알림을 적용하지 못했어요."
                    return
                }

                settingsStore.updateLearningNotificationSettings(updatedSettings)
                learningNotificationSettings = updatedSettings
                isLearningNotificationEnabled = true

                if previousSettings.isEnabled == false {
                    await PushRegistrationManager.shared.syncRegistrationState()
                }

                if showToggleNotice {
                    learningNotificationNotice = updatedSettings.isRepeating
                        ? "반복 학습 알림을 켰어요."
                        : "매일 설정한 시간에 학습 알림을 보내드릴게요."
                }
                return
            }

            await NotificationManager.shared.cancelLearningReminders()
            settingsStore.updateLearningNotificationSettings(updatedSettings)
            learningNotificationSettings = updatedSettings
            isLearningNotificationEnabled = false

            if previousSettings.isEnabled {
                await PushRegistrationManager.shared.unregisterDeviceTokenIfNeeded(userId: settingsStore.serverUserId)
            }

            if showToggleNotice {
                learningNotificationNotice = "학습 알림을 껐어요."
            }
        }
    }

    private func refreshLearningNotificationAuthorizationStatus() async {
        learningNotificationAuthorizationStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func resyncLearningNotificationScheduleIfNeeded() async {
        let storedSettings = settingsStore.settings.learningNotificationSettings

        guard storedSettings.isEnabled else {
            await NotificationManager.shared.cancelLearningReminders()
            return
        }

        let authorizationStatus = await NotificationManager.shared.authorizationStatus()
        learningNotificationAuthorizationStatus = authorizationStatus

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            _ = await NotificationManager.shared.scheduleLearningReminders(using: storedSettings)
        case .denied, .notDetermined:
            await NotificationManager.shared.cancelLearningReminders()
        @unknown default:
            await NotificationManager.shared.cancelLearningReminders()
        }
    }

    private func resolvedRepeatInterval(for settings: LearningNotificationSettings) -> LearningNotificationSettings.RepeatInterval? {
        let availableIntervals = settings.availableRepeatIntervals
        guard availableIntervals.isEmpty == false else { return nil }
        if availableIntervals.contains(settings.repeatInterval) {
            return settings.repeatInterval
        }
        return LearningNotificationSettings.preferredInterval(from: availableIntervals)
    }

    private func applyServerProfile(_ response: ServerUserProfileResponse, avatarData: Data?, forceDraftSync: Bool = false) {
        let shouldSyncDrafts = forceDraftSync || hasProfileDraftChanges == false
        let currentUserId = settingsStore.mateUserId
        let cachedProfile = settingsStore.currentMateProfile()

        if let nickname = trimmedNonEmpty(response.nickname) {
            print("[Profile] server nickname=\(nickname)")
        }
        if let bio = trimmedNonEmpty(response.bio) {
            print("[Profile] server bio=\(bio)")
        }
        if let instagramId = trimmedNonEmpty(response.instagramId) {
            print("[Profile] server instagramId=\(instagramId)")
        }
        print("[ProfileImage] server profileImageUrl=\(response.profileImageUrl ?? "nil")")
        if let learningLevel = response.learningLevel {
            print("[Profile] server learningLevel=\(learningLevel.rawValue)")
        }
        print("[Profile] decoded nickname=\(response.nickname ?? "nil")")
        print("[Profile] decoded bio=\(response.bio ?? "nil")")
        print("[Profile] decoded instagram=\(response.instagramId ?? "nil")")
        print("[Profile] decoded learningLevel=\(response.learningLevel?.rawValue ?? "nil")")

        let resolvedNickname = resolveServerEditableText(
            serverValue: response.nickname,
            fallbackValue: cachedProfile?.displayName,
            fieldName: "nickname"
        ) ?? "하루"
        let resolvedBio = resolveServerEditableText(
            serverValue: response.bio,
            fallbackValue: cachedProfile?.bio,
            fieldName: "bio"
        ) ?? ""
        let resolvedInstagramId = resolveServerEditableText(
            serverValue: response.instagramId,
            fallbackValue: cachedProfile?.instagramId,
            fieldName: "instagramId"
        ) ?? ""
        let resolvedLevel = resolveLearningLevel(
            serverValue: response.learningLevel,
            fallbackValue: cachedProfile?.jlptLevel
        ) ?? .n5
        let resolvedRandomMatchingEnabled = response.randomMatchingEnabled ?? settingsStore.currentMateRandomMatchingEnabled()
        let resolvedProfileImageUrl = trimmedNonEmpty(response.profileImageUrl)
        if resolvedProfileImageUrl != nil {
            avatarImageRefreshKey = UUID().uuidString
            print("[ProfileImage] server profileImageUrl=\(resolvedProfileImageUrl ?? "nil")")
        }

        let didUpdateStore = settingsStore.applyServerProfile(
            userId: currentUserId,
            nickname: resolvedNickname,
            bio: resolvedBio,
            instagramId: resolvedInstagramId,
            jlptLevel: resolvedLevel,
            profileImageUrl: resolvedProfileImageUrl,
            avatarData: avatarData,
            randomMatchingEnabled: resolvedRandomMatchingEnabled
        )
        if didUpdateStore {
            print("[Profile] using server profile values")
        } else {
            print("[Profile] store update skipped no changes")
        }
        profileSourceText = "source: server"
        profileRefreshErrorMessage = nil
        syncProfileFromCurrentUser(syncDrafts: shouldSyncDrafts)
        localAvatarPreviewData = nil
        profileSourceText = "source: server"
    }

    private func resolveServerEditableText(serverValue: String?, fallbackValue: String?, fieldName: String) -> String? {
        if let serverValue {
            let trimmed = serverValue.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[Profile] using server \(fieldName)=\(trimmed.isEmpty ? "<empty>" : trimmed)")
            return trimmed
        }

        if let fallbackValue {
            let trimmed = fallbackValue.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[Profile] fallback to local \(fieldName)")
            return trimmed
        }

        print("[Profile] using placeholder \(fieldName)")
        return nil
    }

    private func syncDraftsFromProfile() {
        nicknameDraft = profile.nickname
        bioDraft = profile.bio
        instagramIdDraft = profile.instagramId
    }

    private func normalizeProfileField(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveLearningLevel(serverValue: JLPTLevel?, fallbackValue: JLPTLevel?) -> JLPTLevel? {
        if let serverValue {
            print("[Profile] using server learningLevel=\(serverValue.rawValue)")
            return serverValue
        }

        if let fallbackValue {
            print("[Profile] fallback to local learningLevel")
            return fallbackValue
        }

        print("[Profile] using placeholder learningLevel")
        return nil
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }

    private func decodeAvatarData(from base64: String?) -> Data? {
        guard let base64 = trimmedNonEmpty(base64) else { return nil }
        return Data(base64Encoded: base64)
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.8) ?? data
    }

    private func resizeImageForUpload(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let originalSize = image.size
        let largestSide = max(originalSize.width, originalSize.height)

        if largestSide > maxDimension {
            let scale = maxDimension / largestSide
            let targetSize = CGSize(
                width: max(1, floor(originalSize.width * scale)),
                height: max(1, floor(originalSize.height * scale))
            )

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        return image
    }

    private func makeUploadImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return compressImageData(data) }

        let resizedImage = resizeImageForUpload(image)
        let compressionCandidates: [CGFloat] = [0.7, 0.6, 0.5]
        let preferredMaxUploadBytes = 900_000

        for quality in compressionCandidates {
            if let jpegData = resizedImage.jpegData(compressionQuality: quality),
               jpegData.count <= preferredMaxUploadBytes {
                return jpegData
            }
        }

        return resizedImage.jpegData(compressionQuality: 0.4)
            ?? resizedImage.jpegData(compressionQuality: 0.5)
            ?? data
    }

    private func applyLoadedAvatarData(_ data: Data) {
        let compressed = compressImageData(data)
        localAvatarPreviewData = nil
        profile.avatarData = compressed
        profile.profileImageUrl = nil
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateProfileImageUrl(nil)
            settingsStore.updateCurrentMateAvatarData(compressed)
        } else {
            profileStore.updateProfileImageUrl(nil)
            profileStore.updateAvatar(compressed)
        }
    }

    private func applyAvatarPreview(_ data: Data) {
        let compressed = compressImageData(data)
        localAvatarPreviewData = compressed
        profile.avatarData = compressed
        avatarImageRefreshKey = UUID().uuidString
        print("[ProfileImage] local preview updated size=\(compressed?.count ?? data.count)")
    }

    private func renderImageToJPEGData(_ image: Image) -> Data? {
        let renderer = ImageRenderer(content: image.resizable().scaledToFit())
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.jpegData(compressionQuality: 0.8)
    }

    private func handleLoadedAvatarData(_ data: Data) async {
        let previewData = UIImage(data: data) != nil ? data : (compressImageData(data) ?? data)
        let uploadData = makeUploadImageData(from: data) ?? previewData
        print("[ProfileImage] original image bytes=\(data.count)")
        print("[ProfileImage] resized image bytes=\(uploadData.count)")

        guard let backendUserId = settingsStore.currentBackendUserId,
              settingsStore.isMateLoggedIn else {
            applyLoadedAvatarData(previewData)
            return
        }

        applyAvatarPreview(previewData)

        do {
            print("[ProfileImage] upload start userId=\(backendUserId)")
            _ = try await profileAPIService.uploadProfileImage(
                userId: backendUserId,
                imageData: uploadData,
                fileName: "profile.jpg",
                mimeType: "image/jpeg"
            )
            print("[ProfileImage] upload success")
            print("[ProfileImage] refresh profile after upload")
            hasLoadedProfile = false
            avatarImageRefreshKey = UUID().uuidString
            await refreshCurrentUserProfileFromServerNow(
                triggerSource: "profileImageUpload",
                force: true,
                cacheBustImage: true
            )
        } catch {
            print("[ProfileImage] upload failed error=\(error.localizedDescription)")
            localAvatarPreviewData = nil
            syncProfileFromCurrentUser()
            avatarLoadErrorMessage = "프로필 사진을 서버에 저장하지 못했어요. 다시 시도해 주세요."
        }
    }

    private func refreshCurrentUserProfileFromServerNow(
        triggerSource: String,
        force: Bool = false,
        cacheBustImage: Bool = false
    ) async {
        print("[Profile] trigger source=\(triggerSource)")
        let mateUserId = settingsStore.mateUserId
        guard mateUserId.isEmpty == false else {
            print("[Profile] currentBackendUserId=nil reason=mateUserId empty")
            profileSourceText = "source: local fallback"
            profileRefreshErrorMessage = nil
            hasLoadedProfile = false
            lastLoadedBackendUserId = nil
            return
        }

        guard let backendUserId = settingsStore.currentBackendUserId else {
            print("[Profile] currentBackendUserId=nil reason=unmapped mateUserId=\(mateUserId)")
            profileSourceText = "source: local fallback"
            profileRefreshErrorMessage = "서버 사용자 ID를 찾지 못해 로컬 프로필을 표시하고 있어요."
            hasLoadedProfile = false
            lastLoadedBackendUserId = nil
            return
        }

        if isRefreshingServerProfile, force == false {
            print("[Profile] skip duplicate fetch currentBackendUserId=\(backendUserId)")
            return
        }

        if force == false, hasLoadedProfile, lastLoadedBackendUserId == backendUserId {
            print("[Profile] fetch skipped already loaded")
            return
        }

        print("[Profile] currentBackendUserId=\(backendUserId)")
        isRefreshingServerProfile = true
        lastLoadedBackendUserId = backendUserId
        defer { isRefreshingServerProfile = false }

        do {
            let response = try await profileAPIService.fetchUserProfile(userId: backendUserId)
            let avatarData = await resolvedAvatarData(
                from: response,
                fallbackAvatarData: settingsStore.currentMateProfile()?.avatarData,
                cacheBustImage: cacheBustImage
            )
            hasLoadedProfile = true
            applyServerProfile(response, avatarData: avatarData)
        } catch {
            hasLoadedProfile = false
            profileSourceText = "source: local fallback"
            profileRefreshErrorMessage = "프로필 서버 동기화에 실패해 로컬 데이터를 표시하고 있어요."
            print("[Profile] fetch failed error=\(error.localizedDescription)")
        }
    }

    private func resolvedAvatarData(
        from response: ServerUserProfileResponse,
        fallbackAvatarData: Data?,
        cacheBustImage: Bool = false
    ) async -> Data? {
        if let avatarData = decodeAvatarData(from: response.avatarBase64) {
            return avatarData
        }

        if let profileImageUrl = trimmedNonEmpty(response.profileImageUrl),
           let avatarData = await downloadImageData(from: profileImageUrl, cacheBust: cacheBustImage) {
            return avatarData
        }

        return fallbackAvatarData
    }

    private func downloadImageData(from path: String, cacheBust: Bool = false) async -> Data? {
        guard let url = resolvedImageURL(from: path, cacheBust: cacheBust) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return data
        } catch {
            print("[Profile] image download failed url=\(path) error=\(error.localizedDescription)")
            return nil
        }
    }

    private func resolvedImageURL(from path: String, cacheBust: Bool = false) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return cacheBust ? appendCacheBust(to: url) : url
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let resolvedURL = APIConfiguration.baseURL.appendingPathComponent(trimmedPath)
        return cacheBust ? appendCacheBust(to: resolvedURL) : resolvedURL
    }

    private func cacheBustedImagePath(_ path: String?, token: String?) -> String? {
        guard let path = trimmedNonEmpty(path),
              let token = trimmedNonEmpty(token) else {
            return path
        }

        if var components = URLComponents(string: path), components.scheme != nil {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "t" }
            items.append(URLQueryItem(name: "t", value: token))
            components.queryItems = items
            return components.url?.absoluteString ?? path
        }

        let separator = path.contains("?") ? "&" : "?"
        return "\(path)\(separator)t=\(token)"
    }

    private func appendCacheBust(to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "t" }
        items.append(URLQueryItem(name: "t", value: avatarImageRefreshKey))
        components.queryItems = items
        return components.url ?? url
    }

    private func applyLearningLevelLocally(_ level: JLPTLevel) {
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateJLPTLevel(level)
        } else {
            settingsStore.updateHomeDeckLevel(level)
        }
        selectedLearningLevel = level
    }

    private func profileSaveErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .server(_, let message):
                if let message, message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return message
                }
            default:
                break
            }
        }
        return "프로필을 저장하지 못했어요. 잠시 후 다시 시도해주세요."
    }

    private func identityTokenString(from data: Data?) throws -> String {
        guard let data,
              let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            throw AppleAuthFlowError.missingIdentityToken
        }
        return token
    }

    private func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .server(_, let message):
                return message ?? "서버 계정을 확인하지 못했어요. 잠시 후 다시 시도해주세요."
            case .requestFailed, .invalidResponse:
                return "서버 계정을 확인하지 못했어요. 잠시 후 다시 시도해주세요."
            case .decodingFailed, .encodingFailed, .invalidURL:
                return "로그인 응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }

        return error.localizedDescription
    }
}
