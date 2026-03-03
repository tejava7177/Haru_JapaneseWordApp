import Foundation
import Combine
import UserNotifications

enum MatchCelebration: Identifiable, Equatable {
    case connected(message: MatchCelebrationMessage, roomId: Int)

    var id: Int {
        switch self {
        case .connected(_, let roomId):
            return roomId
        }
    }
}

struct MateRoomCardItem: Identifiable, Equatable {
    let id: Int
    let room: MateRoom
    let counterpartLabel: String
    let lastInteractionText: String
    let jlptLevel: JLPTLevel?
    let extraInfoText: String
}

@MainActor
final class MateViewModel: ObservableObject {
    static let maxMateCount: Int = 4

    @Published private(set) var activeRooms: [MateRoom] = []
    @Published private(set) var connectedRoomCards: [MateRoomCardItem] = []
    @Published var inviteCode: String = ""
    @Published var inputInviteCode: String = ""
    @Published var inviteSectionErrorMessage: String?
    @Published private(set) var isBusy: Bool = false
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false
    @Published var matchCelebration: MatchCelebration?

    private let service: MateService
    private let settingsStore: AppSettingsStore
    private let userMetaProvider: MateUserMetaProvider
    private var cancellables: Set<AnyCancellable> = []
    private var celebratedRoomIds: Set<Int> = []

    init(
        service: MateService,
        settingsStore: AppSettingsStore,
        userMetaProvider: MateUserMetaProvider = DevMateUserMetaProvider()
    ) {
        self.service = service
        self.settingsStore = settingsStore
        self.userMetaProvider = userMetaProvider

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }

    var connectedMateCount: Int {
        connectedRoomCards.count
    }

    var canAddNewMate: Bool {
        connectedMateCount < Self.maxMateCount
    }

    func load() {
        service.cleanupIfNeeded()
        let userId = settingsStore.mateUserId
        if userId.isEmpty {
            activeRooms = []
            connectedRoomCards = []
            inviteCode = ""
            return
        }

        let previousActiveRooms = activeRooms
        activeRooms = service.loadActiveRooms()
        inviteCode = activeRooms.first?.inviteCode ?? ""
        connectedRoomCards = makeConnectedRoomCards(from: activeRooms, myUserId: userId)

        for room in activeRooms where room.hasMate {
            let previousRoom = previousActiveRooms.first(where: { $0.id == room.id })
            triggerCelebrationIfNeeded(room: room, previousRoom: previousRoom)
        }
    }

    func createInviteCode() {
        guard canAddNewMate else {
            inviteSectionErrorMessage = "동행은 최대 \(Self.maxMateCount)명까지 가능해요"
            return
        }
        print("MATE_ACTION_CREATE_INVITE")
        isBusy = true
        defer { isBusy = false }
        inviteSectionErrorMessage = nil
        inviteCode = service.createInviteCode()
        load()
    }

    func joinByInviteCode() {
        joinByInviteCode(inputInviteCode)
    }

    func joinByInviteCode(_ inviteCode: String) {
        guard canAddNewMate else {
            inviteSectionErrorMessage = "동행은 최대 \(Self.maxMateCount)명까지 가능해요"
            return
        }
        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.isEmpty == false else {
            inviteSectionErrorMessage = "초대 코드를 입력해 주세요."
            return
        }
        print("MATE_ACTION_JOIN_INVITE code=\(trimmed)")
        isBusy = true
        defer { isBusy = false }
        inviteSectionErrorMessage = nil
        do {
            let room = try service.joinByInviteCode(trimmed)
            let previousRoom = activeRooms.first(where: { $0.id == room.id })
            triggerCelebrationIfNeeded(room: room, previousRoom: previousRoom)
            inputInviteCode = ""
            load()
        } catch {
            inviteSectionErrorMessage = "초대 코드에 참여하지 못했어요."
        }
    }

    func endRoom(roomId: Int) {
        print("MATE_ACTION_END_ROOM roomId=\(roomId)")
        isBusy = true
        defer { isBusy = false }
        service.endRoom(roomId: roomId, reason: "user_end")
        load()
    }

    func counterpartLabel(for room: MateRoom) -> String {
        let otherId = counterpartUserId(for: room)
        if otherId.hasPrefix("DEV-"), let suffix = otherId.split(separator: "-").last, suffix.isEmpty == false {
            return String(suffix)
        }
        return otherId.isEmpty ? "대기중" : otherId
    }

    func lastInteractionDescription(for room: MateRoom, now: Date = Date()) -> String {
        let days = service.daysSinceLastInteraction(room: room, now: now)
        if days <= 0 { return "오늘" }
        return "\(days)일 전"
    }

    private func triggerCelebrationIfNeeded(room: MateRoom, previousRoom: MateRoom?) {
        guard room.isActive, room.hasMate else { return }
        guard celebratedRoomIds.contains(room.id) == false else { return }
        if let previousRoom, previousRoom.id == room.id, previousRoom.hasMate {
            return
        }
        celebratedRoomIds.insert(room.id)
        let message = MatchCelebrationMessageProvider.random()
        matchCelebration = .connected(message: message, roomId: room.id)
        scheduleMatchNotificationIfAllowed()
    }

    private func counterpartUserId(for room: MateRoom) -> String {
        let myUserId = settingsStore.mateUserId
        return room.userAId != myUserId ? room.userAId : room.userBId
    }

    private func makeConnectedRoomCards(from rooms: [MateRoom], myUserId: String) -> [MateRoomCardItem] {
        rooms
            .filter { $0.hasMate }
            .map { room in
                let otherId = room.userAId != myUserId ? room.userAId : room.userBId
                return MateRoomCardItem(
                    id: room.id,
                    room: room,
                    counterpartLabel: counterpartLabel(for: room),
                    lastInteractionText: lastInteractionDescription(for: room),
                    jlptLevel: userMetaProvider.jlptLevel(for: otherId),
                    extraInfoText: "기록 준비중"
                )
            }
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
