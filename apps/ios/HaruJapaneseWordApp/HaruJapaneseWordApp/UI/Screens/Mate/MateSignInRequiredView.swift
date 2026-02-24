import SwiftUI

struct MateSignInRequiredView: View {
    let onRequestProfileLogin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Mate 사용을 위해 로그인 필요")
                .font(.title3).bold()

            Text("프로필에서 로그인하면 Mate 기능을 사용할 수 있어요.")
                .font(.footnote)
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
        .padding(.horizontal, 24)
    }
}

#Preview {
    MateSignInRequiredView(onRequestProfileLogin: {})
}
