import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var enabledLevels: Set<JLPTLevel> = []
    @Published var isAllEnabled: Bool = true
    @Published private(set) var displayedWords: [WordSummary] = []
    @Published private(set) var availableLevels: [JLPTLevel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isShuffling: Bool = false

    private let repository: DictionaryRepository
    private var baseWords: [WordSummary] = []
    private var userDisabledLevels: Set<JLPTLevel> = []

    init(repository: DictionaryRepository) {
        self.repository = repository
    }

    func load() {
        fetchWords()
    }

    func search() {
        fetchWords()
    }

    func shuffleDisplayedWords() {
        displayedWords.shuffle()
    }

    func shuffleByPull() async {
        if isShuffling {
            return
        }
        isShuffling = true
        try? await Task.sleep(nanoseconds: 200_000_000)
        displayedWords.shuffle()
        try? await Task.sleep(nanoseconds: 500_000_000)
        isShuffling = false
    }

    func toggleAllLevels(_ isOn: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isAllEnabled = isOn
            if isOn {
                enabledLevels = Set(availableLevels)
                userDisabledLevels = []
            } else {
                enabledLevels = []
                userDisabledLevels = []
            }
            applyLevelFilter()
        }
    }

    func toggleLevel(_ level: JLPTLevel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if enabledLevels.contains(level) {
                enabledLevels.remove(level)
                userDisabledLevels.insert(level)
            } else {
                enabledLevels.insert(level)
                userDisabledLevels.remove(level)
            }
            applyAutoRange()
            applyLevelFilter()
        }
    }

    private func applyAutoRange() {
        let ranks = enabledLevels.map { $0.rank }
        guard let minRank = ranks.min(), let maxRank = ranks.max() else {
            isAllEnabled = false
            return
        }
        let rangeLevels = availableLevels.filter { level in
            level.rank >= minRank && level.rank <= maxRank
        }
        for level in rangeLevels where userDisabledLevels.contains(level) == false {
            enabledLevels.insert(level)
        }
        isAllEnabled = enabledLevels.count == availableLevels.count && availableLevels.isEmpty == false
    }

    private func applyLevelFilter() {
        if enabledLevels.isEmpty {
            displayedWords = []
            return
        }
        displayedWords = baseWords.filter { enabledLevels.contains($0.level) }
    }

    private func fetchWords() {
        isLoading = true
        errorMessage = nil

        do {
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                baseWords = try repository.fetchWords(level: nil, limit: nil, offset: nil)
            } else {
                baseWords = try repository.searchWords(level: nil, query: trimmedQuery, limit: nil, offset: nil)
            }
            updateAvailableLevels(from: baseWords)
            applyLevelFilter()
        } catch {
            errorMessage = "단어를 불러오지 못했습니다.\n\(String(describing: error))"
            baseWords = []
            displayedWords = []
        }

        isLoading = false
    }

    private func updateAvailableLevels(from words: [WordSummary]) {
        let levels = Set(words.map { $0.level })
        let sorted = levels.sorted { $0.rank > $1.rank }
        availableLevels = sorted

        if isAllEnabled {
            enabledLevels = Set(sorted)
            userDisabledLevels = []
        } else {
            enabledLevels = enabledLevels.intersection(levels)
            userDisabledLevels = userDisabledLevels.intersection(levels)
            applyAutoRange()
        }
    }
}
