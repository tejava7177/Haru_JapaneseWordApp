import Foundation
import Combine

@MainActor
final class BuddyDetailViewModel: ObservableObject {
    struct UserAlert: Equatable {
        let title: String
        let message: String
    }

    @Published private(set) var items: [BuddyWordItemUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published private(set) var targetDateText: String = ""
    @Published private(set) var sentCount: Int = 0
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var receivedCount: Int = 0
    @Published var errorMessage: String?
    @Published var sendSuccessMessage: String?
    @Published var nonFatalMessage: String?
    @Published var userAlert: UserAlert?

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
        selectedItem != nil && isSending == false && hasPendingOutgoingAnswer == false
    }

    var hasPendingOutgoingAnswer: Bool {
        items.contains { $0.direction == .sent && $0.status == .sent }
    }

    var pendingAnswerMessage: String? {
        guard hasPendingOutgoingAnswer else { return nil }
        return "상대가 아직 답변 중이에요"
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
        let dailyWordsUserId = buddyId
        let tsunTsunUserId = myUserId
        let tsunTsunBuddyId = buddyId

        isLoading = true
        errorMessage = nil
        nonFatalMessage = nil
        print("[BuddyDetail] currentLoginUser=\(settingsStore.mateUserId) myUserId=\(myUserId) buddyId=\(buddyId) buddyName=\(buddyName)")
        print("[BuddyDetail] dailyWordsRequestUserId=\(dailyWordsUserId)")
        print("[BuddyDetail] tsuntsunTodayRequest userId=\(tsunTsunUserId) buddyId=\(tsunTsunBuddyId)")

        Task {
            do {
                let dailyWords = try await service.fetchDailyWords(userId: dailyWordsUserId)

                do {
                    let tsunTsunToday = try await service.fetchTsunTsunToday(
                        userId: tsunTsunUserId,
                        buddyId: tsunTsunBuddyId
                    )
                    apply(dailyWords: dailyWords, tsunTsunToday: tsunTsunToday)
                } catch {
                    logTsunTsunFailure(error, userId: tsunTsunUserId, buddyId: tsunTsunBuddyId)
                    applyFallback(dailyWords: dailyWords)
                }
                isLoading = false
            } catch {
                items = []
                totalCount = 0
                sentCount = 0
                receivedCount = 0
                targetDateText = ""
                nonFatalMessage = nil
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
        if hasPendingOutgoingAnswer {
            userAlert = waitingForBuddyAlert()
            return
        }

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
                if let alert = userAlert(for: error) {
                    userAlert = alert
                } else {
                    errorMessage = error.localizedDescription
                }
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
            nonFatalMessage = nil
            rebuildItems()
        } catch {
            logTsunTsunFailure(error, userId: myUserId, buddyId: buddyId)
            sentCount = 0
            receivedCount = 0
            tsunTsunTodayResponse = nil
            nonFatalMessage = "층츤 상태를 불러오지 못해 기본 상태로 표시했어요."
            rebuildItems()
        }
    }

    private var resolvedMyUserId: String? {
        settingsStore.currentBackendUserId
    }

    private func apply(dailyWords: DailyWordsTodayResponse, tsunTsunToday: TsunTsunTodayResponse) {
        dailyWordsResponse = dailyWords
        tsunTsunTodayResponse = tsunTsunToday
        targetDateText = dailyWords.targetDate
        sentCount = tsunTsunToday.sentCount
        receivedCount = tsunTsunToday.receivedCount
        totalCount = dailyWords.items.count
        nonFatalMessage = nil
        rebuildItems()
    }

    private func applyFallback(dailyWords: DailyWordsTodayResponse) {
        dailyWordsResponse = dailyWords
        tsunTsunTodayResponse = nil
        targetDateText = dailyWords.targetDate
        sentCount = 0
        receivedCount = 0
        totalCount = dailyWords.items.count
        nonFatalMessage = "층츤 상태를 불러오지 못해 기본 상태로 표시했어요."
        print("[BuddyDetail] tsuntsun fallback applied sentCount=0 receivedCount=0 status=NONE")
        rebuildItems()
    }

    private func logTsunTsunFailure(_ error: Error, userId: String, buddyId: String) {
        switch error {
        case APIError.server(let statusCode, let message):
            print("[BuddyDetail] tsuntsun today failed userId=\(userId) buddyId=\(buddyId) status=\(statusCode) body=\(message ?? "<empty>")")
        case APIError.decodingFailed(let underlyingError):
            print("[BuddyDetail] tsuntsun today decoding failed userId=\(userId) buddyId=\(buddyId) error=\(underlyingError)")
        case APIError.requestFailed(let underlyingError):
            print("[BuddyDetail] tsuntsun today request failed userId=\(userId) buddyId=\(buddyId) error=\(underlyingError)")
        default:
            print("[BuddyDetail] tsuntsun today failed userId=\(userId) buddyId=\(buddyId) error=\(error.localizedDescription)")
        }
    }

    private func userAlert(for error: Error) -> UserAlert? {
        switch error {
        case APIError.server(let statusCode, let message):
            let normalized = (message ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if statusCode == 400 && (
                normalized.contains("already sent")
                || normalized.contains("not answered")
                || normalized.contains("waiting answer")
                || normalized.contains("waiting for answer")
            ) {
                return waitingForBuddyAlert()
            }

            if statusCode == 400, normalized.isEmpty || normalized == "bad request" {
                return waitingForBuddyAlert()
            }

            return nil
        default:
            return nil
        }
    }

    private func waitingForBuddyAlert() -> UserAlert {
        UserAlert(
            title: "잠시 기다려주세요",
            message: "아직 \(buddyName)이 츤츤에 답하지 않았어요.\n답변 후 다음 츤츤을 보낼 수 있어요."
        )
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
