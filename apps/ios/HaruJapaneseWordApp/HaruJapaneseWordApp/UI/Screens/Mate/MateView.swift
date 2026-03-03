import SwiftUI
import UIKit

struct MateView: View {
    @StateObject private var viewModel: MateViewModel
    @State private var isInviteSectionExpanded: Bool = false

    init(viewModel: MateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.connectedRoomCards.isEmpty {
                        emptyMateSection
                    } else {
                        myMateSection
                    }

                    addMateButtonSection

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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Mate")
        }
        .onAppear {
            viewModel.load()
        }
        .onChange(of: viewModel.connectedMateCount) { count in
            guard count >= MateViewModel.maxMateCount else { return }
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
        .animation(.easeOut(duration: 0.2), value: viewModel.matchCelebration?.id ?? -1)
        .alert("안내", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    private var myMateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내 동행")
                .font(.headline)

            LazyVStack(spacing: 12) {
                ForEach(viewModel.connectedRoomCards) { item in
                    MateRoomCardView(item: item) {
                        viewModel.endRoom(roomId: item.room.id)
                    }
                }
            }
        }
    }

    private var emptyMateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내 동행")
                .font(.headline)
            Text("아직 동행이 없어요. 초대코드로 시작해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                    Text(isInviteSectionExpanded ? "새 동행 추가 접기" : "새 동행 추가")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.canAddNewMate == false)

            if viewModel.canAddNewMate == false {
                Text("동행은 최대 4명까지 가능해요")
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
}

#Preview {
    let settings = AppSettingsStore()
    let repo = SQLiteMateRepository()
    let service = MateService(repository: repo, appUserIdProvider: { settings.mateUserId })
    MateView(viewModel: MateViewModel(service: service, settingsStore: settings))
}
