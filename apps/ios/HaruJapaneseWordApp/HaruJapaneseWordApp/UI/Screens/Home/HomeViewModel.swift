import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published var errorMessage: String?
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    private let repository: DictionaryRepository
    private let homeDeckStore: HomeDeckStore
    private let settingsStore: AppSettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: DictionaryRepository,
        homeDeckStore: HomeDeckStore = HomeDeckStore(),
        settingsStore: AppSettingsStore
    ) {
        self.repository = repository
        self.homeDeckStore = homeDeckStore
        self.settingsStore = settingsStore

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck()
            }
            .store(in: &cancellables)
    }

    func loadDeck() {
        errorMessage = nil
        let today = Date()
        let settings = settingsStore.settings
        let ids = homeDeckStore.getOrCreateDeck(
            date: today,
            repository: repository,
            excluding: [],
            level: settings.homeDeckLevel
        )
        deckWordIds = ids
        selectedIndex = 0
        cards = loadCards(from: ids)

        if cards.isEmpty {
            errorMessage = "오늘의 추천을 불러오지 못했습니다."
        }
    }

    func sendPokePlaceholder(wordId: Int) {
        alertMessage = "준비 중입니다."
        isShowingAlert = true
    }

    private func loadCards(from ids: [Int]) -> [WordSummary] {
        var summaries: [WordSummary] = []
        for id in ids {
            do {
                if let summary = try repository.fetchWordSummary(wordId: id) {
                    summaries.append(summary)
                }
            } catch {
                errorMessage = "단어 정보를 불러오지 못했습니다."
            }
        }
        return summaries
    }
}
