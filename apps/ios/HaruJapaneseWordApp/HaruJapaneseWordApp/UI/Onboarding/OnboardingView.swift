import SwiftUI

struct OnboardingView: View {
    @State private var selectedIndex: Int = 0
    @State private var isShowingProfileSheet: Bool = false
    @State private var nickname: String = ""
    @State private var jlptLevel: String = JLPTLevel.n5.rawValue
    @State private var errorMessage: String?
    let settingsStore: AppSettingsStore?
    let onFinish: () -> Void

    init(settingsStore: AppSettingsStore, onFinish: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onFinish = onFinish
        print("✅ ONBOARDING_VIEW_INIT settingsStore=\(settingsStore)")
    }

    var body: some View {
        ZStack {
            Color.yellow.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("ONBOARDING SIMPLE")
                    .font(.system(size: 28, weight: .bold))
                Text("...")
                    .font(.body)
            }
        }
        .onAppear {
            print("✅ ONBOARDING_SIMPLE_APPEAR")
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
                        guard let settingsStore = settingsStore else {
                            errorMessage = "설정 정보를 불러오지 못했어요. 앱을 다시 실행해 주세요."
                            return
                        }
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
