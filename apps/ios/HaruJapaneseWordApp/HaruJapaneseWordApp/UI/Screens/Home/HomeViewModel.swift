import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todayWord: WordSummary?
    @Published var errorMessage: String?

    private let repository: DictionaryRepository
    private let userDefaults: UserDefaults

    private static let todayWordDateKey = "today_word_date"
    private static let todayWordIdKey = "today_word_id"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(repository: DictionaryRepository, userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults
    }

    func loadTodayWord() {
        errorMessage = nil
        let todayString = Self.dateFormatter.string(from: Date())

        if let savedDate = userDefaults.string(forKey: Self.todayWordDateKey),
           savedDate == todayString {
            let savedId = userDefaults.integer(forKey: Self.todayWordIdKey)
            if savedId > 0 {
                do {
                    if let cached = try repository.fetchWordSummary(wordId: savedId) {
                        todayWord = cached
                        return
                    }
                } catch {
                    errorMessage = "오늘의 단어를 불러오지 못했습니다."
                }
            }
        }

        do {
            if let random = try repository.randomWord(level: .n5) {
                todayWord = random
                userDefaults.set(todayString, forKey: Self.todayWordDateKey)
                userDefaults.set(random.id, forKey: Self.todayWordIdKey)
            } else {
                todayWord = nil
                errorMessage = "오늘의 단어를 찾지 못했습니다."
            }
        } catch {
            todayWord = nil
            errorMessage = "오늘의 단어를 불러오지 못했습니다."
        }
    }
}
