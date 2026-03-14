import Foundation
import Combine
import UIKit

enum MatchCelebration: Identifiable, Equatable {
    case connected(message: MatchCelebrationMessage, roomId: Int)

    var id: Int {
        switch self {
        case .connected(_, let roomId):
            return roomId
        }
    }
}

struct MateBannerMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct MateRoomCardItem: Identifiable, Equatable {
    let id: Int
    let counterpartUserId: String
    let counterpartRawUserId: String
    let counterpartBackendUserId: Int?
    let profile: MateUserProfile
    let lastInteractionText: String
    let extraInfoText: String
    let tikiTakaCount: Int?

    var counterpartLabel: String { profile.displayName }
    var jlptLevel: JLPTLevel { profile.jlptLevel }
    var resolvedTikiTakaCount: Int { max(tikiTakaCount ?? 0, 0) }
    var buddyStatusText: String {
        if resolvedTikiTakaCount > 0 {
            return "🔥 티키타카 \(resolvedTikiTakaCount)회"
        }
        return "티키타카 준비중"
    }

    var miniProfileTikiTakaText: String {
        "\(resolvedTikiTakaCount)회"
    }

    var previewItem: BuddyProfilePreviewItem {
        BuddyProfilePreviewItem(
            displayName: counterpartLabel,
            jlptLevel: jlptLevel,
            bio: profile.bio,
            instagramId: profile.instagramId,
            avatarData: profile.avatarData,
            detailTitle: "티키타카",
            detailValue: miniProfileTikiTakaText,
            detailIcon: "flame.fill"
        )
    }
}

struct IncomingBuddyRequestItem: Identifiable, Equatable {
    let id: Int
    let requestId: Int
    let displayName: String
    let jlptLevel: JLPTLevel
    let recentAccessText: String
    let bio: String
    let instagramId: String
    let avatarData: Data?

    var cardItem: BuddyDiscoveryCardItem {
        BuddyDiscoveryCardItem(
            id: "incoming-\(requestId)",
            kind: .incoming(requestId: requestId),
            displayName: displayName,
            jlptLevel: jlptLevel,
            recentAccessText: recentAccessText,
            bio: bio,
            instagramId: instagramId,
            avatarData: avatarData,
            primaryActionTitle: "수락",
            isPrimaryActionDisabled: false
        )
    }

    var previewItem: BuddyProfilePreviewItem {
        BuddyProfilePreviewItem(
            displayName: displayName,
            jlptLevel: jlptLevel,
            bio: bio,
            instagramId: instagramId,
            avatarData: avatarData,
            detailTitle: "최근 접속일",
            detailValue: recentAccessText,
            detailIcon: "clock.fill"
        )
    }
}

struct RandomCandidateItem: Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let displayName: String
    let jlptLevel: JLPTLevel
    let recentAccessText: String
    let bio: String
    let instagramId: String
    let avatarData: Data?
    let isPending: Bool

    var cardItem: BuddyDiscoveryCardItem {
        BuddyDiscoveryCardItem(
            id: "candidate-\(id)",
            kind: .randomCandidate(userId: userId),
            displayName: displayName,
            jlptLevel: jlptLevel,
            recentAccessText: recentAccessText,
            bio: bio,
            instagramId: instagramId,
            avatarData: avatarData,
            primaryActionTitle: isPending ? "신청 대기중" : "버디 신청",
            isPrimaryActionDisabled: isPending || userId == nil
        )
    }

    var previewItem: BuddyProfilePreviewItem {
        BuddyProfilePreviewItem(
            displayName: displayName,
            jlptLevel: jlptLevel,
            bio: bio,
            instagramId: instagramId,
            avatarData: avatarData,
            detailTitle: "최근 접속일",
            detailValue: recentAccessText,
            detailIcon: "clock.fill"
        )
    }
}

@MainActor
final class MateViewModel: ObservableObject {
    static let maxMateCount = 3

    @Published private(set) var connectedRoomCards: [MateRoomCardItem] = []
    @Published var inviteCode: String = ""
    @Published var inputInviteCode: String = ""
    @Published var inviteSectionErrorMessage: String?
    @Published private(set) var isBusy: Bool = false
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false
    @Published var matchCelebration: MatchCelebration?
    @Published private(set) var incomingRequests: [IncomingBuddyRequestItem] = []
    @Published private(set) var outgoingRequests: [BuddyRequestResponse] = []
    @Published private(set) var randomCandidates: [RandomCandidateItem] = []
    @Published private(set) var isRefreshingDiscoveryData: Bool = false
    @Published var bannerMessage: MateBannerMessage?
    @Published var discoveryErrorMessage: String?
    @Published var buddyListErrorMessage: String?

    private let settingsStore: AppSettingsStore
    private let userMetaProvider: MateUserMetaProvider
    private let buddyAPIService: BuddyAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []

    init(
        settingsStore: AppSettingsStore,
        userMetaProvider: MateUserMetaProvider? = nil,
        buddyAPIService: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.settingsStore = settingsStore
        self.userMetaProvider = userMetaProvider ?? DevMateUserMetaProvider(settingsStore: settingsStore)
        self.buddyAPIService = buddyAPIService

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

    var currentUserId: String {
        settingsStore.currentBackendUserId ?? settingsStore.mateUserId
    }

    var settingsStoreForBuddyDetail: AppSettingsStore {
        settingsStore
    }

    var canAddNewMate: Bool {
        connectedRoomCards.count < Self.maxMateCount
    }

    var incomingRequestCount: Int {
        incomingRequests.count
    }

    func onViewAppear() {
        load()
    }

    func onViewDisappear() { }

    func load() {
        guard let backendUserId = settingsStore.currentBackendUserId else {
            connectedRoomCards = []
            incomingRequests = []
            outgoingRequests = []
            randomCandidates = []
            inviteCode = ""
            inviteSectionErrorMessage = nil
            buddyListErrorMessage = nil
            discoveryErrorMessage = nil
            return
        }

        Task {
            await refreshAllData(userId: backendUserId)
        }
    }

    func fetchMyInviteCode() {
        guard let userId = settingsStore.currentBackendUserId else {
            inviteSectionErrorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        isBusy = true
        inviteSectionErrorMessage = nil

        Task {
            defer { isBusy = false }
            do {
                let response = try await buddyAPIService.fetchMyBuddyCode(userId: userId)
                inviteCode = response.buddyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            } catch {
                inviteSectionErrorMessage = "초대코드를 불러오지 못했어요"
            }
        }
    }

    func copyInviteCode() {
        guard inviteCode.isEmpty == false else { return }
        UIPasteboard.general.string = inviteCode
        showBanner("초대코드를 복사했어요")
    }

    func joinByInviteCode() {
        joinByInviteCode(inputInviteCode)
    }

    func joinByInviteCode(_ inviteCode: String) {
        guard let userId = settingsStore.currentBackendUserId else {
            inviteSectionErrorMessage = "현재 로그인 사용자 ID를 확인하지 못했어요."
            return
        }

        let trimmed = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.isEmpty == false else {
            inviteSectionErrorMessage = "초대 코드를 입력해 주세요."
            return
        }

        isBusy = true
        inviteSectionErrorMessage = nil

        Task {
            defer { isBusy = false }
            do {
                _ = try await buddyAPIService.connectBuddy(userId: userId, buddyCode: trimmed)
                print("[Buddy] connect success -> refresh")
                inputInviteCode = ""
                showBanner("새 버디가 연결되었어요!")
                await refreshAllData(userId: userId)
            } catch {
                inviteSectionErrorMessage = error.localizedDescription
            }
        }
    }

    func deleteBuddy(_ item: MateRoomCardItem) {
        guard let userId = settingsStore.currentBackendUserId,
              let buddyId = item.counterpartBackendUserId else {
            alertMessage = "삭제할 버디 정보를 확인하지 못했어요."
            isShowingAlert = true
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await buddyAPIService.deleteBuddy(userId: userId, buddyUserId: buddyId)
                print("[Buddy] delete success -> refresh")
                showBanner("버디 연결을 종료했어요.")
                await refreshAllData(userId: userId, shouldRefreshIncoming: false)
            } catch {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
    }

    func refreshRandomCandidates() {
        Task {
            guard let userId = settingsStore.currentBackendUserId else { return }
            await refreshDiscoveryData(userId: userId, shouldRefreshIncoming: false)
        }
    }

    func sendBuddyRequest(to candidate: RandomCandidateItem) {
        if outgoingRequests.count >= 3 {
            alertMessage = "현재 대기 중인 신청이 3개예요. 응답을 기다려주세요."
            isShowingAlert = true
            return
        }

        guard let myUserId = settingsStore.currentBackendUserId,
              let receiverId = candidate.userId else {
            alertMessage = "현재 로그인 사용자 정보를 확인하지 못했어요."
            isShowingAlert = true
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await buddyAPIService.createBuddyRequest(
                    requesterId: myUserId,
                    receiverId: String(receiverId)
                )
                showBanner("버디 신청을 보냈어요")
                await refreshDiscoveryData(userId: myUserId, shouldRefreshIncoming: false)
            } catch {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
    }

    func acceptIncomingRequest(_ item: IncomingBuddyRequestItem) {
        guard let userId = settingsStore.currentBackendUserId else {
            alertMessage = "현재 로그인 사용자 정보를 확인하지 못했어요."
            isShowingAlert = true
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await buddyAPIService.acceptBuddyRequest(requestId: item.requestId)
                showBanner("새 버디가 연결되었어요!")
                await refreshAllData(userId: userId)
            } catch {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
    }

    func rejectIncomingRequest(_ item: IncomingBuddyRequestItem) {
        guard let userId = settingsStore.currentBackendUserId else {
            alertMessage = "현재 로그인 사용자 정보를 확인하지 못했어요."
            isShowingAlert = true
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                _ = try await buddyAPIService.rejectBuddyRequest(requestId: item.requestId)
                showBanner("버디 신청을 거절했어요")
                await refreshDiscoveryData(userId: userId)
            } catch {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
    }

    private func refreshAllData(userId: String, shouldRefreshIncoming: Bool = true) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.refreshBuddyList(userId: userId)
            }
            group.addTask { [weak self] in
                await self?.refreshDiscoveryData(userId: userId, shouldRefreshIncoming: shouldRefreshIncoming)
            }
        }
    }

    private func refreshBuddyList(userId: String) async {
        do {
            let buddies = try await buddyAPIService.fetchBuddies(userId: userId)
            print("[Buddy] fetched server buddies count=\(buddies.count)")
            connectedRoomCards = buddies.map(makeMateRoomCardItem)
            buddyListErrorMessage = nil
        } catch {
            connectedRoomCards = []
            buddyListErrorMessage = error.localizedDescription
        }
    }

    private func refreshDiscoveryData(userId: String, shouldRefreshIncoming: Bool = true) async {
        isRefreshingDiscoveryData = true
        defer { isRefreshingDiscoveryData = false }

        do {
            async let incomingTask: [BuddyRequestResponse] = shouldRefreshIncoming
                ? buddyAPIService.fetchIncomingBuddyRequests(userId: userId)
                : []
            async let outgoingTask = buddyAPIService.fetchOutgoingBuddyRequests(userId: userId)
            async let candidatesTask = buddyAPIService.fetchRandomCandidates(userId: userId)

            let incomingResponses = try await incomingTask
            let outgoingResponses = try await outgoingTask
            let candidateResponses = try await candidatesTask
            let pendingOutgoingIds = Set(outgoingResponses.compactMap { $0.receiverId })

            if shouldRefreshIncoming {
                incomingRequests = incomingResponses.map(makeIncomingRequestItem)
            }
            outgoingRequests = outgoingResponses
            randomCandidates = candidateResponses.map { makeRandomCandidateItem(from: $0, pendingOutgoingIds: pendingOutgoingIds) }
            discoveryErrorMessage = nil
        } catch {
            if shouldRefreshIncoming {
                incomingRequests = []
            }
            outgoingRequests = []
            randomCandidates = []
            discoveryErrorMessage = error.localizedDescription
        }
    }

    private func makeMateRoomCardItem(from summary: BuddySummaryResponse) -> MateRoomCardItem {
        let backendBuddyId = summary.buddyUserId
        let profileUserId = backendBuddyId.map(String.init) ?? ""
        let fallbackProfile = userMetaProvider.profile(for: profileUserId)

        let resolvedDisplayName = resolvedBuddyText(
            serverValue: summary.buddyNickname,
            fallbackValue: fallbackProfile.displayName,
            placeholder: "이름 미정",
            fieldName: "nickname",
            buddyUserId: backendBuddyId
        )
        let resolvedBio = resolvedBuddyText(
            serverValue: summary.buddyBio,
            fallbackValue: fallbackProfile.bio,
            placeholder: "",
            fieldName: "bio",
            buddyUserId: backendBuddyId
        )
        let resolvedInstagramId = resolvedBuddyText(
            serverValue: summary.buddyInstagramId,
            fallbackValue: fallbackProfile.instagramId,
            placeholder: "",
            fieldName: "instagramId",
            buddyUserId: backendBuddyId
        )
        let resolvedLevel = resolvedBuddyLevel(
            serverValue: summary.buddyLearningLevel,
            fallbackValue: fallbackProfile.jlptLevel,
            buddyUserId: backendBuddyId
        ) ?? .n5

        let resolvedProfile = MateUserProfile(
            userId: profileUserId,
            displayName: resolvedDisplayName,
            bio: resolvedBio,
            instagramId: resolvedInstagramId,
            jlptLevel: resolvedLevel,
            avatarData: decodeAvatarData(from: summary.avatarBase64) ?? fallbackProfile.avatarData
        )

        let mapped = MateRoomCardItem(
            id: summary.id,
            counterpartUserId: backendBuddyId.map(String.init) ?? "",
            counterpartRawUserId: backendBuddyId.map(String.init) ?? "",
            counterpartBackendUserId: backendBuddyId,
            profile: resolvedProfile,
            lastInteractionText: recentAccessText(from: summary.lastActiveAt),
            extraInfoText: tikiTakaStatusText(for: summary.tikiTakaCount),
            tikiTakaCount: summary.tikiTakaCount
        )

        print(
            "[Buddy] mapped card backendBuddyUserId=\(backendBuddyId.map(String.init) ?? "nil") " +
            "nickname=\(mapped.counterpartLabel) tikiTakaCount=\(mapped.resolvedTikiTakaCount)"
        )
        return mapped
    }

    private func makeIncomingRequestItem(from response: BuddyRequestResponse) -> IncomingBuddyRequestItem {
        print("[Buddy] using server request profile requestId=\(response.requestId) nickname=\(response.nickname)")
        return IncomingBuddyRequestItem(
            id: response.id,
            requestId: response.requestId,
            displayName: response.nickname,
            jlptLevel: response.jlptLevel,
            recentAccessText: recentAccessText(from: response.lastActiveAt),
            bio: response.bio,
            instagramId: response.instagramId,
            avatarData: decodeAvatarData(from: response.avatarBase64)
        )
    }

    private func makeRandomCandidateItem(from response: RandomCandidateResponse, pendingOutgoingIds: Set<Int>) -> RandomCandidateItem {
        print("[Buddy] using server candidate profile userId=\(response.userId.map(String.init) ?? "nil") nickname=\(response.nickname)")
        return RandomCandidateItem(
            id: response.id,
            userId: response.userId,
            displayName: response.nickname,
            jlptLevel: response.jlptLevel,
            recentAccessText: recentAccessText(from: response.lastActiveAt),
            bio: response.bio,
            instagramId: response.instagramId,
            avatarData: decodeAvatarData(from: response.avatarBase64),
            isPending: response.userId.map(pendingOutgoingIds.contains) ?? false
        )
    }

    private func recentAccessText(from rawValue: String?) -> String {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.isEmpty == false else {
            return "최근 접속일 정보 없음"
        }

        if let date = ISO8601DateFormatter.fractionalOrInternet.date(from: rawValue) {
            let days = DateKey.daysBetweenKST(from: date, to: Date())
            if days <= 0 {
                return "최근 접속 오늘"
            }
            return "최근 접속 \(days)일 전"
        }

        return "최근 접속 \(rawValue)"
    }

    private func tikiTakaStatusText(for count: Int?) -> String {
        let resolvedCount = max(count ?? 0, 0)
        if resolvedCount > 0 {
            return "🔥 티키타카 \(resolvedCount)회"
        }
        return "티키타카 준비중"
    }

    private func decodeAvatarData(from base64: String?) -> Data? {
        guard let base64 = base64?.trimmingCharacters(in: .whitespacesAndNewlines),
              base64.isEmpty == false else {
            return nil
        }
        return Data(base64Encoded: base64)
    }

    private func showBanner(_ message: String) {
        bannerMessage = MateBannerMessage(text: message)
    }

    private func resolvedBuddyText(
        serverValue: String?,
        fallbackValue: String,
        placeholder: String,
        fieldName: String,
        buddyUserId: Int?
    ) -> String {
        if let serverValue = trimmedNonEmpty(serverValue) {
            print("[Buddy] using server \(fieldName) for buddyUserId=\(buddyUserId.map(String.init) ?? "nil") value=\(serverValue)")
            return serverValue
        }

        if let fallbackValue = trimmedNonEmpty(fallbackValue) {
            print("[Buddy] fallback to local \(fieldName) for buddyUserId=\(buddyUserId.map(String.init) ?? "nil")")
            return fallbackValue
        }

        print("[Buddy] using placeholder \(fieldName) for buddyUserId=\(buddyUserId.map(String.init) ?? "nil")")
        return placeholder
    }

    private func resolvedBuddyLevel(
        serverValue: JLPTLevel?,
        fallbackValue: JLPTLevel,
        buddyUserId: Int?
    ) -> JLPTLevel? {
        if let serverValue {
            print("[Buddy] using server learningLevel for buddyUserId=\(buddyUserId.map(String.init) ?? "nil")")
            return serverValue
        }

        print("[Buddy] fallback to local learningLevel for buddyUserId=\(buddyUserId.map(String.init) ?? "nil")")
        return fallbackValue
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}

private extension ISO8601DateFormatter {
    static let fractionalOrInternet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
