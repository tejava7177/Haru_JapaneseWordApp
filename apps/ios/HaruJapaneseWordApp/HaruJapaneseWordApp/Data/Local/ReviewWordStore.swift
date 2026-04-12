import Foundation
import Combine

@MainActor
final class ReviewWordStore: ObservableObject {
    static let shared = ReviewWordStore()

    @Published private(set) var reviewWordIds: Set<Int>

    private let userDefaults: UserDefaults
    private let reviewWordsKey = "review_words"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let ids = userDefaults.array(forKey: reviewWordsKey) as? [Int] ?? []
        self.reviewWordIds = Set(ids)
    }

    func loadReviewSet() -> Set<Int> {
        let ids = userDefaults.array(forKey: reviewWordsKey) as? [Int] ?? []
        let loaded = Set(ids)
        if loaded != reviewWordIds {
            reviewWordIds = loaded
        }
        return loaded
    }

    func contains(_ wordId: Int) -> Bool {
        reviewWordIds.contains(wordId)
    }

    func add(_ wordId: Int) {
        print("[ReviewWordStore] actual store save/remove called action=add wordId=\(wordId)")
        var nextIds = loadReviewSet()
        nextIds.insert(wordId)
        saveReviewSet(nextIds)
    }

    func remove(_ wordId: Int) {
        print("[ReviewWordStore] actual store save/remove called action=remove wordId=\(wordId)")
        var nextIds = loadReviewSet()
        nextIds.remove(wordId)
        saveReviewSet(nextIds)
    }

    func toggle(_ wordId: Int) {
        if contains(wordId) {
            remove(wordId)
        } else {
            add(wordId)
        }
    }

    func saveReviewSet(_ ids: Set<Int>) {
        reviewWordIds = ids
        userDefaults.set(Array(ids), forKey: reviewWordsKey)
    }
}
