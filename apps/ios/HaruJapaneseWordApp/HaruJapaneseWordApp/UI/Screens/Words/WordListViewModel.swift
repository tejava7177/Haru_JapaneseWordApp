import Foundation
import SwiftUI
import Combine

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var selectedLevel: JLPTLevel = .n5 {
        didSet {
            load()
        }
    }
    @Published var query: String = ""
    @Published var words: [WordSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: DictionaryRepository

    init(repository: DictionaryRepository) {
        self.repository = repository
    }

    func load() {
        fetchWords()
    }

    func search() {
        fetchWords()
    }

    private func fetchWords() {
        isLoading = true
        errorMessage = nil

        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                words = try repository.fetchWords(level: selectedLevel, limit: nil, offset: nil)
            } else {
                words = try repository.searchWords(level: selectedLevel, query: trimmedQuery, limit: nil, offset: nil)
            }
        } catch {
            errorMessage = "단어를 불러오지 못했습니다.\n\(String(describing: error))"
            words = []
        }

        isLoading = false
    }
}
