import Foundation
import PhotosUI
import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
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
    @Published var isUpdatingLearningNotification: Bool = false
    @Published var learningNotificationNotice: String?
    @Published var learningNotificationErrorMessage: String?
    @Published var localResetNotice: String?
    @Published var localResetErrorMessage: String?
    @Published var isRefreshingServerProfile: Bool = false
    @Published var profileSourceText: String = "source: local fallback"
    @Published var avatarLoadErrorMessage: String?
    @Published private(set) var localAvatarPreviewData: Data?

    private let profileStore: UserProfileStore
    private let settingsStore: AppSettingsStore
    private let profileAPIService: ProfileAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var hasLoadedProfile: Bool = false
    private var lastLoadedBackendUserId: String?

    init(
        settingsStore: AppSettingsStore,
        profileStore: UserProfileStore = UserProfileStore(),
        profileAPIService: ProfileAPIServiceProtocol = ProfileAPIService()
    ) {
        self.profileStore = profileStore
        self.settingsStore = settingsStore
        self.profileAPIService = profileAPIService

        let legacyProfile = profileStore.load()
        self.profile = legacyProfile
        self.settings = settingsStore.settings
        self.selectedLearningLevel = settingsStore.settings.homeDeckLevel
        self.isDarkModeEnabled = settingsStore.isDarkModeEnabled
        self.isLearningNotificationEnabled = settingsStore.settings.isLearningNotificationEnabled

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.settings = value
                self?.isLearningNotificationEnabled = value.isLearningNotificationEnabled
                self?.syncProfileFromCurrentUser()
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

        syncProfileFromCurrentUser()
        refreshCurrentUserProfileFromServer(triggerSource: "init")
    }

    func onViewAppear() {
        refreshCurrentUserProfileFromServer(triggerSource: "onAppear")
    }

    func updateNickname(_ nickname: String) {
        guard settingsStore.isMateLoggedIn == false else { return }
        profile.nickname = nickname
        profileStore.updateNickname(nickname)
    }

    func updateBio(_ bio: String) {
        guard settingsStore.isMateLoggedIn == false else { return }
        profile.bio = bio
        profileStore.updateBio(bio)
    }

    func updateInstagram(_ instagramId: String) {
        guard settingsStore.isMateLoggedIn == false else { return }
        profile.instagramId = instagramId
        profileStore.updateInstagram(instagramId)
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
    var currentMateUserId: String { settingsStore.mateUserId }
    var currentProfile: UserProfile { profile }

    var mateUserIdPrefix: String {
        let value = currentMateUserId
        guard value.isEmpty == false else { return "" }
        let prefixLength = min(8, value.count)
        return String(value.prefix(prefixLength))
    }

    func signInWithApple(userId: String) {
        settingsStore.signIn(appleUserId: userId)
    }

    func signInForMate(userId: String) {
        settingsStore.signInForMate(userId: userId)
    }

    func signInForMateDevSlot(_ slot: AppSettingsStore.MateDevSlot) {
        settingsStore.signInForMateDevSlot(slot)
    }

    func signOutForMate() {
        settingsStore.signOutForMate()
    }

    func updateDarkModeEnabled(_ enabled: Bool) {
        settingsStore.setDarkModeEnabled(enabled)
    }

    func updateLearningNotificationEnabled(_ enabled: Bool) {
        print("[Notification] toggle changed enabled=\(enabled)")
        guard isUpdatingLearningNotification == false else { return }

        learningNotificationErrorMessage = nil
        learningNotificationNotice = nil
        isUpdatingLearningNotification = true

        Task {
            defer { isUpdatingLearningNotification = false }

            if enabled {
                let granted = await NotificationManager.shared.requestAuthorizationIfNeeded()
                guard granted else {
                    settingsStore.setLearningNotificationEnabled(false)
                    isLearningNotificationEnabled = false
                    learningNotificationNotice = "알림 권한이 꺼져 있어요. 설정에서 알림을 허용해 주세요."
                    return
                }

                settingsStore.setLearningNotificationEnabled(true)
                isLearningNotificationEnabled = true
                await NotificationManager.shared.scheduleDailyLearningReminder()
                learningNotificationNotice = "매일 오후 8시에 학습 알림을 보내드릴게요."
                return
            }

            settingsStore.setLearningNotificationEnabled(false)
            isLearningNotificationEnabled = false
            await NotificationManager.shared.cancelDailyLearningReminder()
            learningNotificationNotice = "학습 알림을 껐어요."
        }
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
        isRandomMatchingEnabled = false
        localResetNotice = "로컬 상태를 초기화했어요."
        localAvatarPreviewData = nil
    }

    private func syncProfileFromCurrentUser() {
        if let mateProfile = settingsStore.currentMateProfile() {
            profileSourceText = "source: local fallback"
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
            profile.nickname = legacyProfile.nickname
            profile.bio = legacyProfile.bio
            profile.instagramId = legacyProfile.instagramId
            profile.profileImageUrl = legacyProfile.profileImageUrl
            profile.avatarData = legacyProfile.avatarData
            selectedLearningLevel = settingsStore.settings.homeDeckLevel
            isRandomMatchingEnabled = false
        }
    }

    private func refreshCurrentUserProfileFromServer(triggerSource: String, force: Bool = false) {
        Task {
            await refreshCurrentUserProfileFromServerNow(triggerSource: triggerSource, force: force)
        }
    }

    private func applyServerProfile(_ response: ServerUserProfileResponse, avatarData: Data?) {
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

        let resolvedNickname = resolveServerText(
            serverValue: response.nickname,
            fallbackValue: cachedProfile?.displayName,
            fieldName: "nickname"
        ) ?? "하루"
        let resolvedBio = resolveServerText(
            serverValue: response.bio,
            fallbackValue: cachedProfile?.bio,
            fieldName: "bio"
        ) ?? ""
        let resolvedInstagramId = resolveServerText(
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
        syncProfileFromCurrentUser()
        localAvatarPreviewData = nil
        profileSourceText = "source: server"
    }

    private func resolveServerText(serverValue: String?, fallbackValue: String?, fieldName: String) -> String? {
        if let serverValue = trimmedNonEmpty(serverValue) {
            print("[Profile] using server \(fieldName)=\(serverValue)")
            return serverValue
        }

        if let fallbackValue = trimmedNonEmpty(fallbackValue) {
            print("[Profile] fallback to local \(fieldName)")
            return fallbackValue
        }

        print("[Profile] using placeholder \(fieldName)")
        return nil
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
    }

    private func renderImageToJPEGData(_ image: Image) -> Data? {
        let renderer = ImageRenderer(content: image.resizable().scaledToFit())
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.jpegData(compressionQuality: 0.8)
    }

    private func handleLoadedAvatarData(_ data: Data) async {
        let compressed = compressImageData(data) ?? data
        print("[ProfileImage] selected image size=\(compressed.count)")

        guard let backendUserId = settingsStore.currentBackendUserId,
              settingsStore.isMateLoggedIn else {
            applyLoadedAvatarData(compressed)
            return
        }

        applyAvatarPreview(compressed)

        do {
            print("[ProfileImage] upload start userId=\(backendUserId)")
            let response = try await profileAPIService.uploadProfileImage(
                userId: backendUserId,
                imageData: compressed,
                fileName: "profile.jpg",
                mimeType: "image/jpeg"
            )
            print("[ProfileImage] upload success url=\(response.profileImageUrl ?? "nil")")
            print("[ProfileImage] refresh profile after upload")
            hasLoadedProfile = false
            await refreshCurrentUserProfileFromServerNow(triggerSource: "profileImageUpload", force: true)
        } catch {
            print("[ProfileImage] upload failed error=\(error.localizedDescription)")
            localAvatarPreviewData = nil
            syncProfileFromCurrentUser()
            avatarLoadErrorMessage = "프로필 사진을 서버에 저장하지 못했어요. 다시 시도해 주세요."
        }
    }

    private func refreshCurrentUserProfileFromServerNow(triggerSource: String, force: Bool = false) async {
        print("[Profile] trigger source=\(triggerSource)")
        let mateUserId = settingsStore.mateUserId
        guard mateUserId.isEmpty == false else {
            print("[Profile] currentBackendUserId=nil reason=mateUserId empty")
            profileSourceText = "source: local fallback"
            hasLoadedProfile = false
            lastLoadedBackendUserId = nil
            return
        }

        guard let backendUserId = settingsStore.currentBackendUserId else {
            print("[Profile] currentBackendUserId=nil reason=unmapped mateUserId=\(mateUserId)")
            profileSourceText = "source: local fallback"
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
                fallbackAvatarData: settingsStore.currentMateProfile()?.avatarData
            )
            hasLoadedProfile = true
            applyServerProfile(response, avatarData: avatarData)
        } catch {
            hasLoadedProfile = false
            profileSourceText = "source: local fallback"
            print("[Profile] fetch failed error=\(error.localizedDescription)")
        }
    }

    private func resolvedAvatarData(from response: ServerUserProfileResponse, fallbackAvatarData: Data?) async -> Data? {
        if let avatarData = decodeAvatarData(from: response.avatarBase64) {
            return avatarData
        }

        if let profileImageUrl = trimmedNonEmpty(response.profileImageUrl),
           let avatarData = await downloadImageData(from: profileImageUrl) {
            return avatarData
        }

        return fallbackAvatarData
    }

    private func downloadImageData(from path: String) async -> Data? {
        guard let url = resolvedImageURL(from: path) else { return nil }
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

    private func resolvedImageURL(from path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return APIConfiguration.baseURL.appendingPathComponent(trimmedPath)
    }

    private func applyLearningLevelLocally(_ level: JLPTLevel) {
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateJLPTLevel(level)
        } else {
            settingsStore.updateHomeDeckLevel(level)
        }
        selectedLearningLevel = level
    }
}
