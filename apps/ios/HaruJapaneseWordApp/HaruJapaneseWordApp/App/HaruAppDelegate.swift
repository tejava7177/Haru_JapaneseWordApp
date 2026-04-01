import UIKit
import UserNotifications

final class HaruAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await PushRegistrationManager.shared.handleDeviceTokenRegistration(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushRegistrationManager.shared.handleDeviceTokenRegistrationFailure(error)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        guard BuddyPushPayload.isPetalReceived(userInfo: userInfo) else {
            return []
        }

        print("[BuddyPush] foreground push received type=PETAL_RECEIVED")
        BuddyPushPayload.postPetalStatusDidChange(
            trigger: .pushForeground,
            remoteUserInfo: userInfo
        )
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard BuddyPushPayload.isPetalReceived(userInfo: userInfo) else {
            return
        }

        print("[BuddyPush] notification tap received type=PETAL_RECEIVED")
        BuddyPushPayload.postPetalStatusDidChange(
            trigger: .pushTap,
            remoteUserInfo: userInfo
        )
    }
}
