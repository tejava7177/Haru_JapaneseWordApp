import Foundation

struct LearningNotificationSettings: Hashable {
    enum RepeatInterval: Int, CaseIterable, Hashable, Identifiable {
        case thirtyMinutes = 30
        case oneHour = 60
        case twoHours = 120
        case threeHours = 180

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .thirtyMinutes:
                return "30분"
            case .oneHour:
                return "1시간"
            case .twoHours:
                return "2시간"
            case .threeHours:
                return "3시간"
            }
        }
    }

    var isEnabled: Bool = false
    var notificationTimeMinutes: Int = 20 * 60
    var isRepeating: Bool = false
    var repeatStartMinutes: Int = 9 * 60
    var repeatEndMinutes: Int = 21 * 60
    var repeatInterval: RepeatInterval = .oneHour

    var hasValidRepeatingRange: Bool {
        repeatStartMinutes <= repeatEndMinutes
    }

    var repeatingRangeDurationMinutes: Int {
        repeatEndMinutes - repeatStartMinutes
    }

    var availableRepeatIntervals: [RepeatInterval] {
        guard hasValidRepeatingRange else { return [] }
        return RepeatInterval.allCases.filter { repeatingRangeDurationMinutes > $0.rawValue }
    }

    var hasValidRepeatIntervalChoice: Bool {
        availableRepeatIntervals.contains(repeatInterval)
    }

    var notificationTime: Date {
        Self.date(fromMinutes: notificationTimeMinutes)
    }

    var repeatStartTime: Date {
        Self.date(fromMinutes: repeatStartMinutes)
    }

    var repeatEndTime: Date {
        Self.date(fromMinutes: repeatEndMinutes)
    }

    func scheduledMinutes() -> [Int] {
        guard isEnabled else { return [] }

        if isRepeating == false {
            return [notificationTimeMinutes]
        }

        guard hasValidRepeatingRange, hasValidRepeatIntervalChoice else { return [] }

        var scheduled: [Int] = []
        var current = repeatStartMinutes

        while current <= repeatEndMinutes {
            scheduled.append(current)
            current += repeatInterval.rawValue
        }

        return scheduled
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }

    static func date(fromMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        let normalized = max(0, min((23 * 60) + 59, minutes))
        let hour = normalized / 60
        let minute = normalized % 60
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? startOfDay
    }

    static func preferredInterval(from intervals: [RepeatInterval]) -> RepeatInterval? {
        if intervals.contains(.oneHour) {
            return .oneHour
        }
        if intervals.contains(.thirtyMinutes) {
            return .thirtyMinutes
        }
        return intervals.first
    }

    static func availableRepeatIntervals(startMinutes: Int, endMinutes: Int) -> [RepeatInterval] {
        guard startMinutes <= endMinutes else { return [] }
        let duration = endMinutes - startMinutes
        return RepeatInterval.allCases.filter { duration > $0.rawValue }
    }
}
