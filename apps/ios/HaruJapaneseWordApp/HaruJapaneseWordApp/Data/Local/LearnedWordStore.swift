import Foundation

struct LearnedWordStore {
    private let userDefaults: UserDefaults
    private let learnedWordsKey = "learned_words"

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

    func markLearned(wordId: Int, date: Date) {
        var map = loadLearnedMap()
        map[String(wordId)] = Self.dateFormatter.string(from: date)
        userDefaults.set(map, forKey: learnedWordsKey)
    }

    func unmarkLearned(wordId: Int) {
        var map = loadLearnedMap()
        map.removeValue(forKey: String(wordId))
        userDefaults.set(map, forKey: learnedWordsKey)
    }

    func isLearned(wordId: Int, today: Date) -> Bool {
        let todayString = Self.dateFormatter.string(from: today)
        let map = loadLearnedMap()
        return map[String(wordId)] == todayString
    }

    func isExcluded(wordId: Int, today: Date, excludeDays: Int) -> Bool {
        let map = loadLearnedMap()
        guard let learnedString = map[String(wordId)],
              let learnedDate = Self.dateFormatter.date(from: learnedString) else {
            return false
        }
        let calendar = Calendar.current
        let startToday = calendar.startOfDay(for: today)
        let startLearned = calendar.startOfDay(for: learnedDate)
        if startLearned > startToday {
            return true
        }
        let diff = calendar.dateComponents([.day], from: startLearned, to: startToday).day ?? 0
        return diff < excludeDays
    }

    func loadExcludedSet(today: Date, excludeDays: Int) -> Set<Int> {
        let map = loadLearnedMap()
        var result: Set<Int> = []
        for (key, value) in map {
            guard let id = Int(key),
                  let learnedDate = Self.dateFormatter.date(from: value) else {
                continue
            }
            let calendar = Calendar.current
            let startToday = calendar.startOfDay(for: today)
            let startLearned = calendar.startOfDay(for: learnedDate)
            if startLearned > startToday {
                result.insert(id)
                continue
            }
            let diff = calendar.dateComponents([.day], from: startLearned, to: startToday).day ?? 0
            if diff < excludeDays {
                result.insert(id)
            }
        }
        return result
    }

    func loadLearnedSet(today: Date) -> Set<Int> {
        let todayString = Self.dateFormatter.string(from: today)
        let map = loadLearnedMap()
        var result: Set<Int> = []
        for (key, value) in map where value == todayString {
            if let id = Int(key) {
                result.insert(id)
            }
        }
        return result
    }

    func resetLearnedData() {
        userDefaults.removeObject(forKey: learnedWordsKey)
    }

    private func loadLearnedMap() -> [String: String] {
        userDefaults.dictionary(forKey: learnedWordsKey) as? [String: String] ?? [:]
    }
}
