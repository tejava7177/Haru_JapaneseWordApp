import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    private static let selectedLevelsKey = "WordFilter.selectedLevels"
    private static let reviewOnlyKey = "WordFilter.reviewOnly"
    private static let shuffledWordIdsKey = "WordList.shuffledWordIds"

    @Published var searchText: String = ""
    @Published var selectedLevels: Set<JLPTLevel> = []
    @Published var reviewOnly: Bool = false
    @Published private(set) var displayedWords: [WordSummary] = []
    @Published private(set) var availableLevels: [JLPTLevel] = []
    @Published private(set) var reviewWordIds: Set<Int> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isShuffling: Bool = false

    private let repository: DictionaryRepository
    private let reviewStore = ReviewWordStore()
    private var baseWords: [WordSummary] = []
    private var shuffledWordIds: [Int] = []

    init(repository: DictionaryRepository) {
        self.repository = repository
        self.selectedLevels = Self.loadSelectedLevels()
        self.reviewOnly = Self.loadReviewOnly()
        self.shuffledWordIds = Self.loadShuffledWordIds()
        self.reviewWordIds = reviewStore.loadReviewSet()
    }

    func load() {
        fetchWords()
    }

    func search() {
        fetchWords()
    }

    func shuffleByPull() async {
        if isShuffling {
            return
        }
        isShuffling = true
        try? await Task.sleep(nanoseconds: 200_000_000)
        shuffleCurrentWords()
        try? await Task.sleep(nanoseconds: 500_000_000)
        isShuffling = false
    }

    func toggleReviewOnly() {
        reviewOnly.toggle()
        persistReviewOnly()
        applyFiltersAndOrder()
    }

    func toggleLevel(_ level: JLPTLevel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedLevels.contains(level) {
                selectedLevels.remove(level)
            } else {
                selectedLevels.insert(level)
            }
        }
        persistSelectedLevels()
        applyFiltersAndOrder()
    }

    func isReviewWord(_ wordId: Int) -> Bool {
        reviewWordIds.contains(wordId)
    }

    func toggleReview(_ wordId: Int) {
        if isReviewWord(wordId) {
            removeFromReview(wordId)
        } else {
            addToReview(wordId)
        }
    }

    private func addToReview(_ wordId: Int) {
        reviewWordIds.insert(wordId)
        reviewStore.saveReviewSet(reviewWordIds)
        if reviewOnly {
            applyFiltersAndOrder()
        }
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    private func removeFromReview(_ wordId: Int) {
        reviewWordIds.remove(wordId)
        reviewStore.saveReviewSet(reviewWordIds)
        if reviewOnly {
            applyFiltersAndOrder()
        }
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
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
            applyFiltersAndOrder()
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

    }

    private func applyFiltersAndOrder() {
        let levelSet = selectedLevels.isEmpty ? Set(availableLevels) : selectedLevels
        var filtered = baseWords
        if levelSet.isEmpty == false {
            filtered = filtered.filter { levelSet.contains($0.level) }
        }
        if reviewOnly {
            filtered = filtered.filter { reviewWordIds.contains($0.id) }
        }
        displayedWords = applyShuffleIfNeeded(to: filtered)
    }

    private func applyShuffleIfNeeded(to words: [WordSummary]) -> [WordSummary] {
        guard shuffledWordIds.isEmpty == false else {
            return words
        }
        let wordById = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        var ordered: [WordSummary] = []
        ordered.reserveCapacity(words.count)
        for id in shuffledWordIds {
            if let word = wordById[id] {
                ordered.append(word)
            }
        }
        var seen = Set(shuffledWordIds)
        var didAppend = false
        for word in words where seen.contains(word.id) == false {
            ordered.append(word)
            shuffledWordIds.append(word.id)
            seen.insert(word.id)
            didAppend = true
        }
        if didAppend {
            persistShuffledWordIds()
        }
        return ordered
    }

    private func shuffleCurrentWords() {
        let levelSet = selectedLevels.isEmpty ? Set(availableLevels) : selectedLevels
        var filtered = baseWords
        if levelSet.isEmpty == false {
            filtered = filtered.filter { levelSet.contains($0.level) }
        }
        if reviewOnly {
            filtered = filtered.filter { reviewWordIds.contains($0.id) }
        }
        shuffledWordIds = filtered.map { $0.id }
        shuffledWordIds.shuffle()
        persistShuffledWordIds()
        displayedWords = applyShuffleIfNeeded(to: filtered)
    }

    private func persistSelectedLevels() {
        let raw = selectedLevels.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: Self.selectedLevelsKey)
    }

    private func persistReviewOnly() {
        UserDefaults.standard.set(reviewOnly, forKey: Self.reviewOnlyKey)
    }

    private func persistShuffledWordIds() {
        UserDefaults.standard.set(shuffledWordIds, forKey: Self.shuffledWordIdsKey)
    }

    private static func loadSelectedLevels() -> Set<JLPTLevel> {
        let raw = UserDefaults.standard.stringArray(forKey: selectedLevelsKey) ?? []
        return Set(raw.compactMap { JLPTLevel(rawValue: $0) })
    }

    private static func loadReviewOnly() -> Bool {
        UserDefaults.standard.bool(forKey: reviewOnlyKey)
    }

    private static func loadShuffledWordIds() -> [Int] {
        UserDefaults.standard.array(forKey: shuffledWordIdsKey) as? [Int] ?? []
    }
}
