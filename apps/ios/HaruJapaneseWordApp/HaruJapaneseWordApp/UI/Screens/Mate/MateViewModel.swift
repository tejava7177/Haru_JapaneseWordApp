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
    let jlptLevel: JLPTLevel
    let extraInfoText: String
    let canSendPokeToday: Bool
    let pokeStatusText: String?
}

@MainActor
final class MateViewModel: ObservableObject {
    static let maxMateCount: Int = MateService.maxActiveMatesPerUser

    @Published private(set) var activeRooms: [MateRoom] = []
    @Published private(set) var connectedRoomCards: [MateRoomCardItem] = []
    @Published var inviteCode: String = ""
    @Published var inputInviteCode: String = ""
    @Published var inviteSectionErrorMessage: String?
    @Published private(set) var isBusy: Bool = false
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false
    @Published var matchCelebration: MatchCelebration?
    @Published private(set) var latestPokeByRoomId: [Int: MatePoke] = [:]
    @Published private(set) var canSendPokeByRoomId: [Int: Bool] = [:]
    @Published private(set) var pokeStatusByRoomId: [Int: String] = [:]

    private let service: MateService
    private let settingsStore: AppSettingsStore
    private let userMetaProvider: MateUserMetaProvider
    private var cancellables: Set<AnyCancellable> = []
    private var celebratedRoomIds: Set<Int> = []
    private var pollTask: Task<Void, Never>?
    private var isViewVisible: Bool = false

    init(
        service: MateService,
        settingsStore: AppSettingsStore,
        userMetaProvider: MateUserMetaProvider? = nil
    ) {
        self.service = service
        self.settingsStore = settingsStore
        self.userMetaProvider = userMetaProvider ?? DevMateUserMetaProvider(settingsStore: settingsStore)

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }

    deinit {
        pollTask?.cancel()
    }

    var connectedMateCount: Int {
        connectedRoomCards.count
    }

    var canAddNewMate: Bool {
        activeRooms.count < Self.maxMateCount
    }

    func onViewAppear() {
        isViewVisible = true
        load()
        startPokePollingIfNeeded()
    }

    func onViewDisappear() {
        isViewVisible = false
        stopPokePolling()
    }

    func load() {
        service.cleanupIfNeeded()
        let userId = settingsStore.mateUserId
        if userId.isEmpty {
            activeRooms = []
            connectedRoomCards = []
            inviteCode = ""
            latestPokeByRoomId = [:]
            canSendPokeByRoomId = [:]
            pokeStatusByRoomId = [:]
            stopPokePolling()
            return
        }

        let previousActiveRooms = activeRooms
        activeRooms = service.getActiveRooms()
        inviteCode = activeRooms.first(where: { $0.userAId == userId && $0.userBId.isEmpty })?.inviteCode ?? ""
        rebuildConnectedCards(myUserId: userId)

        for room in activeRooms where room.hasMate {
            let previousRoom = previousActiveRooms.first(where: { $0.id == room.id })
            triggerCelebrationIfNeeded(room: room, previousRoom: previousRoom)
        }

        Task {
            await refreshPokeState(shouldLogPollUpdate: false)
        }

        if isViewVisible {
            startPokePollingIfNeeded()
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
        do {
            inviteCode = try service.createInvite()
            load()
        } catch let mateError as MateError {
            inviteSectionErrorMessage = mateError.userMessage
        } catch {
            inviteSectionErrorMessage = "동행을 시작하지 못했어요. 다시 시도해 주세요."
        }
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
            let room = try service.join(inviteCode: trimmed)
            let previousRoom = activeRooms.first(where: { $0.id == room.id })
            triggerCelebrationIfNeeded(room: room, previousRoom: previousRoom)
            inputInviteCode = ""
            load()
        } catch let mateError as MateError {
            inviteSectionErrorMessage = mateError.userMessage
        } catch {
            inviteSectionErrorMessage = "동행을 시작하지 못했어요. 다시 시도해 주세요."
        }
    }

    func endRoom(roomId: Int) {
        print("MATE_ACTION_END_ROOM roomId=\(roomId)")
        isBusy = true
        defer { isBusy = false }
        do {
            try service.end(roomId: roomId)
            load()
        } catch let mateError as MateError {
            alertMessage = mateError.userMessage
            isShowingAlert = true
        } catch {
            alertMessage = "동행을 종료하지 못했어요."
            isShowingAlert = true
        }
    }

    func sendPoke(roomId: Int) {
        guard isBusy == false else { return }
        let currentUserId = settingsStore.mateUserId
        guard currentUserId.isEmpty == false else { return }

        print("[MatePoke] send start user=\(currentUserId) room=\(roomId)")

        isBusy = true
        Task {
            let result = await service.sendPoke(roomId: roomId, currentUserId: currentUserId)
            await MainActor.run {
                isBusy = false
                switch result {
                case .success(let poke):
                    print("[MatePoke] send ok pokeId=\(poke.id ?? -1) createdAt=\(Int(poke.createdAt.timeIntervalSince1970))")
                    latestPokeByRoomId[poke.roomId] = poke
                    canSendPokeByRoomId[poke.roomId] = false
                    pokeStatusByRoomId[poke.roomId] = "오늘 콕 완료"
                    updateLastInteraction(roomId: poke.roomId, at: poke.createdAt)
                    rebuildConnectedCards(myUserId: currentUserId)
                case .failure(let error):
                    if isAlreadyPokedToday(error) {
                        print("[MatePoke] send blocked alreadyPokedToday")
                        canSendPokeByRoomId[roomId] = false
                        pokeStatusByRoomId[roomId] = "오늘 콕 완료"
                        rebuildConnectedCards(myUserId: currentUserId)
                    } else {
                        alertMessage = "콕 전송에 실패했어요."
                        isShowingAlert = true
                    }
                }
            }
        }
    }

    func counterpartLabel(for room: MateRoom) -> String {
        let otherId = counterpartUserId(for: room)
        if otherId.hasPrefix("DEV-"), let suffix = otherId.split(separator: "-").last, suffix.isEmpty == false {
            return String(suffix)
        }
        return otherId.isEmpty ? "대기중" : otherId
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

    private func startPokePollingIfNeeded() {
        guard pollTask == nil else { return }
        guard activeRooms.contains(where: { $0.hasMate }) else { return }
        pollTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard Task.isCancelled == false else { break }
                await self?.refreshPokeState(shouldLogPollUpdate: true)
            }
        }
    }

    private func stopPokePolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refreshPokeState(shouldLogPollUpdate: Bool) async {
        let currentUserId = settingsStore.mateUserId
        guard currentUserId.isEmpty == false else { return }

        var refreshedLatestByRoomId: [Int: MatePoke] = [:]
        var refreshedCanSendByRoomId: [Int: Bool] = [:]
        var refreshedStatusByRoomId: [Int: String] = [:]
        let previousLatestByRoomId = latestPokeByRoomId

        for room in activeRooms where room.hasMate {
            if let refreshedRoom = await service.refreshRoom(roomId: room.id) {
                updateLastInteraction(roomId: refreshedRoom.id, at: refreshedRoom.lastInteractionAt)
            }

            let fetchedLatest = await service.fetchLatestPoke(roomId: room.id)
            let fetchedCanSend = await service.canSendPokeToday(roomId: room.id, currentUserId: currentUserId)

            if let fetchedLatest {
                refreshedLatestByRoomId[room.id] = fetchedLatest
            }
            refreshedCanSendByRoomId[room.id] = fetchedCanSend
            if fetchedCanSend == false {
                refreshedStatusByRoomId[room.id] = "오늘 콕 완료"
            }

            if shouldLogPollUpdate,
               let fetchedLatest,
               hasPokeChanged(previous: previousLatestByRoomId[room.id], next: fetchedLatest) {
                print("[MatePoke] poll updated room=\(room.id) latestPokeAt=\(Int(fetchedLatest.createdAt.timeIntervalSince1970))")
            }
        }

        latestPokeByRoomId = refreshedLatestByRoomId
        canSendPokeByRoomId = refreshedCanSendByRoomId
        pokeStatusByRoomId = refreshedStatusByRoomId
        rebuildConnectedCards(myUserId: currentUserId)
    }

    private func hasPokeChanged(previous: MatePoke?, next: MatePoke) -> Bool {
        if let previous {
            return previous.id != next.id || previous.createdAt != next.createdAt
        }
        return true
    }

    private func interactionDate(for room: MateRoom) -> Date {
        if let latestPoke = latestPokeByRoomId[room.id] {
            return latestPoke.createdAt
        }
        return room.lastInteractionAt
    }

    private func rebuildConnectedCards(myUserId: String) {
        connectedRoomCards = activeRooms
            .filter { $0.hasMate }
            .map { room in
                let otherId = room.userAId != myUserId ? room.userAId : room.userBId
                let interactionDate = interactionDate(for: room)
                let canSendPokeToday = canSendPokeByRoomId[room.id] ?? true
                return MateRoomCardItem(
                    id: room.id,
                    room: room,
                    counterpartLabel: counterpartLabel(for: room),
                    lastInteractionText: lastInteractionDescription(interactionDate: interactionDate),
                    jlptLevel: userMetaProvider.jlptLevel(for: otherId),
                    extraInfoText: "기록 준비중",
                    canSendPokeToday: canSendPokeToday,
                    pokeStatusText: pokeStatusByRoomId[room.id]
                )
            }
    }

    private func updateLastInteraction(roomId: Int, at date: Date) {
        activeRooms = activeRooms.map { room in
            guard room.id == roomId else { return room }
            return MateRoom(
                id: room.id,
                userAId: room.userAId,
                userBId: room.userBId,
                inviteCode: room.inviteCode,
                createdAt: room.createdAt,
                lastInteractionAt: date,
                isActive: room.isActive
            )
        }
    }

    private func lastInteractionDescription(interactionDate: Date, now: Date = Date()) -> String {
        let days = DateKey.daysBetweenKST(from: interactionDate, to: now)
        if days <= 0 { return "오늘" }
        return "\(days)일 전"
    }

    private func isAlreadyPokedToday(_ error: Error) -> Bool {
        if let pokeError = error as? MatePokeError, pokeError == .alreadyPokedToday {
            return true
        }
        return false
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
