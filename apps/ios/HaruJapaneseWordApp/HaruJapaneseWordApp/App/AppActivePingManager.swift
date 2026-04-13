import Combine
import Foundation
import SwiftUI

@MainActor
final class AppActivePingManager: ObservableObject {
    private let settingsStore: AppSettingsStore
    private let profileAPIService: ProfileAPIServiceProtocol
    private var activePingTask: Task<Void, Never>?

    init(
        settingsStore: AppSettingsStore,
        profileAPIService: ProfileAPIServiceProtocol = ProfileAPIService()
    ) {
        self.settingsStore = settingsStore
        self.profileAPIService = profileAPIService
    }

    func sendActivePingIfNeeded(source: String) {
        guard let userId = normalizedUserId else {
            print("[ActivePing] skip source=\(source) reason=no-user-id")
            return
        }

        guard activePingTask == nil else {
            print("[ActivePing] skip source=\(source) reason=in-flight userId=\(userId)")
            return
        }

        print("[ActivePing] start source=\(source) userId=\(userId)")

        activePingTask = Task { [weak self] in
            guard let self else { return }

            defer { self.activePingTask = nil }

            do {
                try await self.profileAPIService.sendActivePing(userId: userId)
                print("[ActivePing] success source=\(source) userId=\(userId)")
            } catch {
                print("[ActivePing] failure source=\(source) userId=\(userId) error=\(error.localizedDescription)")
            }
        }
    }

    private var normalizedUserId: String? {
        guard let userId = settingsStore.currentBackendUserId?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              userId.isEmpty == false else {
            return nil
        }
        return userId
    }
}
