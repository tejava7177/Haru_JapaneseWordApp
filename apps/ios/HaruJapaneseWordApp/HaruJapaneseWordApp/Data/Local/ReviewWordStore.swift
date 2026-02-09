import Foundation

struct ReviewWordStore {
    private let userDefaults: UserDefaults
    private let reviewWordsKey = "review_words"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadReviewSet() -> Set<Int> {
        let ids = userDefaults.array(forKey: reviewWordsKey) as? [Int] ?? []
        return Set(ids)
    }

    func saveReviewSet(_ ids: Set<Int>) {
        userDefaults.set(Array(ids), forKey: reviewWordsKey)
    }
}
