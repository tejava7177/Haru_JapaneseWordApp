import Foundation
import UIKit
import UserNotifications

final class PushRegistrationManager {
    static let shared = PushRegistrationManager()

    private weak var settingsStore: AppSettingsStore?
    private lazy var fallbackSettingsStore = AppSettingsStore()
    private let deviceAPIService: DeviceAPIServiceProtocol
    private var isRegisteringTokenToServer = false
    private var isUnregisteringTokenFromServer = false

    init(deviceAPIService: DeviceAPIServiceProtocol = DeviceAPIService()) {
        self.deviceAPIService = deviceAPIService
    }

    @MainActor
    func configure(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        if settingsStore.apnsDeviceToken == nil, let existingToken = fallbackSettingsStore.apnsDeviceToken {
            settingsStore.setAPNSDeviceToken(existingToken)
        }
    }

    @MainActor
    func syncRegistrationState() async {
        let settingsStore = activeSettingsStore()

        guard settingsStore.settings.isLearningNotificationEnabled else {
            return
        }

        let authorizationStatus = await NotificationManager.shared.authorizationStatus()
        guard authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral else {
            return
        }

        requestRemoteNotifications()
        await registerDeviceTokenToServerIfPossible()
    }

    @MainActor
    func requestRemoteNotifications() {
        print("[APNs] registerForRemoteNotifications requested")
        UIApplication.shared.registerForRemoteNotifications()
    }

    @MainActor
    func handleDeviceTokenRegistration(_ deviceTokenData: Data) async {
        let settingsStore = activeSettingsStore()

        let token = deviceTokenData.map { String(format: "%02x", $0) }.joined()
        guard token.isEmpty == false else {
            print("[APNs] didFail error=Failed to convert APNs device token")
            return
        }

        print("[APNs] didRegister token=\(token)")
        settingsStore.setAPNSDeviceToken(token)
        await registerDeviceTokenToServerIfPossible()
    }

    @MainActor
    func handleDeviceTokenRegistrationFailure(_ error: Error) {
        print("[APNs] didFail error=\(error.localizedDescription)")
    }

    @MainActor
    func registerDeviceTokenToServerIfPossible() async {
        let settingsStore = activeSettingsStore()
        guard settingsStore.settings.isLearningNotificationEnabled else { return }
        guard isRegisteringTokenToServer == false else { return }

        guard let userId = settingsStore.serverUserId, userId.isEmpty == false else {
            return
        }

        guard let token = settingsStore.apnsDeviceToken, token.isEmpty == false else {
            return
        }

        guard settingsStore.hasRegisteredDeviceTokenToServer(token: token, userId: userId) == false else {
            return
        }

        isRegisteringTokenToServer = true
        defer { isRegisteringTokenToServer = false }

        print("[APNs] server registration start userId=\(userId)")
        do {
            try await deviceAPIService.registerDeviceToken(userId: userId, token: token)
            settingsStore.markDeviceTokenRegisteredToServer(token: token, userId: userId)
            print("[APNs] server registration success token=\(token)")
        } catch {
            print("[APNs] server registration failed error=\(error.localizedDescription)")
        }
    }

    @MainActor
    func unregisterDeviceTokenIfNeeded(userId: String?) async {
        guard isUnregisteringTokenFromServer == false else { return }
        let settingsStore = activeSettingsStore()
        guard let userId, userId.isEmpty == false else {
            settingsStore.clearDeviceTokenServerRegistration()
            return
        }

        guard let token = settingsStore.apnsDeviceToken, token.isEmpty == false else {
            settingsStore.clearDeviceTokenServerRegistration()
            return
        }

        isUnregisteringTokenFromServer = true
        defer {
            settingsStore.clearDeviceTokenServerRegistration()
            isUnregisteringTokenFromServer = false
        }

        print("[APNs] unregister start userId=\(userId)")
        do {
            try await deviceAPIService.unregisterDeviceToken(userId: userId, token: token)
            print("[APNs] unregister success token=\(token)")
        } catch {
            print("[APNs] unregister failed error=\(error.localizedDescription)")
        }
    }

    @MainActor
    private func activeSettingsStore() -> AppSettingsStore {
        if let settingsStore {
            return settingsStore
        }
        return fallbackSettingsStore
    }
}
