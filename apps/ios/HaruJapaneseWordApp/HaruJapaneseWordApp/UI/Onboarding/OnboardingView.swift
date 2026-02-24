import SwiftUI

struct OnboardingView: View {
    @State private var selectedIndex: Int = 0
    @State private var isShowingProfileSheet: Bool = false
    @State private var nickname: String = ""
    @State private var jlptLevel: String = JLPTLevel.n5.rawValue
    @State private var errorMessage: String?
    let settingsStore: AppSettingsStore
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedIndex) {
                onboardingPage(
                    title: "오늘의 추천",
                    description: [
                        "하루에 추천되는 단어 카드 3장을 넘겨볼 수 있어요.",
                        "오늘의 추천은 하루 동안 유지돼요."
                    ]
                )
                .tag(0)

                onboardingPage(
                    title: "학습 체크 ✓",
                    description: [
                        "✓를 누르면 학습한 단어로 표시돼요.",
                        "학습한 단어는 추천에서 잠시 쉬어요."
                    ],
                    showsButton: true
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background(Color.white)
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $isShowingProfileSheet) {
            ProfileSetupSheet(nickname: $nickname, jlptLevel: $jlptLevel) { nickname, level in
                settingsStore.completeProfile(nickname: nickname, jlptLevel: level)
                settingsStore.markOnboardingSeen()
                isShowingProfileSheet = false
                onFinish()
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

    private func onboardingPage(title: String, description: [String], showsButton: Bool = false) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                .frame(width: 96, height: 96)
                .overlay(
                    Text("카드")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                )

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(description, id: \.self) { line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            if showsButton {
                VStack(spacing: 12) {
                    AppleSignInButton { userId in
                        settingsStore.signIn(appleUserId: userId)
                        nickname = ""
                        jlptLevel = settingsStore.jlptLevel
                        isShowingProfileSheet = true
                    } onFailure: { error in
                        errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요.\\n\\(error.localizedDescription)"
                    }
                    .frame(maxWidth: 280)
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(settingsStore: AppSettingsStore(), onFinish: {})
}
