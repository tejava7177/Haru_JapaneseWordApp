import Foundation
import SwiftUI
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
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore
    private let lyricRepository: LyricRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: DictionaryRepository,
        settingsStore: AppSettingsStore
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
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
            todayLyric = try lyricRepository.getTodayLyric()

            var lyricWord: WordSummary?
            if let lyric = todayLyric, lyric.targetExpression.isEmpty == false {
                lyricWord = try repository.findByExpression(lyric.targetExpression)
            }

            let lyricWordIsChecked: Bool
            if let lyricWord {
                let checked = try repository.fetchCheckedStates(wordIds: [lyricWord.id])
                lyricWordIsChecked = checked.contains(lyricWord.id)
            } else {
                lyricWordIsChecked = false
            }
            let shouldUseLyricWord = lyricWord != nil && lyricWordIsChecked == false
            lyricWordId = shouldUseLyricWord ? lyricWord?.id : nil

            let currentLevel = settingsStore.settings.homeDeckLevel
            let needed = shouldUseLyricWord ? 9 : 10
            let fetchLimit = shouldUseLyricWord ? 10 : 9
            var recommended = try repository.fetchRecommendedWords(level: currentLevel, limit: fetchLimit)
            if let lyricWord {
                recommended.removeAll { $0.id == lyricWord.id }
            }
            let recommendedWords = Array(recommended.prefix(needed))

            var finalCards: [WordSummary] = []
            if let lyricWord, shouldUseLyricWord {
                finalCards.append(lyricWord)
            }
            finalCards.append(contentsOf: recommendedWords)

            cards = finalCards
            deckWordIds = finalCards.map { $0.id }
            selectedIndex = 0
            checkedWordIds = try repository.fetchCheckedStates(wordIds: deckWordIds)

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

    func sendPokePlaceholder(wordId: Int) {
        alertMessage = "준비 중입니다."
        isShowingAlert = true
    }

}
