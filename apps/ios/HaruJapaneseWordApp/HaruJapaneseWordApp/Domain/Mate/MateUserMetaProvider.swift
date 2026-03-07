import Foundation

protocol MateUserMetaProvider {
    func displayName(for userId: String) -> String
    func jlptLevel(for userId: String) -> JLPTLevel
}

struct DevMateUserMetaProvider: MateUserMetaProvider {
    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
    }

    func displayName(for userId: String) -> String {
        settingsStore.profile(for: userId).displayName
    }

    func jlptLevel(for userId: String) -> JLPTLevel {
        settingsStore.profileLevel(for: userId)
    }
}
