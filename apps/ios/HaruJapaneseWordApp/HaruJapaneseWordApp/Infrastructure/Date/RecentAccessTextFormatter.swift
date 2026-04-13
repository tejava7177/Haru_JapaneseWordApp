import Foundation

enum RecentAccessTextFormatter {
    private static let unavailableText = "최근 접속일 정보 없음"

    static func text(
        from rawValue: String?,
        fallbackText: String? = nil,
        now: Date = Date(),
        logPrefix: String = "[RecentAccess]"
    ) -> String {
        guard let rawValue = trimmed(rawValue), rawValue.isEmpty == false else {
            let text = resolvedFallbackText(from: fallbackText)
            print("\(logPrefix) raw lastActiveAt=nil")
            print("\(logPrefix) normalized KST date=nil")
            print("\(logPrefix) today KST date=\(DateKey.kstDailyWordsKey(from: now))")
            print("\(logPrefix) computed day difference=nil")
            print("\(logPrefix) final recent access text=\(text)")
            return text
        }

        print("\(logPrefix) raw lastActiveAt=\(rawValue)")

        guard let parsedDate = parsedDate(from: rawValue, logPrefix: logPrefix) else {
            let text = resolvedFallbackText(from: fallbackText)
            print("\(logPrefix) normalized KST date=nil")
            print("\(logPrefix) today KST date=\(DateKey.kstDailyWordsKey(from: now))")
            print("\(logPrefix) computed day difference=nil")
            print("\(logPrefix) final recent access text=\(text)")
            return text
        }

        let normalizedKSTDate = DateKey.kstDailyWordsKey(from: parsedDate)
        let todayKSTDate = DateKey.kstDailyWordsKey(from: now)
        let dayDifference = max(DateKey.daysBetweenKST(from: parsedDate, to: now), 0)
        let text = dayDifference == 0 ? "오늘 접속" : "\(dayDifference)일 전 접속"

        print("\(logPrefix) normalized KST date=\(normalizedKSTDate)")
        print("\(logPrefix) today KST date=\(todayKSTDate)")
        print("\(logPrefix) computed day difference=\(dayDifference)")
        print("\(logPrefix) final recent access text=\(text)")
        return text
    }

    private static func parsedDate(from rawValue: String, logPrefix: String) -> Date? {
        if let parsedDate = ISO8601DateFormatter.fractionalOrInternet.date(from: rawValue)
            ?? ISO8601DateFormatter.internet.date(from: rawValue) {
            return parsedDate
        }

        let normalizedISO8601 = normalizedISO8601StringAssumingKST(from: rawValue)
        if normalizedISO8601 != rawValue {
            print("\(logPrefix) normalized raw lastActiveAt=\(normalizedISO8601)")
        }

        return ISO8601DateFormatter.fractionalOrInternet.date(from: normalizedISO8601)
            ?? ISO8601DateFormatter.internet.date(from: normalizedISO8601)
    }

    private static func normalizedISO8601StringAssumingKST(from rawValue: String) -> String {
        let hasTimezone = rawValue.hasSuffix("Z")
            || rawValue.range(of: "[+-]\\d{2}:?\\d{2}$", options: .regularExpression) != nil
        guard hasTimezone == false else { return rawValue }
        return "\(rawValue)+09:00"
    }

    private static func resolvedFallbackText(from fallbackText: String?) -> String {
        guard let fallbackText = trimmed(fallbackText), fallbackText.isEmpty == false else {
            return unavailableText
        }
        return fallbackText
    }

    private static func trimmed(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
