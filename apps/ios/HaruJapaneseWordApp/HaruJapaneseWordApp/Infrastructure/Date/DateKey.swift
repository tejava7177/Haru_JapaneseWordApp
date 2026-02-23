import Foundation

struct DateKey {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func todayString(from date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }

    static func startOfDay(for date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addingDays(_ days: Int, to date: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        let startFrom = calendar.startOfDay(for: from)
        let startTo = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: startFrom, to: startTo).day ?? 0
    }

    static func isoString(from date: Date = Date()) -> String {
        isoFormatter.string(from: date)
    }

    static func date(fromISO string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
    }
}
