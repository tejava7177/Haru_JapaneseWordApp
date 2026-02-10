import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedLevels: Set<JLPTLevel> = Set(JLPTLevel.allCases)
    @Published private(set) var displayedWords: [WordSummary] = []
    @Published private(set) var availableLevels: [JLPTLevel] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingPage: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    @Published var isShuffling: Bool = false

    private let repository: DictionaryRepository
    private let pageSize: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true
    private var loadedWordIds: Set<Int> = []

    init(repository: DictionaryRepository) {
        self.repository = repository
        let sortedLevels = JLPTLevel.allCases.sorted { $0.rank > $1.rank }
        self.availableLevels = sortedLevels
        self.selectedLevels = Set(sortedLevels)
    }

    var isAllOn: Bool {
        let availableSet = Set(availableLevels)
        return availableSet.isEmpty == false && selectedLevels == availableSet
    }

    func load() {
        Task {
            await loadFirstPage()
        }
    }

    func search() {
        Task {
            await resetAndLoadFirstPage()
        }
    }

    func shuffleDisplayedWords() {
        displayedWords.shuffle()
    }

    func setAllLevels(_ isOn: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isOn {
                selectedLevels = Set(availableLevels)
            } else {
                if let fallback = availableLevels.last {
                    selectedLevels = [fallback]
                }
            }
        }
        Task {
            await resetAndLoadFirstPage()
        }
    }

    func toggleLevel(_ level: JLPTLevel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedLevels.contains(level) {
                if selectedLevels.count == 1 {
                    return
                }
                selectedLevels.remove(level)
            } else {
                selectedLevels.insert(level)
            }
        }
        Task {
            await resetAndLoadFirstPage()
        }
    }

    func refresh() async {
        if isRefreshing {
            return
        }
        isRefreshing = true
        isShuffling = true
        await resetAndLoadFirstPage()
        shuffleDisplayedWords()
        // TODO: Consider server-side random sampling for true shuffle across all words.
        try? await Task.sleep(nanoseconds: 250_000_000)
        isShuffling = false
        isRefreshing = false
    }

    func loadFirstPage() async {
        await resetAndLoadFirstPage()
    }

    func loadNextPageIfNeeded(currentItem: WordSummary) async {
        guard hasMore, !isLoadingPage, displayedWords.isEmpty == false else {
            return
        }
        let thresholdIndex = max(displayedWords.count - 10, 0)
        if currentItem.id == displayedWords[thresholdIndex].id {
            await loadNextPage()
        }
    }

    func loadNextPage() async {
        await loadPage(reset: false)
    }

    private func resetAndLoadFirstPage() async {
        offset = 0
        hasMore = true
        loadedWordIds = []
        displayedWords = []
        await loadPage(reset: true)
    }

    private func loadPage(reset: Bool) async {
        guard isLoadingPage == false else {
            return
        }

        isLoadingPage = true
        if reset {
            isLoading = true
            errorMessage = nil
        }

        let levels = selectedLevels
        if levels.isEmpty {
            displayedWords = []
            hasMore = false
            isLoadingPage = false
            isLoading = false
            return
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmedQuery.isEmpty ? nil : trimmedQuery

        do {
            let fetched = try await repository.fetchWordsPaged(
                levels: levels,
                query: query,
                limit: pageSize,
                offset: offset
            )
            let unique = fetched.filter { loadedWordIds.insert($0.id).inserted }
            if reset {
                displayedWords = unique
            } else {
                displayedWords.append(contentsOf: unique)
            }
            if fetched.count < pageSize {
                hasMore = false
            }
            offset += fetched.count
        } catch {
            errorMessage = "단어를 불러오지 못했습니다.\n\(String(describing: error))"
            if reset {
                displayedWords = []
            }
        }

        isLoadingPage = false
        isLoading = false
    }
}
