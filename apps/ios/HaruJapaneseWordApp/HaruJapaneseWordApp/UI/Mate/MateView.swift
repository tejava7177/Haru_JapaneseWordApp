import SwiftUI

struct MateView: View {
    @ObservedObject var viewModel: MateViewModel
    @State private var isShowingInactivityPrompt: Bool = false
    let onRequestProfileLogin: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSignedIn == false {
                    VStack(spacing: 16) {
                        Text("로그인이 필요해요")
                            .font(.title3).bold()
                        Text("Mate 기능(동행/콕)은 프로필에서 로그인 후 사용할 수 있어요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("프로필에서 로그인하기") {
                            onRequestProfileLogin()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if viewModel.isMateEnabled == false {
                                enableCard
                            } else {
                                contentSection
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("Mate")
        }
        .task {
            if viewModel.isSignedIn {
                viewModel.load()
            }
        }
        .onChange(of: viewModel.isSignedIn) { isSignedIn in
            if isSignedIn {
                viewModel.load()
            }
        }
        .onChange(of: viewModel.state.shouldShowInactivityPrompt) { newValue in
            if newValue {
                isShowingInactivityPrompt = true
            }
        }
        .alert("안내", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert("Mate가 잠시 쉬고 있어요. 기다릴까요, 새로운 동행을 시작할까요?", isPresented: $isShowingInactivityPrompt) {
            Button("기다리기") {
                viewModel.waitForMate()
                isShowingInactivityPrompt = false
            }
            Button("새 Mate 찾기") {
                viewModel.endRoom()
                isShowingInactivityPrompt = false
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isShowingToast {
                Text(viewModel.toastMessage)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var enableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🌿 Mate를 켜면")
                .font(.headline)
            Text("가끔 서로를 콕 찌르며 가볍게 공부를 이어가요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Mate 켜기") {
                viewModel.enableMate()
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var contentSection: some View {
        if let room = viewModel.state.room {
            if room.status == .expired {
                expiredSection
            } else if room.status == .ended {
                startSection
            } else {
                activeSection(room: room)
            }
        } else {
            startSection
        }
    }

    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🌿 30일 동안 함께했어요. 새로운 동행을 시작할까요?")
                .font(.headline)
            HStack {
                Button("새 Mate 찾기") {
                    viewModel.endRoom()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                Button("나중에") {}
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func activeSection(room: MateRoom) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MateCardView(
                title: "🌿 함께 걷는 중",
                description: "\(room.mateNickname) 님과 천천히 걸어봐요.",
                myStatus: viewModel.state.myLearnedToday ? "학습 완료" : "아직 시작 전",
                mateStatus: viewModel.state.mateLearnedToday ? "학습 완료" : "아직 시작 전",
                canPoke: viewModel.state.canPoke,
                isCTA: false,
                ctaTitle: "",
                onTapCTA: {},
                onPoke: { Task { await viewModel.poke() } }
            )

            inviteCard
        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("동행을 시작해 볼까요?")
                .font(.headline)
            Text("초대 코드를 입력하면 30일 동안 단일 동행이 시작돼요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                TextField("초대 코드", text: $viewModel.inputInviteCode)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
                TextField("Mate 닉네임 (선택)", text: $viewModel.inputMateNickname)
                    .textFieldStyle(.roundedBorder)
                Button("동행 시작하기") {
                    viewModel.startWithInvite()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)

                #if DEBUG
                Button("테스트 Mate 연결") {
                    viewModel.startWithMock()
                }
                .buttonStyle(.bordered)
                #endif
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            inviteCard
        }
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내 초대 코드")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(viewModel.inviteCode())
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    let repository = StubDictionaryRepository()
    let mateRepository = try? SQLiteMateRepository()
    let service = MateService(
        repository: mateRepository ?? StubMateRepository(),
        dictionaryRepository: repository,
        notifier: LocalNotificationPokeNotifier()
    )
    let viewModel = MateViewModel(mateService: service, settingsStore: AppSettingsStore())
    MateView(viewModel: viewModel, onRequestProfileLogin: {})
}
