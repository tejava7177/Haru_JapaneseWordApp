import Foundation
import SwiftUI
import Combine

@MainActor
final class WordDetailViewModel: ObservableObject {
    @Published var detail: WordDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let wordId: Int
    private let repository: DictionaryRepository

    init(wordId: Int, repository: DictionaryRepository) {
        self.wordId = wordId
        self.repository = repository
    }

    func load() {
        isLoading = true
        errorMessage = nil

        do {
            detail = try repository.fetchWordDetail(wordId: wordId)
            if detail == nil {
                errorMessage = "단어 정보를 찾을 수 없습니다."
            }
        } catch {
            errorMessage = "단어 정보를 불러오지 못했습니다."
        }

        isLoading = false
    }
}
