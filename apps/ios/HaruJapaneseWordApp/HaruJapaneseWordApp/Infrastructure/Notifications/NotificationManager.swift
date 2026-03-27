import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    static let dailyLearningReminderIdentifier = "daily-learning-reminder"
    static let learningReminderIdentifierPrefix = "learning-reminder-"
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

    func scheduleLearningReminders(using settings: LearningNotificationSettings) async -> Bool {
        guard settings.isRepeating == false || settings.hasValidRepeatingRange else {
            print("[Notification] invalid repeating range start=\(settings.repeatStartMinutes) end=\(settings.repeatEndMinutes)")
            return false
        }

        await cancelLearningReminders()

        let scheduledMinutes = settings.scheduledMinutes()
        let content = learningReminderContent()

        do {
            for minutes in scheduledMinutes {
                var dateComponents = DateComponents()
                dateComponents.calendar = Calendar.current
                dateComponents.hour = minutes / 60
                dateComponents.minute = minutes % 60

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: learningReminderIdentifier(for: minutes),
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }

            print("[Notification] scheduled learning reminders count=\(scheduledMinutes.count) repeating=\(settings.isRepeating)")
            return true
        } catch {
            print("[Notification] failed to schedule learning reminders error=\(error.localizedDescription)")
            await cancelLearningReminders()
            return false
        }
    }

    func scheduleDailyLearningReminder() async {
        _ = await scheduleLearningReminders(
            using: LearningNotificationSettings(
                isEnabled: true,
                notificationTimeMinutes: 20 * 60
            )
        )
    }

    func cancelLearningReminders() async {
        let identifiers = await learningReminderIdentifiers()
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        print("[Notification] cancel learning reminders count=\(identifiers.count)")
    }

    func cancelDailyLearningReminder() async {
        await cancelLearningReminders()
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
            await cancelLearningReminders()
        @unknown default:
            await cancelLearningReminders()
        }
    }

    private func learningReminderContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "하루"
        content.body = "오늘의 추천 단어 10개를 확인해보세요"
        content.sound = .default
        return content
    }

    private func learningReminderIdentifier(for minutes: Int) -> String {
        "\(Self.learningReminderIdentifierPrefix)\(minutes)"
    }

    private func learningReminderIdentifiers() async -> [String] {
        let pending = await pendingLearningReminderIdentifiers()
        let delivered = await deliveredLearningReminderIdentifiers()
        return Array(Set(pending + delivered + [Self.dailyLearningReminderIdentifier]))
    }

    private func pendingLearningReminderIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let identifiers = requests
                    .map(\.identifier)
                    .filter {
                        $0 == Self.dailyLearningReminderIdentifier || $0.hasPrefix(Self.learningReminderIdentifierPrefix)
                    }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private func deliveredLearningReminderIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                let identifiers = notifications
                    .map(\.request.identifier)
                    .filter {
                        $0 == Self.dailyLearningReminderIdentifier || $0.hasPrefix(Self.learningReminderIdentifierPrefix)
                    }
                continuation.resume(returning: identifiers)
            }
        }
    }
}
