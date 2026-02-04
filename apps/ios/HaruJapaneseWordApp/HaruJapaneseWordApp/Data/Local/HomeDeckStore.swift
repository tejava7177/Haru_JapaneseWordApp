import Foundation

struct HomeDeckStore {
    private let userDefaults: UserDefaults

    private static let deckDateKey = "home_deck_date"
    private static let deckWordIdsKey = "home_deck_word_ids"
    private static let rerollDateKey = "home_deck_reroll_date"
    private static let rerollCountKey = "home_deck_reroll_count"

    private let maxRerollsPerDay: Int = 2
    private let deckSize: Int = 3

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getOrCreateDeck(
        date: Date,
        repository: DictionaryRepository,
        excluding ids: Set<Int>,
        level: JLPTLevel = .n5,
        count: Int? = nil
    ) -> [Int] {
        let todayString = Self.dateFormatter.string(from: date)
        if let savedDate = userDefaults.string(forKey: Self.deckDateKey),
           savedDate == todayString,
           let savedIds = loadDeckIds() {
            return savedIds
        }

        let size = count ?? deckSize
        let newIds = (try? repository.randomWordIds(level: level, count: size, excluding: ids)) ?? []
        saveDeck(ids: newIds, dateString: todayString)
        resetRerollCount(dateString: todayString)
        return newIds
    }

    func rerollDeck(
        date: Date,
        repository: DictionaryRepository,
        excluding ids: Set<Int>,
        level: JLPTLevel = .n5,
        count: Int? = nil
    ) -> [Int] {
        let todayString = Self.dateFormatter.string(from: date)
        let remaining = remainingRerolls(date: date)
        guard remaining > 0 else {
            return loadDeckIds() ?? []
        }

        let size = count ?? deckSize
        let newIds = (try? repository.randomWordIds(level: level, count: size, excluding: ids)) ?? []
        saveDeck(ids: newIds, dateString: todayString)
        incrementRerollCount(dateString: todayString)
        return newIds
    }

    func remainingRerolls(date: Date) -> Int {
        let todayString = Self.dateFormatter.string(from: date)
        let storedDate = userDefaults.string(forKey: Self.rerollDateKey)
        if storedDate != todayString {
            return maxRerollsPerDay
        }
        let count = userDefaults.integer(forKey: Self.rerollCountKey)
        return max(0, maxRerollsPerDay - count)
    }

    func resetDeckData() {
        userDefaults.removeObject(forKey: Self.deckDateKey)
        userDefaults.removeObject(forKey: Self.deckWordIdsKey)
        userDefaults.removeObject(forKey: Self.rerollDateKey)
        userDefaults.removeObject(forKey: Self.rerollCountKey)
    }

    private func loadDeckIds() -> [Int]? {
        if let data = userDefaults.data(forKey: Self.deckWordIdsKey) {
            if let ids = try? JSONDecoder().decode([Int].self, from: data) {
                return ids
            }
        }
        if let ids = userDefaults.array(forKey: Self.deckWordIdsKey) as? [Int] {
            return ids
        }
        return nil
    }

    private func saveDeck(ids: [Int], dateString: String) {
        if let data = try? JSONEncoder().encode(ids) {
            userDefaults.set(data, forKey: Self.deckWordIdsKey)
        } else {
            userDefaults.set(ids, forKey: Self.deckWordIdsKey)
        }
        userDefaults.set(dateString, forKey: Self.deckDateKey)
    }

    private func resetRerollCount(dateString: String) {
        userDefaults.set(dateString, forKey: Self.rerollDateKey)
        userDefaults.set(0, forKey: Self.rerollCountKey)
    }

    private func incrementRerollCount(dateString: String) {
        let storedDate = userDefaults.string(forKey: Self.rerollDateKey)
        if storedDate != dateString {
            resetRerollCount(dateString: dateString)
        }
        let current = userDefaults.integer(forKey: Self.rerollCountKey)
        userDefaults.set(current + 1, forKey: Self.rerollCountKey)
    }
}
