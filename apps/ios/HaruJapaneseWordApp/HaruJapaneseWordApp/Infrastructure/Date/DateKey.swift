import Foundation

enum DateKey {
    static func kstDateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    static func daysBetweenKST(from start: Date, to end: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        var kst = calendar
        kst.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let startOfDay = kst.startOfDay(for: start)
        let endOfDay = kst.startOfDay(for: end)
        return kst.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0
    }
}
