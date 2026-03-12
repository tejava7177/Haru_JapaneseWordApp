import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published private var checkedWordIds: Set<Int> = []
    @Published var todayLyric: LyricEntry?
    @Published var lyricWordId: Int?
    @Published var hasError: Bool = false
    @Published var debugError: String?
    @Published private(set) var targetDateText: String = ""

    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore
    private let lyricRepository: LyricRepository
    private let buddyAPIService: BuddyAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: DictionaryRepository,
        settingsStore: AppSettingsStore,
        buddyAPIService: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.lyricRepository = LyricRepository()
        self.buddyAPIService = buddyAPIService

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .dailyWordsDidRegenerate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck()
            }
            .store(in: &cancellables)
    }

    func loadDeck() {
        Task {
            await loadDeckFromPrimarySource()
        }
    }

    private func loadDeckFromPrimarySource() async {
        hasError = false
        debugError = nil

        do {
            todayLyric = try lyricRepository.getTodayLyric()
            lyricWordId = nil

            if let currentUserId = settingsStore.currentBackendUserId {
                let response = try await buddyAPIService.fetchDailyWords(userId: currentUserId)
                let finalCards = try response.items
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map(makeWordSummary(from:))

                targetDateText = response.targetDate
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
            } else {
                let finalCards = try loadFallbackRecommendedWords()
                targetDateText = ""
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
                debugError = "DailyWord API userId unavailable. Falling back to local recommendations."
            }

            selectedIndex = 0
            checkedWordIds = try repository.fetchCheckedStates(wordIds: deckWordIds)

            if cards.isEmpty {
                hasError = true
            }
        } catch {
            do {
                let finalCards = try loadFallbackRecommendedWords()
                targetDateText = ""
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
                selectedIndex = 0
                checkedWordIds = try repository.fetchCheckedStates(wordIds: deckWordIds)
                debugError = "DailyWord API failed, fallback applied: \(error)"
                hasError = finalCards.isEmpty
            } catch {
                hasError = true
                debugError = String(describing: error)
                cards = []
                deckWordIds = []
                selectedIndex = 0
                targetDateText = ""
            }
        }
    }

    func isExcluded(_ wordId: Int) -> Bool {
        checkedWordIds.contains(wordId)
    }

    func toggleExcluded(wordId: Int) {
        let checked = isExcluded(wordId) == false
        do {
            try repository.setChecked(wordId: wordId, checked: checked)
            if checked {
                checkedWordIds.insert(wordId)
            } else {
                checkedWordIds.remove(wordId)
            }
        } catch {
            debugError = String(describing: error)
        }
    }

    private func makeWordSummary(from item: DailyWordsTodayItemResponse) throws -> WordSummary {
        if let summary = try repository.fetchWordSummary(wordId: item.wordId) {
            return summary
        }

        return WordSummary(
            id: item.wordId,
            level: JLPTLevel(rawValue: item.level) ?? .n5,
            expression: item.expression,
            reading: item.reading,
            meanings: ""
        )
    }

    private func loadFallbackRecommendedWords() throws -> [WordSummary] {
        let currentLevel = settingsStore.settings.homeDeckLevel
        return try repository.fetchRecommendedWords(level: currentLevel, limit: 10)
    }
}
