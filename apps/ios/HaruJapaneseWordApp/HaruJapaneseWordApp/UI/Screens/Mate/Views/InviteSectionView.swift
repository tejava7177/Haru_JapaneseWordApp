import SwiftUI

struct InviteSectionView: View {
    let myInviteCode: String
    @Binding var inviteCodeInput: String
    let onShowInviteCode: () -> Void
    let onCopyInviteCode: () -> Void
    let onJoin: (String) -> Void
    let isBusy: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("초대코드 매칭")
                .font(.headline)

            if myInviteCode.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("내 초대코드")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(myInviteCode)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("복사하기") { onCopyInviteCode() }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }

            Button("내 초대코드 보기") { onShowInviteCode() }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(isBusy)

            VStack(alignment: .leading, spacing: 8) {
                TextField("초대 코드 입력", text: $inviteCodeInput)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)

                Button("버디 시작") {
                    onJoin(inviteCodeInput)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(isBusy)

                if let errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
        )
    }
}
