import Foundation

struct HomeDeckStore {
    private let userDefaults: UserDefaults

    private static let deckDateKey = "home_deck_date"
    private static let deckWordIdsKey = "home_deck_word_ids"
    private let deckSize: Int = 10

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
        return newIds
    }

    func resetDeckData() {
        userDefaults.removeObject(forKey: Self.deckDateKey)
        userDefaults.removeObject(forKey: Self.deckWordIdsKey)
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

}
