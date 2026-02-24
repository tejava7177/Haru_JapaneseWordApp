import SwiftUI

struct SignInRequiredView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @State private var isShowingProfileSheet: Bool = false
    @State private var nickname: String = ""
    @State private var jlptLevel: String = JLPTLevel.n5.rawValue
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.yellow.opacity(0.15).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("로그인이 필요해요")
                    .font(.title3).bold()

                Text("Apple로 시작하기")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Apple 버튼 아래에 보이면 레이아웃은 정상")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                AppleSignInButton { userId in
                    settingsStore.signIn(appleUserId: userId)
                    if settingsStore.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        nickname = ""
                        jlptLevel = settingsStore.jlptLevel
                        isShowingProfileSheet = true
                    }
                } onFailure: { error in
                    errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요.\n\(error.localizedDescription)"
                }
                .frame(height: 52)

                Text("버튼이 안 보이면 AppleSignInButton 구현/Representable 문제 가능성")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingProfileSheet) {
            ProfileSetupSheet(nickname: $nickname, jlptLevel: $jlptLevel) { nickname, level in
                settingsStore.completeProfile(nickname: nickname, jlptLevel: level)
                isShowingProfileSheet = false
            }
        }
        .alert("로그인 실패", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { _ in
            errorMessage = nil
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

#Preview {
    SignInRequiredView(settingsStore: AppSettingsStore())
}
