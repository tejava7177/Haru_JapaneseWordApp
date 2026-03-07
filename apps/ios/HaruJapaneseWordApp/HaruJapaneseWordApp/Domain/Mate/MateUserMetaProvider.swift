import Foundation

protocol MateUserMetaProvider {
    func jlptLevel(for userId: String) -> JLPTLevel
}

struct DevMateUserMetaProvider: MateUserMetaProvider {
    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
    }

    func jlptLevel(for userId: String) -> JLPTLevel {
        settingsStore.profileLevel(for: userId)
    }
}
