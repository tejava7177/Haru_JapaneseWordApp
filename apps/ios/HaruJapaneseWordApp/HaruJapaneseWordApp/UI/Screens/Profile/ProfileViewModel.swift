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

    private let profileStore: UserProfileStore
    private let settingsStore: AppSettingsStore
    private let homeDeckStore: HomeDeckStore
    private let learnedStore: LearnedWordStore
    private var cancellables: Set<AnyCancellable> = []

    init(
        settingsStore: AppSettingsStore,
        profileStore: UserProfileStore = UserProfileStore(),
        homeDeckStore: HomeDeckStore = HomeDeckStore(),
        learnedStore: LearnedWordStore = LearnedWordStore()
    ) {
        self.profileStore = profileStore
        self.settingsStore = settingsStore
        self.homeDeckStore = homeDeckStore
        self.learnedStore = learnedStore

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
        selectedLearningLevel = level
        if settingsStore.isMateLoggedIn {
            settingsStore.updateCurrentMateJLPTLevel(level)
        } else {
            settingsStore.updateHomeDeckLevel(level)
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

    func resetLearningData() {
        learnedStore.resetLearnedData()
        homeDeckStore.resetDeckData()
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
}
