import Foundation
import Combine
import UserNotifications

@MainActor
final class DeepLinkRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var pendingWordId: Int?

    func consumeWordId() -> Int? {
        defer { pendingWordId = nil }
        return pendingWordId
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handle(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func handle(userInfo: [AnyHashable: Any]) {
        if let wordId = userInfo["word_id"] as? Int {
            pendingWordId = wordId
        } else if let stringValue = userInfo["word_id"] as? String, let wordId = Int(stringValue) {
            pendingWordId = wordId
        }
    }
}
