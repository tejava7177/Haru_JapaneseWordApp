import Foundation

struct MateHomeState: Hashable {
    let room: MateRoom?
    let myLearnedToday: Bool
    let mateLearnedToday: Bool
    let canPoke: Bool
    let shouldShowInactivityPrompt: Bool
    let inactivityDays: Int
}

struct MatePokeOutcome: Hashable {
    let succeeded: Bool
    let message: String
    let didScheduleNotification: Bool
}

final class MateService {
    private let repository: MateRepositoryProtocol
    private let dictionaryRepository: DictionaryRepository
    private let notifier: PokeNotifierProtocol
    private let profileStore: UserProfileStore
    private var identityStore: MateIdentityStore
    private let userDefaults: UserDefaults

    private let inactivityPromptKey = "mate_inactivity_prompt_date"

    init(
        repository: MateRepositoryProtocol,
        dictionaryRepository: DictionaryRepository,
        notifier: PokeNotifierProtocol,
        profileStore: UserProfileStore = UserProfileStore(),
        identityStore: MateIdentityStore = MateIdentityStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.dictionaryRepository = dictionaryRepository
        self.notifier = notifier
        self.profileStore = profileStore
        self.identityStore = identityStore
        self.userDefaults = userDefaults
    }

    func currentUserId() -> String {
        var store = identityStore
        return store.userId()
    }

    func currentInviteCode() -> String {
        var store = identityStore
        return store.inviteCode()
    }

    func loadHomeState(now: Date = Date()) throws -> MateHomeState {
        let userId = currentUserId()
        guard var room = try repository.getLatestRoom(userId: userId) else {
            return MateHomeState(room: nil, myLearnedToday: false, mateLearnedToday: false, canPoke: false, shouldShowInactivityPrompt: false, inactivityDays: 0)
        }

        if room.status == .active || room.status == .paused {
            if isExpired(room: room, now: now) {
                try repository.updateRoomStatus(roomId: room.id, status: .expired)
                room = MateRoom(
                    id: room.id,
                    userId: room.userId,
                    mateUserId: room.mateUserId,
                    mateNickname: room.mateNickname,
                    startDate: room.startDate,
                    endDate: room.endDate,
                    status: .expired
                )
            }
        }

        guard room.status == .active || room.status == .paused else {
            return MateHomeState(room: room, myLearnedToday: false, mateLearnedToday: false, canPoke: false, shouldShowInactivityPrompt: false, inactivityDays: 0)
        }

        let dateKey = DateKey.todayString(from: now)
        let myLearned = (try? repository.getTodayStatus(userId: userId, date: dateKey)) ?? false
        let mateLearned = (try? repository.getTodayStatus(userId: room.mateUserId, date: dateKey)) ?? false
        let canPoke = (try? repository.canPoke(senderId: userId, receiverId: room.mateUserId, date: dateKey)) ?? false
        let inactivity = try inactivityInfo(room: room, now: now)

        return MateHomeState(
            room: room,
            myLearnedToday: myLearned,
            mateLearnedToday: mateLearned,
            canPoke: canPoke && mateLearned == false,
            shouldShowInactivityPrompt: inactivity.shouldPrompt,
            inactivityDays: inactivity.days
        )
    }

    func createRoomFromInvite(code: String, mateNickname: String, now: Date = Date()) throws -> MateRoom {
        let userId = currentUserId()
        if let existing = try repository.getActiveRoom(userId: userId) {
            return existing
        }
        let mateUserId = "mate_\(code.uppercased())"
        return try repository.createRoom(userId: userId, mateUserId: mateUserId, mateNickname: mateNickname, startDate: now)
    }

    #if DEBUG
    func createRoomFromMock(now: Date = Date()) throws -> MateRoom {
        let userId = currentUserId()
        if let existing = try repository.getActiveRoom(userId: userId) {
            return existing
        }
        let mates = ["서연", "민재", "윤지", "서준", "지후", "수아", "하린", "도윤"]
        let nickname = mates.randomElement() ?? "메이트"
        let mateUserId = "mock_\(UUID().uuidString.prefix(6))"
        return try repository.createRoom(userId: userId, mateUserId: mateUserId, mateNickname: nickname, startDate: now)
    }
    #endif

    func endRoom(_ room: MateRoom) throws {
        try repository.updateRoomStatus(roomId: room.id, status: .ended)
    }

    func pauseRoom(_ room: MateRoom) throws {
        try repository.updateRoomStatus(roomId: room.id, status: .paused)
    }

    func markLearnedToday(now: Date = Date()) {
        let userId = currentUserId()
        let dateKey = DateKey.todayString(from: now)
        try? repository.setTodayLearned(userId: userId, date: dateKey, learned: true)
    }

    func pokeMate(level: JLPTLevel, now: Date = Date()) async -> MatePokeOutcome {
        let userId = currentUserId()
        guard let room = try? repository.getActiveRoom(userId: userId) else {
            return MatePokeOutcome(succeeded: false, message: "Mate가 연결되어 있지 않아요.", didScheduleNotification: false)
        }
        let dateKey = DateKey.todayString(from: now)
        let mateLearned = (try? repository.getTodayStatus(userId: room.mateUserId, date: dateKey)) ?? false
        guard mateLearned == false else {
            return MatePokeOutcome(succeeded: false, message: "오늘은 이미 함께 공부를 시작했어요.", didScheduleNotification: false)
        }
        let canPoke = (try? repository.canPoke(senderId: userId, receiverId: room.mateUserId, date: dateKey)) ?? false
        guard canPoke else {
            return MatePokeOutcome(succeeded: false, message: "오늘은 이미 콕을 보냈어요.", didScheduleNotification: false)
        }

        guard let word = await selectPokeWord(level: level) else {
            return MatePokeOutcome(succeeded: false, message: "질문 단어를 준비하지 못했어요.", didScheduleNotification: false)
        }

        do {
            _ = try repository.createPoke(senderId: userId, receiverId: room.mateUserId, date: dateKey, wordId: word.id)
        } catch {
            return MatePokeOutcome(succeeded: false, message: "이미 오늘 콕을 보냈어요.", didScheduleNotification: false)
        }

        let senderName = profileStore.load().nickname
        let message = "\(senderName) 님이 ‘\(word.expression)’ 단어를 공부했어요. \(room.mateNickname) 님은 알고 있나요?"
        let result = await notifier.notifyPoke(receiverId: room.mateUserId, message: message, wordId: word.id)
        let toastMessage = result.isAuthorized ? "살짝 신호를 보냈어요." : "알림 권한이 없어 인앱으로만 알려요."

        return MatePokeOutcome(succeeded: true, message: toastMessage, didScheduleNotification: result.didSchedule)
    }

    func markInactivityPromptShown(now: Date = Date()) {
        userDefaults.set(DateKey.todayString(from: now), forKey: inactivityPromptKey)
    }

    private func selectPokeWord(level: JLPTLevel) async -> WordSummary? {
        do {
            let recommended = try dictionaryRepository.fetchRecommendedWords(level: level, limit: 9)
            if let word = recommended.randomElement() {
                return word
            }
            return try dictionaryRepository.randomWord(level: level)
        } catch {
            return nil
        }
    }

    private func isExpired(room: MateRoom, now: Date) -> Bool {
        guard let endDate = DateKey.date(fromISO: room.endDate) else { return false }
        return DateKey.startOfDay(for: now) >= DateKey.startOfDay(for: endDate)
    }

    private func inactivityInfo(room: MateRoom, now: Date) throws -> (shouldPrompt: Bool, days: Int) {
        guard room.status == .active else { return (false, 0) }
        let lastLearnedString = try repository.latestLearnedDate(userId: room.mateUserId)
        let fallbackDate = DateKey.date(fromISO: room.startDate)
        let lastDate: Date
        if let lastString = lastLearnedString,
           let parsed = DateKey.dayFormatter.date(from: lastString) {
            lastDate = parsed
        } else if let fallbackDate {
            lastDate = fallbackDate
        } else {
            return (false, 0)
        }
        let days = DateKey.daysBetween(lastDate, now)
        guard days >= 3 else { return (false, days) }

        let lastPrompt = userDefaults.string(forKey: inactivityPromptKey)
        if lastPrompt == DateKey.todayString(from: now) {
            return (false, days)
        }
        return (true, days)
    }
}

private extension DateKey {
    static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
