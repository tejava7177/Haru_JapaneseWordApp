import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    private static let selectedLevelsKey = "WordFilter.selectedLevels"
    private static let reviewOnlyKey = "WordFilter.reviewOnly"
    private static let showJLPTWordsKey = "WordFilter.showJLPTWords"
    private static let showNotebookWordsKey = "WordFilter.showNotebookWords"
    private static let selectedNotebookIdsKey = "WordFilter.selectedNotebookIds"
    private static let shuffledWordIdsKey = "WordList.shuffledWordIds"
    private static let preferencesKey = "wordListPreferences"

    enum WordSortMode: String, Codable {
        case alphabetical
        case shuffled
    }

    struct WordListPreferences: Codable {
        var sortMode: WordSortMode = .alphabetical
        var shuffleLocked: Bool = false
    }

    enum RefreshAction {
        case shuffled
        case sortedAlphabetically
    }

    @Published var searchText: String = ""
    @Published var selectedLevels: Set<JLPTLevel> = []
    @Published var reviewOnly: Bool = false
    @Published var showJLPTWords: Bool = true
    @Published var showNotebookWords: Bool = false
    @Published var selectedNotebookIds: Set<UUID> = []
    @Published var preferences: WordListPreferences = WordListPreferences()
    @Published private(set) var displayedWords: [WordListItem] = []
    @Published private(set) var availableLevels: [JLPTLevel] = []
    @Published private(set) var reviewWordIds: Set<Int> = []
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var debugError: String?
    @Published var isShuffling: Bool = false

    private let repository: DictionaryRepository
    private let reviewStore = ReviewWordStore()
    private var baseJLPTWords: [WordSummary] = []
    private var notebooks: [WordNotebook] = []
    private var shuffledWordIds: [String] = []

    init(repository: DictionaryRepository) {
        self.repository = repository
        self.selectedLevels = Self.loadSelectedLevels()
        self.reviewOnly = Self.loadReviewOnly()
        self.showJLPTWords = Self.loadShowJLPTWords()
        self.showNotebookWords = Self.loadShowNotebookWords()
        self.selectedNotebookIds = Self.loadSelectedNotebookIds()
        self.shuffledWordIds = Self.loadShuffledWordIds()
        self.preferences = Self.loadPreferences()
        self.reviewWordIds = reviewStore.loadReviewSet()
    }

    func load() {
        fetchWords()
    }

    func search() {
        fetchWords()
    }

    func pullToRefresh() async -> RefreshAction {
        if isShuffling {
            return preferences.sortMode == .shuffled ? .shuffled : .sortedAlphabetically
        }
        let action = handlePullToRefresh()
        isShuffling = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isShuffling = false
        return action
    }

    func toggleReviewOnly() {
        reviewOnly.toggle()
        persistReviewOnly()
        applyFiltersAndOrder()
    }

    func setShowJLPTWords(_ isOn: Bool) {
        showJLPTWords = isOn
        persistShowJLPTWords()
        applyFiltersAndOrder()
    }

    func setShowNotebookWords(_ isOn: Bool) {
        showNotebookWords = isOn
        persistShowNotebookWords()
        applyFiltersAndOrder()
    }

    func toggleNotebookSelection(_ notebookId: UUID) {
        if selectedNotebookIds.contains(notebookId) {
            selectedNotebookIds.remove(notebookId)
        } else {
            selectedNotebookIds.insert(notebookId)
        }
        persistSelectedNotebookIds()
        applyFiltersAndOrder()
    }

    func isNotebookSelected(_ notebookId: UUID) -> Bool {
        selectedNotebookIds.contains(notebookId)
    }

    func setShuffleLocked(_ isLocked: Bool) {
        preferences.shuffleLocked = isLocked
        persistPreferences()
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

    func isReviewWord(_ word: WordListItem) -> Bool {
        guard let wordId = word.jlptWordId else { return false }
        return isReviewWord(wordId)
    }

    func toggleReview(_ wordId: Int) {
        if isReviewWord(wordId) {
            removeFromReview(wordId)
        } else {
            addToReview(wordId)
        }
    }

    func refreshReviewState() {
        reviewWordIds = reviewStore.loadReviewSet()
        applyFiltersAndOrder()
    }

    func updateNotebooks(_ notebooks: [WordNotebook]) {
        self.notebooks = notebooks
        let validIds = Set(notebooks.map(\.id))
        let filteredIds = Set(selectedNotebookIds.filter { validIds.contains($0) })
        if filteredIds != selectedNotebookIds {
            selectedNotebookIds = filteredIds
            persistSelectedNotebookIds()
        }
        applyFiltersAndOrder()
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
        hasError = false
        debugError = nil

        do {
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                baseJLPTWords = try repository.fetchWords(level: nil, limit: nil, offset: nil)
            } else {
                baseJLPTWords = try repository.searchWords(level: nil, query: trimmedQuery, limit: nil, offset: nil)
            }
            updateAvailableLevels(from: baseJLPTWords)
            applyFiltersAndOrder()
        } catch {
            hasError = true
            debugError = String(describing: error)
            baseJLPTWords = []
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
        displayedWords = applySort(to: filteredWords())
    }

    private func filteredWords() -> [WordListItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let levelSet = selectedLevels.isEmpty ? Set(availableLevels) : selectedLevels
        var filtered: [WordListItem] = []

        if showJLPTWords {
            var jlptWords = baseJLPTWords
            if levelSet.isEmpty == false {
                jlptWords = jlptWords.filter { levelSet.contains($0.level) }
            }
            if reviewOnly {
                jlptWords = jlptWords.filter { reviewWordIds.contains($0.id) }
            }
            filtered.append(contentsOf: jlptWords.map(WordListItem.init(wordSummary:)))
        }

        if showNotebookWords {
            let notebookWords = notebooks
                .filter { selectedNotebookIds.contains($0.id) }
                .flatMap { notebook in
                    notebook.items.map { WordListItem(notebookId: notebook.id, item: $0) }
                }
                .filter { item in
                    matchesNotebookWord(item, query: trimmedQuery)
                }
            filtered.append(contentsOf: notebookWords)
        }

        return filtered
    }

    private func matchesNotebookWord(_ item: WordListItem, query: String) -> Bool {
        guard query.isEmpty == false else { return true }
        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let targets = [item.word, item.reading ?? "", item.meaning]
        return targets.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .localizedStandardContains(normalizedQuery)
        }
    }

    private func applySort(to words: [WordListItem]) -> [WordListItem] {
        switch preferences.sortMode {
        case .alphabetical:
            return words
        case .shuffled:
            return applyShuffleIfNeeded(to: words)
        }
    }

    private func applyShuffleIfNeeded(to words: [WordListItem]) -> [WordListItem] {
        if shuffledWordIds.isEmpty {
            shuffledWordIds = words.map { $0.id }
            shuffledWordIds.shuffle()
            persistShuffledWordIds()
        }

        let wordById = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        var ordered: [WordListItem] = []
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
        let filtered = filteredWords()
        shuffledWordIds = filtered.map { $0.id }
        shuffledWordIds.shuffle()
        persistShuffledWordIds()
        displayedWords = applyShuffleIfNeeded(to: filtered)
    }

    @discardableResult
    private func handlePullToRefresh() -> RefreshAction {
        if preferences.shuffleLocked {
            preferences.sortMode = .shuffled
            shuffleCurrentWords()
            persistPreferences()
            return .shuffled
        } else {
            switch preferences.sortMode {
            case .alphabetical:
                preferences.sortMode = .shuffled
                shuffleCurrentWords()
                persistPreferences()
                return .shuffled
            case .shuffled:
                preferences.sortMode = .alphabetical
                applyFiltersAndOrder()
                persistPreferences()
                return .sortedAlphabetically
            }
        }
    }

    private func persistSelectedLevels() {
        let raw = selectedLevels.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: Self.selectedLevelsKey)
    }

    private func persistReviewOnly() {
        UserDefaults.standard.set(reviewOnly, forKey: Self.reviewOnlyKey)
    }

    private func persistShowJLPTWords() {
        UserDefaults.standard.set(showJLPTWords, forKey: Self.showJLPTWordsKey)
    }

    private func persistShowNotebookWords() {
        UserDefaults.standard.set(showNotebookWords, forKey: Self.showNotebookWordsKey)
    }

    private func persistSelectedNotebookIds() {
        UserDefaults.standard.set(selectedNotebookIds.map(\.uuidString), forKey: Self.selectedNotebookIdsKey)
    }

    private func persistShuffledWordIds() {
        UserDefaults.standard.set(shuffledWordIds, forKey: Self.shuffledWordIdsKey)
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
    }

    private static func loadSelectedLevels() -> Set<JLPTLevel> {
        let raw = UserDefaults.standard.stringArray(forKey: selectedLevelsKey) ?? []
        return Set(raw.compactMap { JLPTLevel(rawValue: $0) })
    }

    private static func loadReviewOnly() -> Bool {
        UserDefaults.standard.bool(forKey: reviewOnlyKey)
    }

    private static func loadShowJLPTWords() -> Bool {
        if UserDefaults.standard.object(forKey: showJLPTWordsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: showJLPTWordsKey)
    }

    private static func loadShowNotebookWords() -> Bool {
        UserDefaults.standard.bool(forKey: showNotebookWordsKey)
    }

    private static func loadSelectedNotebookIds() -> Set<UUID> {
        let rawIds = UserDefaults.standard.stringArray(forKey: selectedNotebookIdsKey) ?? []
        return Set(rawIds.compactMap(UUID.init(uuidString:)))
    }

    private static func loadShuffledWordIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: shuffledWordIdsKey) ?? []
    }

    private static func loadPreferences() -> WordListPreferences {
        guard
            let data = UserDefaults.standard.data(forKey: preferencesKey),
            let prefs = try? JSONDecoder().decode(WordListPreferences.self, from: data)
        else {
            return WordListPreferences()
        }
        return prefs
    }
}
