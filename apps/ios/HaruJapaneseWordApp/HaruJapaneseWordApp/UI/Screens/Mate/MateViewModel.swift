import Foundation
import Combine
import UserNotifications

enum MatchCelebration: Identifiable, Equatable {
    case connected(partnerLabel: String, roomId: Int)

    var id: Int {
        switch self {
        case .connected(_, let roomId):
            return roomId
        }
    }
}

@MainActor
final class MateViewModel: ObservableObject {
    @Published private(set) var activeRoom: MateRoom?
    @Published var inviteCode: String = ""
    @Published var inputInviteCode: String = ""
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false
    @Published var matchCelebration: MatchCelebration?

    private let service: MateService
    private let settingsStore: AppSettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var lastCelebratedRoomId: Int?

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
        let userId = settingsStore.mateUserId
        if userId.isEmpty {
            print("MATE_VM_REFRESH_EMPTY_USERID")
            return
        }
        print("MATE_VM_REFRESH userId=\(userId)")
        let previousRoom = activeRoom
        activeRoom = service.loadActiveRoom()
        inviteCode = activeRoom?.inviteCode ?? ""
        if let activeRoom {
            print("MATE_ROOM_FOUND room=\(activeRoom)")
            triggerCelebrationIfNeeded(room: activeRoom, previousRoom: previousRoom)
        } else {
            print("MATE_ROOM_NOT_FOUND")
        }
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
            let room = try service.joinByInviteCode(trimmed)
            triggerCelebrationIfNeeded(room: room, previousRoom: activeRoom)
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

    private func triggerCelebrationIfNeeded(room: MateRoom, previousRoom: MateRoom?) {
        guard room.isActive, room.hasMate else { return }
        guard lastCelebratedRoomId != room.id else { return }
        if let previousRoom, previousRoom.id == room.id, previousRoom.hasMate {
            return
        }
        lastCelebratedRoomId = room.id
        let partnerLabel = counterpartLabel(for: room)
        matchCelebration = .connected(partnerLabel: partnerLabel, roomId: room.id)
        scheduleMatchNotificationIfAllowed()
    }

    private func scheduleMatchNotificationIfAllowed() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Mate 연결됨"
            content.body = "이제 서로 콕 찌를 수 있어요."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "mate.connected.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
