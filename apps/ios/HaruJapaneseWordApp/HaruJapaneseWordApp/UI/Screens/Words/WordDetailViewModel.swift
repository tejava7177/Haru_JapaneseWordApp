import Foundation
import SwiftUI
import Combine

@MainActor
final class WordDetailViewModel: ObservableObject {
    @Published var detail: WordDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var recommendations: [(kanji: String, words: [WordSummary])] = []
    @Published var isReview: Bool = false

    private let repository: DictionaryRepository
    private let reviewStore = ReviewWordStore()
    private var currentWordId: Int?

    init(repository: DictionaryRepository) {
        self.repository = repository
    }

    func load(wordId: Int) {
        isLoading = true
        errorMessage = nil
        currentWordId = wordId

        do {
            detail = try repository.fetchWordDetail(wordId: wordId)
            if detail == nil {
                errorMessage = "단어 정보를 찾을 수 없습니다."
                recommendations = []
                isReview = false
            } else if let detail {
                isReview = reviewStore.loadReviewSet().contains(detail.id)
                recommendations = loadRecommendations(for: detail)
            }
        } catch {
            errorMessage = "단어 정보를 불러오지 못했습니다."
            recommendations = []
            isReview = false
        }

        isLoading = false
    }

    func toggleReview() {
        guard let wordId = currentWordId else { return }
        var reviewIds = reviewStore.loadReviewSet()
        if reviewIds.contains(wordId) {
            reviewIds.remove(wordId)
            isReview = false
        } else {
            reviewIds.insert(wordId)
            isReview = true
        }
        reviewStore.saveReviewSet(reviewIds)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    private func loadRecommendations(for detail: WordDetail) -> [(kanji: String, words: [WordSummary])] {
        let kanjiCharacters = extractKanjiCharacters(from: detail.expression)
        guard kanjiCharacters.isEmpty == false else { return [] }

        var results: [(kanji: String, words: [WordSummary])] = []
        for kanji in kanjiCharacters {
            do {
                let words = try repository.fetchRecommendedWords(
                    containing: kanji,
                    currentLevel: detail.level,
                    excluding: detail.id,
                    limit: 3
                )
                if words.isEmpty == false {
                    results.append((kanji: kanji, words: words))
                }
            } catch {
                print("❌ Failed to load recommendations for \(kanji): \(error)")
            }
        }
        return results
    }

    private func extractKanjiCharacters(from text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for scalar in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(Int(scalar.value)) {
                let kanji = String(scalar)
                if seen.insert(kanji).inserted {
                    result.append(kanji)
                }
            }
        }
        return result
    }
}
