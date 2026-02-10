import Foundation
import PhotosUI
import SwiftUI
import Combine
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var settings: AppSettings
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
        self.profile = profileStore.load()
        self.settings = settingsStore.settings

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.settings = value
            }
            .store(in: &cancellables)
    }

    func updateNickname(_ nickname: String) {
        profile.nickname = nickname
        profileStore.updateNickname(nickname)
    }

    func updateBio(_ bio: String) {
        profile.bio = bio
        profileStore.updateBio(bio)
    }

    func updateInstagram(_ instagramId: String) {
        profile.instagramId = instagramId
        profileStore.updateInstagram(instagramId)
    }

    func updateHomeDeckLevel(_ level: JLPTLevel) {
        settings.homeDeckLevel = level
        settingsStore.updateHomeDeckLevel(level)
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

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        return image.jpegData(compressionQuality: 0.8) ?? data
    }
}
