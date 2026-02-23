import SwiftUI

struct SignInRequiredView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @State private var isShowingProfileSheet: Bool = false
    @State private var nickname: String = ""
    @State private var jlptLevel: String = JLPTLevel.n5.rawValue
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("Haru")
                    .font(.largeTitle.weight(.semibold))
                Text("Apple ID로 바로 시작할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
            .frame(maxWidth: 280)

            Spacer()
        }
        .padding(24)
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
