import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var deckWordIds: [Int] = []
    @Published var cards: [WordSummary] = []
    @Published var selectedIndex: Int = 0
    @Published private var checkedWordIds: Set<Int> = []
    @Published var todayLyric: LyricEntry?
    @Published var lyricWordId: Int?
    @Published var hasError: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var debugError: String?
    @Published private(set) var targetDateText: String = ""
    @Published private(set) var tsunTsunInboxSummary: TsunTsunInboxSummary?

    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore
    private let lyricRepository: LyricRepository
    private let homeAPIService: HomeAPIServiceProtocol
    private let buddyAPIService: BuddyAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var hasLoadedDeck: Bool = false
    private var lastDeckLoadKey: String?
    private var isLoadingDeck: Bool = false
    private var hasLoadedInbox: Bool = false
    private var lastInboxLoadUserId: String?
    private var isLoadingInbox: Bool = false
    private var refreshTask: Task<Void, Never>?
    private var pendingForcedRefresh: Bool = false
    private var pendingForcedRefreshBypassesThrottle: Bool = false
    private var lastRefreshAt: Date?
    private let minimumRefreshInterval: TimeInterval = 3

    init(
        repository: DictionaryRepository,
        settingsStore: AppSettingsStore,
        homeAPIService: HomeAPIServiceProtocol = HomeAPIService(),
        buddyAPIService: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.repository = repository
        self.settingsStore = settingsStore
        self.lyricRepository = LyricRepository()
        self.homeAPIService = homeAPIService
        self.buddyAPIService = buddyAPIService

        settingsStore.$settings
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck(triggerSource: "onChange")
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .dailyWordsDidRegenerate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadDeck(triggerSource: "notification", force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .tsunTsunInboxDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadInboxSummary(triggerSource: "notification", force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .buddyPetalStatusDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let trigger = BuddyPushPayload.trigger(from: notification.userInfo) ?? .pushForeground
                self?.requestImmediateRefresh(trigger: trigger)
            }
            .store(in: &cancellables)
    }

    func loadDeck(triggerSource: String = "manual", force: Bool = false) {
        refreshHomeContent(triggerSource: triggerSource, force: force)
    }

    func refreshDeckIfNeeded(triggerSource: String) {
        let currentLoadKey = makeDeckLoadKey()
        let shouldForceReload = hasLoadedDeck && lastDeckLoadKey != currentLoadKey
        refreshHomeContent(triggerSource: triggerSource, force: shouldForceReload)
    }

    func loadInboxSummary(triggerSource: String = "manual", force: Bool = false) {
        refreshHomeContent(triggerSource: triggerSource, force: force)
    }

    func onSceneDidBecomeActive() {
        requestImmediateRefresh(trigger: .sceneActive)
    }

    func manualRefresh() async {
        print("[Home] home manual refresh started")
        requestImmediateRefresh(source: "manualPullToRefresh")
        await waitForRefreshCompletion(source: "manualPullToRefresh")
        print("[Home] home manual refresh completed")
    }

    private func loadDeckFromPrimarySource() async {
        hasError = false
        errorMessage = nil
        debugError = nil

        do {
            todayLyric = try lyricRepository.getTodayLyric()
            lyricWordId = nil

            if let currentUserId = settingsStore.currentBackendUserId {
                let response = try await homeAPIService.fetchTodayDailyWords(userId: currentUserId)
                let finalCards = try response.items
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map(makeWordSummary(from:))

                targetDateText = response.targetDate
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
            } else {
                let finalCards = try loadFallbackRecommendedWords()
                targetDateText = ""
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
                errorMessage = "로그인 전에는 로컬 추천 단어를 보여드려요."
                debugError = "DailyWord API userId unavailable. Falling back to local recommendations."
            }

            selectedIndex = 0
            checkedWordIds = try repository.fetchCheckedStates(wordIds: deckWordIds)

            if cards.isEmpty {
                hasError = true
            }
        } catch {
            do {
                let finalCards = try loadFallbackRecommendedWords()
                targetDateText = ""
                cards = finalCards
                deckWordIds = finalCards.map { $0.id }
                selectedIndex = 0
                checkedWordIds = try repository.fetchCheckedStates(wordIds: deckWordIds)
                errorMessage = "서버 연결이 불안정해 로컬 추천 단어를 대신 보여드려요."
                debugError = "DailyWord API failed, fallback applied: \(error)"
                hasError = finalCards.isEmpty
            } catch {
                hasError = true
                errorMessage = "오늘의 추천 단어를 불러오지 못했어요."
                debugError = String(describing: error)
                cards = []
                deckWordIds = []
                selectedIndex = 0
                targetDateText = ""
            }
        }
    }

    private func loadInboxSummaryFromPrimarySource(force: Bool = false) async {
        guard let currentUserId = settingsStore.currentBackendUserId else {
            tsunTsunInboxSummary = nil
            lastInboxLoadUserId = nil
            hasLoadedInbox = false
            return
        }

        if force == false, hasLoadedInbox, lastInboxLoadUserId == currentUserId {
            return
        }

        lastInboxLoadUserId = currentUserId

        do {
            let response = try await buddyAPIService.fetchTsunTsunInbox(userId: currentUserId)
            tsunTsunInboxSummary = TsunTsunInboxSummary.fromInbox(response) { [weak self] item in
                self?.resolveDisplayName(for: item.senderId, fallbackSenderName: item.senderName) ?? item.senderName
            }
        } catch {
            tsunTsunInboxSummary = nil
            #if DEBUG
            debugError = [debugError, "TsunTsun inbox unavailable: \(error)"]
                .compactMap { $0 }
                .joined(separator: "\n")
            #endif
        }
    }

    func isExcluded(_ wordId: Int) -> Bool {
        checkedWordIds.contains(wordId)
    }

    func toggleExcluded(wordId: Int) {
        let checked = isExcluded(wordId) == false
        do {
            try repository.setChecked(wordId: wordId, checked: checked)
            if checked {
                checkedWordIds.insert(wordId)
            } else {
                checkedWordIds.remove(wordId)
            }
        } catch {
            debugError = String(describing: error)
        }
    }

    private func makeWordSummary(from item: DailyWordsTodayItemResponse) throws -> WordSummary {
        if let summary = try repository.fetchWordSummary(wordId: item.wordId) {
            return summary
        }

        return WordSummary(
            id: item.wordId,
            level: JLPTLevel(rawValue: item.level) ?? .n5,
            expression: item.expression,
            reading: item.reading,
            meanings: ""
        )
    }

    private func loadFallbackRecommendedWords() throws -> [WordSummary] {
        let currentLevel = settingsStore.settings.homeDeckLevel
        return try repository.fetchRecommendedWords(level: currentLevel, limit: 10)
    }

    private func resolveDisplayName(for senderId: Int?, fallbackSenderName: String) -> String {
        if let localDisplayName = settingsStore.preferredDisplayName(forBackendUserId: senderId),
           localDisplayName.isEmpty == false {
            return localDisplayName
        }

        let trimmedFallback = fallbackSenderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFallback.isEmpty == false {
            return trimmedFallback
        }

        return "버디"
    }

    private func makeDeckLoadKey() -> String {
        let todayKey = DateKey.kstDailyWordsKey(from: Date())
        if let backendUserId = settingsStore.currentBackendUserId {
            return "server:\(backendUserId):\(todayKey)"
        }
        return "local:\(settingsStore.settings.homeDeckLevel.rawValue):\(todayKey)"
    }

    private func refreshHomeContent(triggerSource: String, force: Bool = false, bypassThrottle: Bool = false) {
        print("[Home] refresh requested source=\(triggerSource) force=\(force) bypassThrottle=\(bypassThrottle)")
        let loadKey = makeDeckLoadKey()
        let userId = settingsStore.currentBackendUserId

        if refreshTask != nil {
            if force {
                pendingForcedRefresh = true
                pendingForcedRefreshBypassesThrottle = pendingForcedRefreshBypassesThrottle || bypassThrottle
                print("[Home] home pending refresh queued source=\(triggerSource)")
            } else {
                print("[Home] refresh skipped in-flight source=\(triggerSource)")
            }
            return
        }

        if force,
           bypassThrottle == false,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < minimumRefreshInterval {
            print("[Home] refresh throttled source=\(triggerSource)")
            return
        }

        if force == false,
           hasLoadedDeck,
           lastDeckLoadKey == loadKey,
           hasLoadedInbox,
           lastInboxLoadUserId == userId {
            print("[Home] fetch skipped already loaded source=\(triggerSource)")
            return
        }

        lastDeckLoadKey = loadKey
        lastInboxLoadUserId = userId
        isLoading = true
        isLoadingDeck = true
        isLoadingInbox = true
        if force {
            print("[Home] force refresh executed source=\(triggerSource) bypassThrottle=\(bypassThrottle)")
        }
        print("[Home] refresh started source=\(triggerSource)")

        refreshTask = Task { [weak self] in
            guard let self else { return }
            async let deckLoad: Void = self.loadDeckFromPrimarySource()
            async let inboxLoad: Void = self.loadInboxSummaryFromPrimarySource(force: true)
            _ = await (deckLoad, inboxLoad)

            self.isLoadingDeck = false
            self.isLoadingInbox = false
            self.isLoading = false
            self.hasLoadedDeck = true
            self.hasLoadedInbox = self.settingsStore.currentBackendUserId != nil
            self.lastRefreshAt = Date()
            self.refreshTask = nil
            print("[Home] refresh completed source=\(triggerSource)")

            if self.pendingForcedRefresh {
                let shouldBypassThrottle = self.pendingForcedRefreshBypassesThrottle
                self.pendingForcedRefresh = false
                self.pendingForcedRefreshBypassesThrottle = false
                print("[Home] home pending refresh executed source=pendingForcedRefresh")
                self.refreshHomeContent(
                    triggerSource: "pendingForcedRefresh",
                    force: true,
                    bypassThrottle: shouldBypassThrottle
                )
            }
        }
    }

    private func requestImmediateRefresh(trigger: BuddyPetalStatusChangeTrigger) {
        print("[Home] home refresh trigger=\(trigger.rawValue)")
        requestImmediateRefresh(source: trigger.rawValue)
    }

    private func requestImmediateRefresh(source: String) {
        refreshHomeContent(
            triggerSource: source,
            force: true,
            bypassThrottle: true
        )
    }

    private func waitForRefreshCompletion(source: String) async {
        while refreshTask != nil || pendingForcedRefresh {
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        print("[Home] refresh wait completed source=\(source)")
    }
}
