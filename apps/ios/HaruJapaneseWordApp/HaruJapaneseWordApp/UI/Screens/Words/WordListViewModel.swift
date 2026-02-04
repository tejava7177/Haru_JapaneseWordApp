import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedRange: JLPTLevelRange = .all {
        didSet {
            applyRangeFilter()
        }
    }
    @Published private(set) var displayedWords: [WordSummary] = []
    @Published private(set) var availableRanges: [JLPTLevelRange] = [.all]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: DictionaryRepository
    private var baseWords: [WordSummary] = []

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
            updateAvailableRanges(from: baseWords)
            applyRangeFilter()
        } catch {
            errorMessage = "단어를 불러오지 못했습니다.\n\(String(describing: error))"
            baseWords = []
            displayedWords = []
        }

        isLoading = false
    }

    private func applyRangeFilter() {
        displayedWords = baseWords.filter { selectedRange.contains($0.level) }
    }

    private func updateAvailableRanges(from words: [WordSummary]) {
        let levels = Set(words.map { $0.level })
        let ranges = JLPTLevelRange.availableRanges(availableLevels: levels)
        availableRanges = ranges
        if ranges.contains(selectedRange) == false {
            selectedRange = .all
        }
    }
}
