import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onFinish: () -> Void

    init(isBuddyEnabled: Bool, onFinish: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(isBuddyEnabled: isBuddyEnabled))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.selectedIndex) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageContent(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut(duration: 0.24), value: viewModel.selectedIndex)

            HStack(spacing: 12) {
                Button("건너뛰기") {
                    onFinish()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Button {
                    if viewModel.isLastPage {
                        onFinish()
                    } else {
                        viewModel.moveToNextPage()
                    }
                } label: {
                    Text(viewModel.isLastPage ? "시작하기" : "다음")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 108)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .background(Color(uiColor: .systemBackground))
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.94, green: 0.97, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

private struct OnboardingPageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 28)

            mockCard

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    ForEach(page.description, id: \.self) { line in
                        Text(line)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if let supportingText = page.supportingText {
                    Text(supportingText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var mockCard: some View {
        mockContent
        .frame(maxWidth: 360)
        .frame(height: 340)
    }

    @ViewBuilder
    private var mockContent: some View {
        switch page.mockKind {
        case .recommendationCard:
            VStack(spacing: 14) {
                RecommendationWordCardView(
                    expression: "食べる",
                    reading: "たべる",
                    meanings: "먹다",
                    isExcluded: false,
                    action: nil
                )

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                )
            }

        case .search:
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 48)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text("JLPT N3")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }

                ForEach(["話す", "準備", "文化"], id: \.self) { word in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(word)
                                .font(.headline)
                            Text("단어 예시와 뜻")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("N3")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

        case .notebook:
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("내 단어장")
                            .font(.title3.weight(.semibold))
                        Text("48 words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 38, height: 38)
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }

                ForEach(["여행 회화", "자주 틀린 단어", "애니 표현"], id: \.self) { item in
                    HStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "book.closed").foregroundStyle(Color.orange))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item)
                                .font(.headline)
                            Text("직접 추가한 단어 모음")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }

        case .buddy:
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Buddy")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Text("LOGIN")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 112)
                    .overlay {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.pink.opacity(0.20))
                                .frame(width: 58, height: 58)
                                .overlay(Image(systemName: "person.fill").foregroundStyle(Color.pink))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("친구와 단어 공유")
                                    .font(.headline)
                                Text("로그인 후 Buddy 탭에서 시작")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(18)
                    }

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                            .frame(height: 64)
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isBuddyEnabled: true, onFinish: {})
}
