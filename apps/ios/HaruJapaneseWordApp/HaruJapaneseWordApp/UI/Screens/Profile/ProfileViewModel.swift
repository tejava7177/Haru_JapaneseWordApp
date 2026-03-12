import Foundation
import PhotosUI
import SwiftUI
import Combine
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var settings: AppSettings
    @Published var selectedLearningLevel: JLPTLevel
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isResetAlertPresented: Bool = false
    @Published var learningLevelNotice: String?
    @Published var learningLevelErrorMessage: String?
    @Published var isUpdatingLearningLevel: Bool = false
    @Published var dailyWordsRegenerateNotice: String?
    @Published var dailyWordsRegenerateErrorMessage: String?
    @Published var isRegeneratingDailyWords: Bool = false

    private let profileStore: UserProfileStore
    private let settingsStore: AppSettingsStore
    private let profileAPIService: ProfileAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []

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

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.settings = value
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
    }

    func updateNickname(_ nickname: String) {
        profile.nickname = nickname
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateDisplayName(nickname)
        } else {
            profileStore.updateNickname(nickname)
        }
    }

    func updateBio(_ bio: String) {
        profile.bio = bio
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateBio(bio)
        } else {
            profileStore.updateBio(bio)
        }
    }

    func updateInstagram(_ instagramId: String) {
        profile.instagramId = instagramId
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateInstagramId(instagramId)
        } else {
            profileStore.updateInstagram(instagramId)
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

    func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            let compressed = compressImageData(data)
            profile.avatarData = compressed
            profileStore.updateAvatar(compressed)
        }
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

    private func syncProfileFromCurrentUser() {
        if let mateProfile = settingsStore.currentMateProfile() {
            profile.nickname = mateProfile.displayName
            profile.bio = mateProfile.bio
            profile.instagramId = mateProfile.instagramId
            selectedLearningLevel = mateProfile.jlptLevel
        } else {
            let legacyProfile = profileStore.load()
            profile.nickname = legacyProfile.nickname
            profile.bio = legacyProfile.bio
            profile.instagramId = legacyProfile.instagramId
            profile.avatarData = legacyProfile.avatarData
            selectedLearningLevel = settingsStore.settings.homeDeckLevel
        }
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.8) ?? data
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
