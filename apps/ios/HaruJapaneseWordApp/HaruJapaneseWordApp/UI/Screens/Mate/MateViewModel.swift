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

private struct BuddyServerProfile: Equatable {
    let userId: Int
    let nickname: String?
    let jlptLevel: JLPTLevel?
    let bio: String?
    let instagramId: String?
    let profileImageUrl: String?
    let avatarData: Data?
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
            profileImageUrl: profile.profileImageUrl,
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
    let requesterId: Int?
    let displayName: String
    let jlptLevel: JLPTLevel
    let recentAccessText: String
    let bio: String
    let instagramId: String
    let profileImageUrl: String?
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
            profileImageUrl: profileImageUrl,
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
            profileImageUrl: profileImageUrl,
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
    let profileImageUrl: String?
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
            profileImageUrl: profileImageUrl,
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
            profileImageUrl: profileImageUrl,
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
    @Published private(set) var currentRandomCandidateIndex: Int = 0
    @Published private(set) var isRefreshingDiscoveryData: Bool = false
    @Published private(set) var isRefreshingCandidate: Bool = false
    @Published var bannerMessage: MateBannerMessage?
    @Published var discoveryErrorMessage: String?
    @Published var buddyListErrorMessage: String?

    private let settingsStore: AppSettingsStore
    private let userMetaProvider: MateUserMetaProvider
    private let buddyAPIService: BuddyAPIServiceProtocol
    private let profileAPIService: ProfileAPIServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var hasLoadedBuddyData: Bool = false
    private var hasLoadedRandomCandidates: Bool = false
    private var lastLoadedBackendUserId: String?
    private var isLoadingBuddyData: Bool = false
    private var serverProfileByUserId: [Int: BuddyServerProfile] = [:]

    init(
        settingsStore: AppSettingsStore,
        userMetaProvider: MateUserMetaProvider? = nil,
        buddyAPIService: BuddyAPIServiceProtocol = BuddyAPIService(),
        profileAPIService: ProfileAPIServiceProtocol = ProfileAPIService()
    ) {
        self.settingsStore = settingsStore
        self.userMetaProvider = userMetaProvider ?? DevMateUserMetaProvider(settingsStore: settingsStore)
        self.buddyAPIService = buddyAPIService
        self.profileAPIService = profileAPIService

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load(triggerSource: "onChange")
            }
            .store(in: &cancellables)

        settingsStore.$profileRefreshTick
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load(triggerSource: "profileRefresh", force: true)
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

    var currentRandomCandidate: RandomCandidateItem? {
        guard randomCandidates.indices.contains(currentRandomCandidateIndex) else {
            return nil
        }
        return randomCandidates[currentRandomCandidateIndex]
    }

    func onViewAppear() {
        load(triggerSource: "onAppear")
    }

    func onViewDisappear() { }

    func load(triggerSource: String = "manual", force: Bool = false) {
        print("[Buddy] trigger source=\(triggerSource)")
        guard let backendUserId = settingsStore.currentBackendUserId else {
            connectedRoomCards = []
            incomingRequests = []
            outgoingRequests = []
            randomCandidates = []
            currentRandomCandidateIndex = 0
            isRefreshingCandidate = false
            inviteCode = ""
            inviteSectionErrorMessage = nil
            buddyListErrorMessage = nil
            discoveryErrorMessage = nil
            hasLoadedBuddyData = false
            hasLoadedRandomCandidates = false
            lastLoadedBackendUserId = nil
            isLoadingBuddyData = false
            serverProfileByUserId = [:]
            return
        }

        if lastLoadedBackendUserId != backendUserId {
            hasLoadedRandomCandidates = false
            randomCandidates = []
            currentRandomCandidateIndex = 0
        }

        if isLoadingBuddyData, force == false {
            print("[Buddy] fetch skipped already loaded")
            return
        }

        if force == false, hasLoadedBuddyData, lastLoadedBackendUserId == backendUserId {
            print("[Buddy] fetch skipped already loaded")
            Task {
                await loadRandomCandidatesIfNeeded(userId: backendUserId)
            }
            return
        }

        isLoadingBuddyData = true
        lastLoadedBackendUserId = backendUserId
        Task {
            await refreshAllData(userId: backendUserId)
            await loadRandomCandidatesIfNeeded(userId: backendUserId)
            self.isLoadingBuddyData = false
            self.hasLoadedBuddyData = true
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

    func refreshRandomCandidates() async {
        guard let userId = settingsStore.currentBackendUserId else { return }
        guard isRefreshingCandidate == false else { return }

        if randomCandidates.count <= 1 {
            print("[Buddy] refresh animation finished -> start API")
            await reloadRandomCandidates(userId: userId, triggerSource: "manual")
            return
        }

        if showNextCandidate() == false {
            print("[Buddy] refresh animation finished -> start API")
            await reloadRandomCandidates(userId: userId, triggerSource: "indexExhausted")
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
                guard let requesterId = Int(myUserId) else {
                    alertMessage = "현재 로그인 사용자 ID 형식이 올바르지 않아요."
                    isShowingAlert = true
                    return
                }
                print("[Buddy] send buddy request requesterId=\(requesterId) targetUserId=\(receiverId)")
                _ = try await buddyAPIService.createBuddyRequest(
                    requesterId: requesterId,
                    targetUserId: receiverId
                )
                showBanner("버디 신청을 보냈어요")
                await refreshRequestData(userId: myUserId, shouldRefreshIncoming: false)
                applyPendingStateToRandomCandidates()
            } catch {
                if case let APIError.server(statusCode, message) = error {
                    print("[Buddy] buddy request failed status=\(statusCode) body=\(message ?? "")")
                } else {
                    print("[Buddy] buddy request failed status=unknown body=\(error.localizedDescription)")
                }
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
                incomingRequests.removeAll { $0.requestId == item.requestId }
                print("[Buddy] accept success requestId=\(item.requestId) remove incoming item")
                print("[Buddy] incoming requests count after accept=\(incomingRequests.count)")
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
                await refreshRequestData(userId: userId)
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
                await self?.refreshRequestData(userId: userId, shouldRefreshIncoming: shouldRefreshIncoming)
            }
        }
    }

    private func refreshBuddyList(userId: String) async {
        do {
            let buddies = try await buddyAPIService.fetchBuddies(userId: userId)
            print("[Buddy] fetched server buddies count=\(buddies.count)")
            let counterpartUserIds = buddies.compactMap { resolvedBuddyUserId(from: $0) }
            await cacheServerProfiles(for: counterpartUserIds)
            connectedRoomCards = buddies.map(makeMateRoomCardItem)
            buddyListErrorMessage = nil
        } catch {
            connectedRoomCards = []
            buddyListErrorMessage = error.localizedDescription
        }
    }

    private func refreshRequestData(userId: String, shouldRefreshIncoming: Bool = true) async {
        isRefreshingDiscoveryData = true
        defer { isRefreshingDiscoveryData = false }

        do {
            async let incomingTask: [BuddyRequestResponse] = shouldRefreshIncoming
                ? buddyAPIService.fetchIncomingBuddyRequests(userId: userId)
                : []
            async let outgoingTask = buddyAPIService.fetchOutgoingBuddyRequests(userId: userId)

            let incomingResponses = try await incomingTask
            let outgoingResponses = try await outgoingTask
            let incomingUserIds = incomingResponses.compactMap(\.requesterId)
            await cacheServerProfiles(for: incomingUserIds)

            if shouldRefreshIncoming {
                incomingRequests = incomingResponses.map(makeIncomingRequestItem)
            }
            outgoingRequests = outgoingResponses
            applyPendingStateToRandomCandidates()
            discoveryErrorMessage = nil
        } catch {
            if shouldRefreshIncoming {
                incomingRequests = []
            }
            outgoingRequests = []
            discoveryErrorMessage = error.localizedDescription
        }
    }

    private func loadRandomCandidatesIfNeeded(userId: String) async {
        if hasLoadedRandomCandidates {
            print("[Buddy] random candidates initial load skipped/already loaded")
            return
        }

        print("[Buddy] random candidates initial load start")
        await reloadRandomCandidates(userId: userId, triggerSource: "initial")
    }

    private func reloadRandomCandidates(userId: String, triggerSource: String) async {
        guard isRefreshingCandidate == false else { return }

        print("[Buddy] random candidate refresh trigger source=\(triggerSource)")
        print("[Buddy] random candidates reload start")

        isRefreshingCandidate = true
        defer { isRefreshingCandidate = false }

        do {
            let candidateResponses = try await buddyAPIService.fetchRandomCandidates(userId: userId)
            let candidateUserIds = candidateResponses.compactMap(\.userId)
            await cacheServerProfiles(for: candidateUserIds)
            applyRandomCandidateResponses(candidateResponses)
            hasLoadedRandomCandidates = true
            print("[Buddy] random candidates reload success count=\(randomCandidates.count)")
            discoveryErrorMessage = nil
        } catch {
            randomCandidates = []
            currentRandomCandidateIndex = 0
            hasLoadedRandomCandidates = false
            discoveryErrorMessage = error.localizedDescription
        }
    }

    private func showNextCandidate() -> Bool {
        guard randomCandidates.count > 1 else {
            return false
        }

        let nextIndex = currentRandomCandidateIndex + 1
        guard randomCandidates.indices.contains(nextIndex) else {
            print("[Buddy] show next candidate reached end -> reload")
            return false
        }

        currentRandomCandidateIndex = nextIndex
        print("[Buddy] show next candidate local index=\(currentRandomCandidateIndex) without network")
        return true
    }

    private func applyRandomCandidateResponses(_ candidateResponses: [RandomCandidateResponse]) {
        let pendingOutgoingIds = Set(outgoingRequests.compactMap { $0.receiverId })
        let incomingRequesterIds = Set(
            incomingRequests.compactMap { item in
                item.requesterId ?? (item.id >= 0 ? item.id : nil)
            }
        )
        let filteredCandidateResponses = candidateResponses.filter { response in
            let candidateId = response.userId ?? (response.id >= 0 ? response.id : nil)
            guard let candidateId else { return true }
            return incomingRequesterIds.contains(candidateId) == false
        }

        if filteredCandidateResponses.count != candidateResponses.count {
            print("[Buddy] filtered duplicate candidates count=\(candidateResponses.count - filteredCandidateResponses.count)")
        }

        randomCandidates = filteredCandidateResponses.map {
            makeRandomCandidateItem(from: $0, pendingOutgoingIds: pendingOutgoingIds)
        }
        currentRandomCandidateIndex = 0
        normalizeCurrentRandomCandidateIndex()
    }

    private func applyPendingStateToRandomCandidates() {
        let pendingOutgoingIds = Set(outgoingRequests.compactMap(\.receiverId))
        randomCandidates = randomCandidates.map { item in
            guard let userId = item.userId else { return item }
            return RandomCandidateItem(
                id: item.id,
                userId: item.userId,
                displayName: item.displayName,
                jlptLevel: item.jlptLevel,
                recentAccessText: item.recentAccessText,
                bio: item.bio,
                instagramId: item.instagramId,
                profileImageUrl: item.profileImageUrl,
                avatarData: item.avatarData,
                isPending: pendingOutgoingIds.contains(userId)
            )
        }
        normalizeCurrentRandomCandidateIndex()
    }

    private func normalizeCurrentRandomCandidateIndex() {
        guard randomCandidates.isEmpty == false else {
            currentRandomCandidateIndex = 0
            return
        }

        if randomCandidates.indices.contains(currentRandomCandidateIndex) == false {
            currentRandomCandidateIndex = 0
        }
    }

    private func makeMateRoomCardItem(from summary: BuddySummaryResponse) -> MateRoomCardItem {
        let backendBuddyId = resolvedBuddyUserId(from: summary)
        let profileUserId = backendBuddyId.map(String.init) ?? ""
        let fallbackProfile = userMetaProvider.profile(for: profileUserId)
        let serverProfile = backendBuddyId.flatMap { serverProfileByUserId[$0] }

        let resolvedDisplayName = resolvedBuddyText(
            serverValue: serverProfile?.nickname ?? summary.buddyNickname,
            fallbackValue: fallbackProfile.displayName,
            placeholder: "이름 미정",
            fieldName: "nickname",
            buddyUserId: backendBuddyId
        )
        let resolvedBio = resolvedBuddyText(
            serverValue: serverProfile?.bio ?? summary.buddyBio,
            fallbackValue: fallbackProfile.bio,
            placeholder: "",
            fieldName: "bio",
            buddyUserId: backendBuddyId
        )
        let resolvedInstagramId = resolvedBuddyText(
            serverValue: serverProfile?.instagramId ?? summary.buddyInstagramId,
            fallbackValue: fallbackProfile.instagramId,
            placeholder: "",
            fieldName: "instagramId",
            buddyUserId: backendBuddyId
        )
        let resolvedLevel = resolvedBuddyLevel(
            serverValue: serverProfile?.jlptLevel ?? summary.buddyLearningLevel,
            fallbackValue: fallbackProfile.jlptLevel,
            buddyUserId: backendBuddyId
        ) ?? .n5

        let resolvedAvatar = resolvedBuddyAvatarData(
            buddyUserId: backendBuddyId,
            serverProfile: serverProfile,
            summaryAvatarBase64: summary.avatarBase64,
            fallbackAvatarData: fallbackProfile.avatarData
        )

        let resolvedProfile = MateUserProfile(
            userId: profileUserId,
            displayName: resolvedDisplayName,
            bio: resolvedBio,
            instagramId: resolvedInstagramId,
            jlptLevel: resolvedLevel,
            profileImageUrl: resolvedAvatar.profileImageUrl,
            avatarData: resolvedAvatar.data
        )

        if let backendBuddyId {
            print(
                "[Buddy] mapped card buddyUserId=\(backendBuddyId) " +
                "nickname=\(resolvedDisplayName) level=\(resolvedLevel.rawValue) " +
                "imageSource=\(resolvedAvatar.source) avatarDataIsNil=\(resolvedAvatar.data == nil)"
            )
        } else {
            print("[Buddy] mapped card buddyUserId=nil nickname=\(resolvedDisplayName) level=\(resolvedLevel.rawValue) imageSource=\(resolvedAvatar.source) avatarDataIsNil=\(resolvedAvatar.data == nil)")
        }

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

        print("[Buddy] card tikiTakaCount buddyUserId=\(backendBuddyId.map(String.init) ?? "nil") count=\(mapped.resolvedTikiTakaCount)")
        return mapped
    }

    private func makeIncomingRequestItem(from response: BuddyRequestResponse) -> IncomingBuddyRequestItem {
        let serverProfile = response.requesterId.flatMap { serverProfileByUserId[$0] }
        let displayName = serverProfile?.nickname ?? response.nickname
        let level = serverProfile?.jlptLevel ?? response.jlptLevel
        let bio = serverProfile?.bio ?? response.bio
        let instagramId = serverProfile?.instagramId ?? response.instagramId
        let profileImageUrl = serverProfile?.profileImageUrl
        let avatarData = resolvedRequestAvatarData(
            buddyUserId: response.requesterId,
            serverProfile: serverProfile,
            responseAvatarBase64: response.avatarBase64
        )

        print("[Buddy] using server request profile requestId=\(response.requestId) nickname=\(displayName)")
        return IncomingBuddyRequestItem(
            id: response.id,
            requestId: response.requestId,
            requesterId: response.requesterId,
            displayName: displayName,
            jlptLevel: level,
            recentAccessText: recentAccessText(from: response.lastActiveAt),
            bio: bio,
            instagramId: instagramId,
            profileImageUrl: profileImageUrl,
            avatarData: avatarData
        )
    }

    private func makeRandomCandidateItem(from response: RandomCandidateResponse, pendingOutgoingIds: Set<Int>) -> RandomCandidateItem {
        let serverProfile = response.userId.flatMap { serverProfileByUserId[$0] }
        let displayName = serverProfile?.nickname ?? response.nickname
        let level = serverProfile?.jlptLevel ?? response.jlptLevel
        let bio = serverProfile?.bio ?? response.bio
        let instagramId = serverProfile?.instagramId ?? response.instagramId
        let profileImageUrl = serverProfile?.profileImageUrl
        let avatarData = resolvedCandidateAvatarData(
            buddyUserId: response.userId,
            serverProfile: serverProfile,
            responseAvatarBase64: response.avatarBase64
        )

        print("[Buddy] using server candidate profile userId=\(response.userId.map(String.init) ?? "nil") nickname=\(displayName)")
        return RandomCandidateItem(
            id: response.id,
            userId: response.userId,
            displayName: displayName,
            jlptLevel: level,
            recentAccessText: recentAccessText(from: response.lastActiveAt),
            bio: bio,
            instagramId: instagramId,
            profileImageUrl: profileImageUrl,
            avatarData: avatarData,
            isPending: response.userId.map(pendingOutgoingIds.contains) ?? false
        )
    }

    private func cacheServerProfiles(for userIds: [Int]) async {
        let uncachedUserIds = Array(Set(userIds)).filter { serverProfileByUserId[$0] == nil }
        guard uncachedUserIds.isEmpty == false else { return }

        await withTaskGroup(of: BuddyServerProfile?.self) { group in
            for userId in uncachedUserIds {
                group.addTask { [profileAPIService] in
                    do {
                        let response = try await profileAPIService.fetchUserProfile(userId: String(userId))
                        let avatarBase64Exists: Bool
                        let avatarData: Data?
                        if let rawValue = response.avatarBase64 {
                            avatarBase64Exists = true
                            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                avatarData = nil
                            } else {
                                avatarData = Data(base64Encoded: trimmed)
                            }
                        } else if let profileImageUrl = response.profileImageUrl,
                                  let downloadedData = await self.downloadImageData(from: profileImageUrl) {
                            avatarBase64Exists = false
                            avatarData = downloadedData
                        } else {
                            avatarBase64Exists = false
                            avatarData = nil
                        }
                        print("[Buddy] fetched server profile userId=\(userId) avatarBase64Exists=\(avatarBase64Exists)")
                        print("[Buddy] decoded avatarData isNil=\(avatarData == nil)")
                        return BuddyServerProfile(
                            userId: userId,
                            nickname: response.nickname,
                            jlptLevel: response.learningLevel,
                            bio: response.bio,
                            instagramId: response.instagramId,
                            profileImageUrl: response.profileImageUrl,
                            avatarData: avatarData
                        )
                    } catch {
                        print("[Buddy] profile fetch failed userId=\(userId) error=\(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await profile in group {
                guard let profile else { continue }
                serverProfileByUserId[profile.userId] = profile
            }
        }
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

    private func resolvedBuddyUserId(from summary: BuddySummaryResponse) -> Int? {
        summary.buddyUserId ?? summary.userId
    }

    private func resolvedBuddyAvatarData(
        buddyUserId: Int?,
        serverProfile: BuddyServerProfile?,
        summaryAvatarBase64: String?,
        fallbackAvatarData: Data?
    ) -> (data: Data?, profileImageUrl: String?, source: String) {
        if let buddyUserId, let serverProfile {
            if let profileImageUrl = serverProfile.profileImageUrl {
                print("[Buddy] using server profile image for buddyUserId=\(buddyUserId)")
                return (serverProfile.avatarData, profileImageUrl, "serverProfileUrl")
            }
            if let avatarData = serverProfile.avatarData {
                print("[Buddy] using server profile image for buddyUserId=\(buddyUserId)")
                return (avatarData, nil, "serverProfile")
            }
        }

        if let avatarData = decodeAvatarData(from: summaryAvatarBase64) {
            return (avatarData, nil, "buddySummary")
        }

        if let buddyUserId {
            print("[Buddy] buddy summary image missing for buddyUserId=\(buddyUserId)")
        }

        if let buddyUserId, let fallbackAvatarData {
            print("[Buddy] fallback to local profile image for buddyUserId=\(buddyUserId)")
            return (fallbackAvatarData, nil, "localFallback")
        }

        if let buddyUserId {
            print("[Buddy] fallback to default avatar for buddyUserId=\(buddyUserId)")
        } else {
            print("[Buddy] fallback to default avatar for buddyUserId=nil")
        }
        return (nil, nil, "default")
    }

    private func resolvedRequestAvatarData(
        buddyUserId: Int?,
        serverProfile: BuddyServerProfile?,
        responseAvatarBase64: String?
    ) -> Data? {
        if let buddyUserId, let avatarData = serverProfile?.avatarData {
            print("[Buddy] using server profile image for buddyUserId=\(buddyUserId) image=true")
            return avatarData
        }

        return decodeAvatarData(from: responseAvatarBase64)
    }

    private func resolvedCandidateAvatarData(
        buddyUserId: Int?,
        serverProfile: BuddyServerProfile?,
        responseAvatarBase64: String?
    ) -> Data? {
        if let buddyUserId, let avatarData = serverProfile?.avatarData {
            print("[Buddy] using server profile image for buddyUserId=\(buddyUserId) image=true")
            return avatarData
        }

        return decodeAvatarData(from: responseAvatarBase64)
    }

    private func downloadImageData(from path: String) async -> Data? {
        guard let url = resolvedImageURL(from: path) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return data
        } catch {
            print("[Buddy] image download failed url=\(path) error=\(error.localizedDescription)")
            return nil
        }
    }

    private func resolvedImageURL(from path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return APIConfiguration.baseURL.appendingPathComponent(trimmedPath)
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
