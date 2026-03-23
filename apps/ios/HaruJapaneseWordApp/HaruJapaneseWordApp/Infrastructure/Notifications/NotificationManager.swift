import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    static let dailyLearningReminderIdentifier = "daily-learning-reminder"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            print("[Notification] authorization granted=true")
            return true
        case .denied:
            print("[Notification] authorization granted=false")
            return false
        case .notDetermined:
            print("[Notification] request authorization")
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            print("[Notification] authorization granted=\(granted)")
            return granted
        @unknown default:
            print("[Notification] authorization granted=false")
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleDailyLearningReminder() async {
        await cancelDailyLearningReminder()

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar.current
        dateComponents.hour = 20
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "하루"
        content.body = "오늘의 추천 단어 10개를 확인해보세요"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyLearningReminderIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[Notification] schedule daily reminder at 20:00")
        } catch {
            print("[Notification] failed to schedule daily reminder error=\(error.localizedDescription)")
        }
    }

    func cancelDailyLearningReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyLearningReminderIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.dailyLearningReminderIdentifier])
        print("[Notification] cancel daily reminder")
    }

    func syncDailyLearningReminder(isEnabled: Bool) async {
        guard isEnabled else {
            await cancelDailyLearningReminder()
            return
        }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            await scheduleDailyLearningReminder()
        case .notDetermined, .denied:
            await cancelDailyLearningReminder()
        @unknown default:
            await cancelDailyLearningReminder()
        }
    }
}
