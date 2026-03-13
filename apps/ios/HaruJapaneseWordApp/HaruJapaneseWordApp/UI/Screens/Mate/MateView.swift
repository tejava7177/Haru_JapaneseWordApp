import SwiftUI
import UIKit

struct MateView: View {
    @StateObject private var viewModel: MateViewModel
    @State private var isInviteSectionExpanded: Bool = false
    @State private var selectedBuddy: MateRoomCardItem?
    @State private var isShowingBuddyDetail: Bool = false
    @State private var previewBuddy: MateRoomCardItem?

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
                            onAvatarLongPress: {
                                presentProfilePreview(for: item)
                            }
                        )
                        .onTapGesture {
                            guard Int(item.counterpartUserId) != nil else { return }
                            selectedBuddy = item
                            isShowingBuddyDetail = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.endRoom(roomId: item.room.id)
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

                if isInviteSectionExpanded {
                    InviteSectionView(
                        myInviteCode: viewModel.inviteCode,
                        inviteCodeInput: $viewModel.inputInviteCode,
                        onCreateInviteCode: {
                            viewModel.createInviteCode()
                        },
                        onJoin: { inviteCode in
                            viewModel.joinByInviteCode(inviteCode)
                        },
                        isBusy: viewModel.isBusy,
                        errorMessage: viewModel.inviteSectionErrorMessage
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
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
        .onChange(of: viewModel.canAddNewMate) { canAdd in
            guard canAdd == false else { return }
            if isInviteSectionExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isInviteSectionExpanded = false
                }
            }
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
        .overlay(alignment: .top) {
            if let celebration = viewModel.matchCelebration {
                toastView(for: celebration)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .overlay {
            if let previewBuddy {
                buddyProfileOverlay(for: previewBuddy)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.matchCelebration?.id ?? -1)
        .alert("안내", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    private var emptyMateSection: some View {
        Text("아직 버디가 없어요. 초대코드로 시작해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
    }

    private var addMateButtonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                guard viewModel.canAddNewMate else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isInviteSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isInviteSectionExpanded ? "chevron.up" : "plus")
                    Text(isInviteSectionExpanded ? "새 버디 추가 접기" : "새 버디 추가")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.canAddNewMate == false)

            if viewModel.canAddNewMate == false {
                Text("버디는 최대 3명까지 가능해요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    private func buddyProfileOverlay(for item: MateRoomCardItem) -> some View {
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
            previewBuddy = item
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
    let repo = SQLiteMateRepository()
    let service = MateService(repository: repo, appUserIdProvider: { settings.mateUserId })
    MateView(viewModel: MateViewModel(service: service, settingsStore: settings))
}
