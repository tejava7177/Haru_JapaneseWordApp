import SwiftUI
import UIKit

struct InviteSectionView: View {
    let myInviteCode: String
    @Binding var inviteCodeInput: String
    let onCreateInviteCode: () -> Void
    let onJoin: (String) -> Void
    let isBusy: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("초대코드 매칭")
                .font(.headline)
            Text("초대코드로만 버디를 시작할 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                        Button("복사") {
                            UIPasteboard.general.string = myInviteCode
                        }
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

            Button("초대코드 만들기") {
                onCreateInviteCode()
            }
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
