import SwiftUI
import UIKit

struct MateView: View {
    private let refreshIconAnimationDuration: Double = 0.8

    @StateObject private var viewModel: MateViewModel
    @State private var isInviteSectionExpanded: Bool = false
    @State private var selectedBuddy: MateRoomCardItem?
    @State private var isShowingBuddyDetail: Bool = false
    @State private var previewBuddy: BuddyProfilePreviewItem?
    @State private var candidateRefreshIconRotation: Double = 0
    @State private var isAnimatingRefreshIcon: Bool = false

    init(viewModel: MateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.connectedRoomCards.isEmpty {
                    emptyMateSection
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.connectedRoomCards) { item in
                        MateRoomCardView(
                            item: item,
                            onAvatarTap: {
                                presentProfilePreview(for: item)
                            },
                            onCardTap: {
                                guard Int(item.counterpartUserId) != nil else { return }
                                selectedBuddy = item
                                isShowingBuddyDetail = true
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteBuddy(item)
                            } label: {
                                Label("끊기", systemImage: "person.2.slash")
                            }
                            .disabled(viewModel.isBusy)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }

                addMateButtonSection
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if viewModel.incomingRequests.isEmpty == false {
                    incomingRequestsSection
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                randomCandidatesSection
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                inviteCodeSection
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("Buddy")
            .navigationDestination(isPresented: $isShowingBuddyDetail) {
                if let item = selectedBuddy {
                    BuddyDetailView(
                        viewModel: BuddyDetailViewModel(
                            buddyId: item.counterpartUserId,
                            buddyName: item.counterpartLabel,
                            settingsStore: viewModel.settingsStoreForBuddyDetail
                        )
                    )
                }
            }
        }
        .onAppear {
            viewModel.onViewAppear()
        }
        .onDisappear {
            viewModel.onViewDisappear()
        }
        .onChange(of: viewModel.matchCelebration) { celebration in
            guard celebration != nil else { return }
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.matchCelebration = nil
                }
            }
        }
        .onChange(of: viewModel.bannerMessage) { message in
            guard message != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.bannerMessage = nil
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let celebration = viewModel.matchCelebration {
                    toastView(for: celebration)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let bannerMessage = viewModel.bannerMessage {
                    bannerView(message: bannerMessage.text)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 12)
        }
        .overlay {
            if let previewBuddy {
                buddyProfileOverlay(for: previewBuddy)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.matchCelebration?.id ?? -1)
        .animation(.easeOut(duration: 0.2), value: viewModel.bannerMessage?.id)
        .alert("안내", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    private var emptyMateSection: some View {
        Text(viewModel.buddyListErrorMessage ?? "아직 버디가 없어요.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var addMateButtonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("새 버디 찾기")
                .font(.headline)
            if viewModel.canAddNewMate == false {
                Text("버디는 최대 3명까지 가능해요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if viewModel.incomingRequestCount > 0 {
                Text("새 신청 \(viewModel.incomingRequestCount)건이 도착했어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var incomingRequestsSection: some View {
        BuddyDiscoverySectionView(
            title: "받은 버디 신청",
            subtitle: viewModel.incomingRequestCount > 0 ? "도착한 신청에 바로 응답할 수 있어요." : nil
        ) {
            VStack(spacing: 10) {
                ForEach(viewModel.incomingRequests) { item in
                    BuddyDiscoveryCardView(
                        item: item.cardItem,
                        onPrimaryAction: { viewModel.acceptIncomingRequest(item) },
                        onSecondaryAction: { viewModel.rejectIncomingRequest(item) },
                        secondaryActionTitle: "거절",
                        onPreviewTap: { previewBuddy = item.previewItem }
                    )
                }
            }
        }
    }

    private var inviteCodeSection: some View {
        InviteSectionView(
            isExpanded: $isInviteSectionExpanded,
            myInviteCode: viewModel.inviteCode,
            inviteCodeInput: $viewModel.inputInviteCode,
            onShowInviteCode: {
                viewModel.fetchMyInviteCode()
            },
            onCopyInviteCode: {
                viewModel.copyInviteCode()
            },
            onJoin: { inviteCode in
                viewModel.joinByInviteCode(inviteCode)
            },
            isBusy: viewModel.isBusy,
            errorMessage: viewModel.inviteSectionErrorMessage
        )
    }

    private var randomCandidatesSection: some View {
        BuddyDiscoverySectionView(
            title: "랜덤 매칭 후보",
            headerAccessory: {
                if viewModel.randomCandidates.isEmpty == false {
                    Button {
                        handleRandomCandidateRefreshTap()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .rotationEffect(.degrees(candidateRefreshIconRotation))
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .disabled(isAnimatingRefreshIcon || viewModel.isRefreshingCandidate || viewModel.isBusy)
                    .opacity(isAnimatingRefreshIcon || viewModel.isRefreshingCandidate || viewModel.isBusy ? 0.5 : 1)
                    .accessibilityLabel(isAnimatingRefreshIcon || viewModel.isRefreshingCandidate ? "후보 불러오는 중" : "다른 후보 보기")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let candidate = viewModel.currentRandomCandidate {
                    BuddyDiscoveryCardView(
                        item: candidate.cardItem,
                        onPrimaryAction: { viewModel.sendBuddyRequest(to: candidate) },
                        onSecondaryAction: nil,
                        secondaryActionTitle: nil,
                        onPreviewTap: { previewBuddy = candidate.previewItem }
                    )
                } else {
                    Text(viewModel.discoveryErrorMessage ?? "지금은 추천할 버디가 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func handleRandomCandidateRefreshTap() {
        guard isAnimatingRefreshIcon == false,
              viewModel.isRefreshingCandidate == false,
              viewModel.isBusy == false else {
            return
        }

        print("[Buddy] refresh icon tapped")

        Task {
            await animateRefreshIconOnce()
            print("[Buddy] refresh animation finished")
            await viewModel.refreshRandomCandidates()
        }
    }

    @MainActor
    private func animateRefreshIconOnce() async {
        print("[Buddy] refresh animation start")
        isAnimatingRefreshIcon = true
        candidateRefreshIconRotation = 0

        withAnimation(.linear(duration: refreshIconAnimationDuration)) {
            candidateRefreshIconRotation = 360
        }

        try? await Task.sleep(nanoseconds: UInt64(refreshIconAnimationDuration * 1_000_000_000))

        candidateRefreshIconRotation = 0
        isAnimatingRefreshIcon = false
    }

    private func toastView(for celebration: MatchCelebration) -> some View {
        let message: MatchCelebrationMessage
        switch celebration {
        case .connected(let m, _):
            message = m
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(message.title)
                .font(.subheadline.weight(.semibold))
                .fontDesign(message.isJapaneseOnly ? .serif : .default)
            HStack(spacing: 6) {
                Text(message.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fontDesign(message.isJapaneseOnly ? .serif : .default)
                if message.isJapaneseOnly {
                    Text("🌸")
                        .font(.footnote)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Capsule(style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
    }

    private func bannerView(message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            )
    }

    private func buddyProfileOverlay(for item: BuddyProfilePreviewItem) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissProfilePreview()
                }

            BuddyProfilePreviewCard(item: item, onClose: dismissProfilePreview)
                .padding(.horizontal, 16)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .zIndex(10)
    }

    private func presentProfilePreview(for item: MateRoomCardItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            previewBuddy = item.previewItem
        }
    }

    private func dismissProfilePreview() {
        withAnimation(.easeInOut(duration: 0.18)) {
            previewBuddy = nil
        }
    }
}

#Preview {
    let settings = AppSettingsStore()
    MateView(viewModel: MateViewModel(settingsStore: settings))
}
