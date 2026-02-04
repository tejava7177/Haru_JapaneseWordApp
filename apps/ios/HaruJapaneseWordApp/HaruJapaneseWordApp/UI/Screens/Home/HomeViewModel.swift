import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published var learnedWordIds: Set<Int> = []
    @Published var remainingRerolls: Int = 0
    @Published var errorMessage: String?
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    private let repository: DictionaryRepository
    private let homeDeckStore: HomeDeckStore
    private let learnedStore: LearnedWordStore
    private let excludeDays: Int = 14

    init(
        repository: DictionaryRepository,
        homeDeckStore: HomeDeckStore = HomeDeckStore(),
        learnedStore: LearnedWordStore = LearnedWordStore()
    ) {
        self.repository = repository
        self.homeDeckStore = homeDeckStore
        self.learnedStore = learnedStore
    }

    func loadDeck() {
        errorMessage = nil
        let today = Date()
        let excluded = learnedStore.loadExcludedSet(today: today, excludeDays: excludeDays)
        let ids = homeDeckStore.getOrCreateDeck(
            date: today,
            repository: repository,
            excluding: excluded
        )
        deckWordIds = ids
        selectedIndex = 0
        remainingRerolls = homeDeckStore.remainingRerolls(date: today)
        learnedWordIds = learnedStore.loadLearnedSet(today: today)
        cards = loadCards(from: ids)

        if cards.isEmpty {
            errorMessage = "오늘의 추천을 불러오지 못했습니다."
        }
    }

    func toggleLearned(wordId: Int) {
        let today = Date()
        if learnedStore.isLearned(wordId: wordId, today: today) {
            learnedStore.unmarkLearned(wordId: wordId)
            learnedWordIds.remove(wordId)
        } else {
            learnedStore.markLearned(wordId: wordId, date: today)
            learnedWordIds.insert(wordId)
        }
    }

    func rerollDeck() {
        let today = Date()
        let remaining = homeDeckStore.remainingRerolls(date: today)
        if remaining <= 0 {
            remainingRerolls = 0
            return
        }

        let excluded = learnedStore.loadExcludedSet(today: today, excludeDays: excludeDays)
        let ids = homeDeckStore.rerollDeck(
            date: today,
            repository: repository,
            excluding: excluded
        )
        deckWordIds = ids
        selectedIndex = 0
        remainingRerolls = homeDeckStore.remainingRerolls(date: today)
        cards = loadCards(from: ids)

        if cards.isEmpty {
            errorMessage = "덱을 새로고침하지 못했습니다."
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
