import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published private var excludedWordIds: Set<Int> = []
    @Published var todayLyric: LyricEntry?
    @Published var lyricWordId: Int?
    @Published var hasError: Bool = false
    @Published var debugError: String?
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore
    private let learnedStore: LearnedWordStore
    private let lyricRepository: LyricRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: DictionaryRepository,
        settingsStore: AppSettingsStore
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.learnedStore = LearnedWordStore()
        self.lyricRepository = LyricRepository()

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck()
            }
            .store(in: &cancellables)
    }

    func loadDeck() {
        hasError = false
        debugError = nil

        do {
            let today = Date()
            refreshExcludedSet(now: today)
            todayLyric = try lyricRepository.getTodayLyric()

            var lyricWord: WordSummary?
            if let lyric = todayLyric, lyric.targetExpression.isEmpty == false {
                lyricWord = try repository.findByExpression(lyric.targetExpression)
            }

            let lyricWordIsExcluded = lyricWord.map { excludedWordIds.contains($0.id) } ?? false
            let shouldUseLyricWord = lyricWord != nil && lyricWordIsExcluded == false
            lyricWordId = shouldUseLyricWord ? lyricWord?.id : nil

            let excludingExpression = shouldUseLyricWord ? lyricWord?.expression : nil
            let needed = shouldUseLyricWord ? 9 : 10
            let randomWords = try collectRandomWords(
                needed: needed,
                excludingExpression: excludingExpression,
                excludedIds: excludedWordIds
            )

            var finalCards: [WordSummary] = []
            if let lyricWord, shouldUseLyricWord {
                finalCards.append(lyricWord)
            }
            finalCards.append(contentsOf: randomWords)

            cards = finalCards
            deckWordIds = finalCards.map { $0.id }
            selectedIndex = 0

            if cards.isEmpty {
                hasError = true
            }
        } catch {
            hasError = true
            debugError = String(describing: error)
            cards = []
            deckWordIds = []
            selectedIndex = 0
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

    private func refreshExcludedSet(now: Date) {
        excludedWordIds = learnedStore.loadExcludedSet(today: now, excludeDays: 30)
    }

    private func collectRandomWords(
        needed: Int,
        excludingExpression: String?,
        excludedIds: Set<Int>
    ) throws -> [WordSummary] {
        guard needed > 0 else { return [] }

        var results: [WordSummary] = []
        var seenIds: Set<Int> = []

        for _ in 0..<3 {
            if results.count >= needed { break }
            let pool = try repository.getRandomWords(limit: 30, excludingExpression: excludingExpression)
            for word in pool where results.count < needed {
                guard excludedIds.contains(word.id) == false else { continue }
                guard seenIds.contains(word.id) == false else { continue }
                results.append(word)
                seenIds.insert(word.id)
            }
        }

        return results
    }
}
