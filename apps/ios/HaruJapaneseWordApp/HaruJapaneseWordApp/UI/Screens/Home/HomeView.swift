import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var isShowingTsunTsunInbox: Bool = false
    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore

    init(repository: DictionaryRepository, settingsStore: AppSettingsStore) {
        self.repository = repository
        self.settingsStore = settingsStore
        _viewModel = StateObject(wrappedValue: HomeViewModel(repository: repository, settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let summary = viewModel.tsunTsunInboxSummary {
                        TsunTsunInboxSummaryCard(summary: summary) {
                            isShowingTsunTsunInbox = true
                        }
                    }

                    todayLyricView()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("오늘의 추천 단어")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Spacer(minLength: 12)

                            if viewModel.targetDateText.isEmpty == false {
                                Text(viewModel.targetDateText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if viewModel.cards.isEmpty == false {
                            TabView(selection: $viewModel.selectedIndex) {
                                ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, word in
                                    cardView(for: word)
                                        .tag(index)
                                        .padding(.horizontal, 2)
                                }
                            }
                            .frame(height: 228)
                            .tabViewStyle(.page(indexDisplayMode: .never))

                            if viewModel.cards.count > 1 {
                                indicatorView(count: viewModel.cards.count)
                                    .padding(.top, 6)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                        } else if viewModel.hasError {
                            emptyStateView()
                        } else {
                            Text("오늘의 추천을 준비 중입니다.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("하루")
            .navigationDestination(for: Int.self) { wordId in
                WordDetailView(wordId: wordId, repository: repository)
            }
            .navigationDestination(isPresented: $isShowingTsunTsunInbox) {
                TsunTsunInboxView(settingsStore: settingsStore)
            }
        }
        .task {
            viewModel.loadDeck()
        }
        .onAppear {
            viewModel.loadInboxSummary()
        }
    }

    @ViewBuilder
    private func cardView(for word: WordSummary) -> some View {
        let cornerRadius: CGFloat = 18
        let bottomSafeSpace: CGFloat = 14
        let isExcluded = viewModel.isExcluded(word.id)

        ZStack {
            NavigationLink(value: word.id) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.expression)
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        if word.reading.isEmpty == false {
                            Text(word.reading)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        if word.meanings.isEmpty == false {
                            Text(word.meanings)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.leading, 18)
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)

                    Spacer(minLength: 10)
                    Spacer(minLength: bottomSafeSpace)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .padding(10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isExcluded ? Color.black.opacity(0.16) : Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.toggleExcluded(wordId: word.id)
            } label: {
                Image(systemName: isExcluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isExcluded ? .primary : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .overlay(alignment: .topLeading) {
            EmptyView()
        }
    }


    @ViewBuilder
    private func todayLyricView() -> some View {
        if let lyric = viewModel.todayLyric {
            VStack(alignment: .leading, spacing: 8) {
                Text("🎵 今日のフレーズ")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if lyric.inspiredBy.isEmpty == false {
                    Text("(Inspired by \(lyric.inspiredBy))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                MarqueeView(text: lyric.jaLine, speed: 28, pause: 0.8)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)

            if lyric.koLine.isEmpty == false {
                Text(lyric.koLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        } else {
            Text("今日のLyric을 준비 중입니다.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func indicatorView(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.selectedIndex ? Color.black.opacity(0.6) : Color.black.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.08))
        )
    }


    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 12) {
            Text("단어를 불러오지 못했어요")
                .font(.headline)
            Text("잠시 후 다시 시도해 주세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("다시 시도") {
                viewModel.loadDeck()
            }
            .buttonStyle(.borderedProminent)

            #if DEBUG
            if let debugError = viewModel.debugError {
                Text(debugError)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
    }
}

private struct TsunTsunInboxSummaryCard: View {
    let summary: TsunTsunInboxSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("받은 츤츤")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(summary.senderHeadline)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.promptText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if summary.reading.isEmpty == false {
                        Text(summary.reading)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Label(summary.arrivalText, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.orange.opacity(0.9))

                    Spacer(minLength: 8)

                    Text("미답변 \(summary.unansweredCount)개")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.16),
                        Color.yellow.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(repository: StubDictionaryRepository(), settingsStore: AppSettingsStore())
}
