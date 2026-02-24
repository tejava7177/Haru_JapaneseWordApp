import SwiftUI

struct MateView: View {
    @StateObject private var viewModel: MateViewModel

    init(viewModel: MateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let room = viewModel.activeRoom, room.hasMate {
                        activeRoomSection(room: room)
                    } else {
                        inviteSection
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
        .alert("안내", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("초대코드 매칭")
                .font(.headline)
            Text("초대코드로만 동행을 시작할 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.inviteCode.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("내 초대코드")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(viewModel.inviteCode)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("복사") {
                            UIPasteboard.general.string = viewModel.inviteCode
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }

            Button("초대코드 만들기") {
                viewModel.createInviteCode()
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)

            VStack(alignment: .leading, spacing: 8) {
                TextField("초대 코드 입력", text: $viewModel.inputInviteCode)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
                Button("동행 시작") {
                    viewModel.joinByInviteCode()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private func activeRoomSection(room: MateRoom) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연결됨")
                .font(.headline)
            Text("상대: \(viewModel.counterpartLabel(for: room))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("최근 콕: \(viewModel.lastInteractionDescription())")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("콕 찌르기 (준비중)") {}
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(true)

            Button("동행 종료") {
                viewModel.endRoom()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview {
    let settings = AppSettingsStore()
    let repo = SQLiteMateRepository()
    let service = MateService(repository: repo, appUserIdProvider: { settings.mateUserId })
    MateView(viewModel: MateViewModel(service: service, settingsStore: settings))
}
