import Foundation
import Combine

@MainActor
final class BuddyDetailViewModel: ObservableObject {
    @Published private(set) var items: [BuddyWordItemUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published private(set) var targetDateText: String = ""
    @Published private(set) var sentCount: Int = 0
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var receivedCount: Int = 0
    @Published var errorMessage: String?
    @Published var sendSuccessMessage: String?

    let buddyId: String
    let buddyName: String

    private let service: BuddyAPIServiceProtocol
    private let settingsStore: AppSettingsStore
    private var selectedItemId: Int?
    private var dailyWordsResponse: DailyWordsTodayResponse?
    private var tsunTsunTodayResponse: TsunTsunTodayResponse?

    init(
        buddyId: String,
        buddyName: String,
        settingsStore: AppSettingsStore,
        service: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.buddyId = buddyId
        self.buddyName = buddyName
        self.settingsStore = settingsStore
        self.service = service
        print("[BuddyDetail] init currentLoginUser=\(settingsStore.mateUserId) myUserId=\(resolvedMyUserId ?? "<nil>") buddyId=\(buddyId) buddyName=\(buddyName)")
    }

    var selectedItem: BuddyWordItemUIModel? {
        items.first(where: { $0.dailyWordItemId == selectedItemId })
    }

    var canSendSelectedItem: Bool {
        selectedItem != nil && isSending == false
    }

    func load() {
        guard isLoading == false else { return }
        guard let myUserId = resolvedMyUserId else {
            items = []
            totalCount = 0
            sentCount = 0
            receivedCount = 0
            targetDateText = ""
            errorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }
        isLoading = true
        errorMessage = nil
        print("[BuddyDetail] load currentLoginUser=\(settingsStore.mateUserId) myUserId=\(myUserId) buddyId=\(buddyId) buddyName=\(buddyName)")

        Task {
            do {
                async let dailyWordsTask = service.fetchDailyWords(userId: myUserId)
                async let tsunTsunTask = service.fetchTsunTsunToday(userId: myUserId, buddyId: buddyId)

                let (dailyWords, tsunTsunToday) = try await (dailyWordsTask, tsunTsunTask)
                apply(dailyWords: dailyWords, tsunTsunToday: tsunTsunToday)
                isLoading = false
            } catch {
                items = []
                totalCount = 0
                sentCount = 0
                receivedCount = 0
                targetDateText = ""
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func selectItem(_ item: BuddyWordItemUIModel) {
        guard item.isSelectable else { return }

        if selectedItemId == item.dailyWordItemId {
            selectedItemId = nil
        } else {
            selectedItemId = item.dailyWordItemId
        }

        rebuildItems()
    }

    func sendTsunTsun() {
        guard let selectedItem else { return }
        guard isSending == false else { return }
        guard let myUserId = resolvedMyUserId else {
            errorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        isSending = true
        errorMessage = nil
        sendSuccessMessage = nil

        Task {
            do {
                _ = try await service.sendTsunTsun(
                    senderId: myUserId,
                    receiverId: buddyId,
                    dailyWordItemId: selectedItem.dailyWordItemId
                )
                selectedItemId = nil
                sendSuccessMessage = "つんつん을 보냈어요."
                await refreshTsunTsunStatus()
                isSending = false
            } catch {
                errorMessage = error.localizedDescription
                isSending = false
            }
        }
    }

    func refreshTsunTsunStatus() async {
        guard let myUserId = resolvedMyUserId else {
            errorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        do {
            let tsunTsunToday = try await service.fetchTsunTsunToday(userId: myUserId, buddyId: buddyId)
            tsunTsunTodayResponse = tsunTsunToday
            sentCount = tsunTsunToday.sentCount
            receivedCount = tsunTsunToday.receivedCount
            if targetDateText.isEmpty {
                targetDateText = tsunTsunToday.targetDate
            }
            rebuildItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var resolvedMyUserId: String? {
        settingsStore.currentBackendUserId
    }

    private func apply(dailyWords: DailyWordsTodayResponse, tsunTsunToday: TsunTsunTodayResponse) {
        dailyWordsResponse = dailyWords
        tsunTsunTodayResponse = tsunTsunToday
        targetDateText = tsunTsunToday.targetDate
        sentCount = tsunTsunToday.sentCount
        receivedCount = tsunTsunToday.receivedCount
        totalCount = dailyWords.items.count
        rebuildItems()
    }

    private func rebuildItems() {
        guard let dailyWordsResponse else {
            items = []
            totalCount = 0
            return
        }

        items = BuddyWordItemUIModel.merge(
            dailyWords: dailyWordsResponse.items,
            statuses: tsunTsunTodayResponse?.items ?? [],
            selectedItemId: selectedItemId
        )

        if let selectedItem = items.first(where: { $0.dailyWordItemId == selectedItemId }),
           selectedItem.isSelectable == false {
            selectedItemId = nil
        }

        if items.contains(where: { $0.dailyWordItemId == selectedItemId }) == false {
            selectedItemId = nil
            items = items.map { item in
                var updated = item
                updated.isSelected = false
                return updated
            }
        }

        totalCount = items.count
    }
}
