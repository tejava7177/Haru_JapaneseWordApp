import Foundation
import Combine

@MainActor
final class MateViewModel: ObservableObject {
    @Published private(set) var activeRoom: MateRoom?
    @Published var inviteCode: String = ""
    @Published var inputInviteCode: String = ""
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false

    private let service: MateService
    private let settingsStore: AppSettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(service: MateService, settingsStore: AppSettingsStore) {
        self.service = service
        self.settingsStore = settingsStore

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }

    func load() {
        service.cleanupIfNeeded()
        activeRoom = service.loadActiveRoom()
        inviteCode = activeRoom?.inviteCode ?? ""
    }

    func createInviteCode() {
        inviteCode = service.createInviteCode()
        activeRoom = service.loadActiveRoom()
    }

    func joinByInviteCode() {
        let trimmed = inputInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.isEmpty == false else {
            showAlert("초대 코드를 입력해 주세요.")
            return
        }
        do {
            _ = try service.joinByInviteCode(trimmed)
            inputInviteCode = ""
            load()
        } catch {
            showAlert("초대 코드에 참여하지 못했어요.")
        }
    }

    func endRoom() {
        guard let room = activeRoom else { return }
        service.endRoom(roomId: room.id, reason: "user_end")
        load()
    }

    func counterpartLabel(for room: MateRoom) -> String {
        let myId = settingsStore.mateUserId
        let otherId = (room.userAId == myId) ? room.userBId : room.userAId
        if otherId.hasPrefix("DEV-"), let suffix = otherId.split(separator: "-").last {
            return String(suffix)
        }
        return otherId.isEmpty ? "대기중" : otherId
    }

    func lastInteractionDescription(now: Date = Date()) -> String {
        guard let room = activeRoom else { return "-" }
        let days = service.daysSinceLastInteraction(room: room, now: now)
        if days <= 0 { return "오늘" }
        return "\(days)일 전"
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}
