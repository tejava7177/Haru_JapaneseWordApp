import Foundation
import UserNotifications

final class LocalNotificationPokeNotifier: PokeNotifierProtocol {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notifyPoke(receiverId: String, message: String, wordId: Int?) async -> PokeNotificationResult {
        let settings = await center.notificationSettings()
        let status = settings.authorizationStatus
        let isAuthorized: Bool

        switch status {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            isAuthorized = granted
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            return PokeNotificationResult(didSchedule: false, isAuthorized: false)
        }

        let content = UNMutableNotificationContent()
        content.title = "콕!"
        content.body = message
        content.sound = .default
        var userInfo: [AnyHashable: Any] = ["receiver_id": receiverId]
        if let wordId {
            userInfo["word_id"] = wordId
        }
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "mate_poke_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return PokeNotificationResult(didSchedule: true, isAuthorized: true)
        } catch {
            return PokeNotificationResult(didSchedule: false, isAuthorized: true)
        }
    }
}
