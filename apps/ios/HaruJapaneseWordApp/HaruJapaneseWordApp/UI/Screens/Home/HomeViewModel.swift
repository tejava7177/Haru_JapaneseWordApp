import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published private var excludedWordIds: Set<Int> = []
    @Published var errorMessage: String?
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    private let repository: DictionaryRepository
    private let homeDeckStore: HomeDeckStore
    private let settingsStore: AppSettingsStore
    private let learnedStore: LearnedWordStore
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: DictionaryRepository,
        homeDeckStore: HomeDeckStore = HomeDeckStore(),
        settingsStore: AppSettingsStore
    ) {
        self.repository = repository
        self.homeDeckStore = homeDeckStore
        self.settingsStore = settingsStore
        self.learnedStore = LearnedWordStore()

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
        refreshExcludedSet(now: today)
        let ids = homeDeckStore.getOrCreateDeck(
            date: today,
            repository: repository,
            excluding: excludedWordIds,
            level: settings.homeDeckLevel,
            count: 10
        )
        deckWordIds = ids
        selectedIndex = 0
        cards = loadCards(from: ids)

        if cards.isEmpty {
            errorMessage = "오늘의 추천을 불러오지 못했습니다."
        }
    }

    func isExcluded(_ wordId: Int) -> Bool {
        excludedWordIds.contains(wordId)
    }

    func toggleExcluded(wordId: Int) {
        let now = Date()
        if isExcluded(wordId) {
            learnedStore.unmarkLearned(wordId: wordId)
        } else {
            learnedStore.markLearned(wordId: wordId, date: now)
        }
        refreshExcludedSet(now: now)
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

    private func refreshExcludedSet(now: Date) {
        excludedWordIds = learnedStore.loadExcludedSet(today: now, excludeDays: 30)
    }
}
