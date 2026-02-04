import SwiftUI

struct OnboardingView: View {
    @State private var selectedIndex: Int = 0
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
                        "학습한 단어는 7일 동안 추천에서 제외돼요."
                    ],
                    showsButton: true
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background(Color.white)
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
                Button {
                    onFinish()
                } label: {
                    Text("시작하기")
                        .font(.callout)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
