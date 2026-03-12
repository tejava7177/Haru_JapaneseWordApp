import Foundation
import Combine

@MainActor
final class TsunTsunInboxViewModel: ObservableObject {
    @Published private(set) var items: [TsunTsunInboxItemResponse] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let settingsStore: AppSettingsStore
    private let service: BuddyAPIServiceProtocol

    init(
        settingsStore: AppSettingsStore,
        service: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.settingsStore = settingsStore
        self.service = service
    }

    var unansweredCountText: String {
        "미답변 \(items.count)개"
    }

    func load() {
        guard isLoading == false else { return }
        guard let userId = settingsStore.currentBackendUserId else {
            items = []
            errorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await service.fetchTsunTsunInbox(userId: userId)
                items = response.items.sorted(by: TsunTsunInboxItemResponse.sortForInbox)
                isLoading = false
            } catch {
                items = []
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func removeAnsweredItem(tsuntsunId: Int) {
        items.removeAll { $0.tsuntsunId == tsuntsunId }
    }
}
