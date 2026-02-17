import SwiftUI

struct WordListView: View {
    @ObservedObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository
    @State private var isRangeSheetPresented: Bool = false
    @State private var lastRefreshAction: WordListViewModel.RefreshAction = .shuffled

    init(repository: DictionaryRepository, viewModel: WordListViewModel) {
        self.repository = repository
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        isRangeSheetPresented = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasError {
                    emptyStateView()
                } else {
                    List(viewModel.displayedWords) { word in
                        NavigationLink {
                            WordDetailView(wordId: word.id, repository: repository)
                        } label: {
                            WordRow(word: word, isReviewWord: viewModel.isReviewWord(word.id))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.isReviewWord(word.id) {
                                Button {
                                    viewModel.toggleReview(word.id)
                                } label: {
                                    Label("해제", systemImage: "book.fill")
                                }
                                .tint(.secondary)
                            } else {
                                Button {
                                    viewModel.toggleReview(word.id)
                                } label: {
                                    Label("복습", systemImage: "book.fill")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        let action = await viewModel.pullToRefresh()
                        lastRefreshAction = action
                    }
                }
            }
            .navigationTitle("단어")
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "검색")
        .onChange(of: viewModel.searchText) { _ in
            viewModel.search()
        }
        .onAppear {
            viewModel.refreshReviewState()
        }
        .task {
            viewModel.load()
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            LevelFilterSheetContent(
                availableLevels: viewModel.availableLevels,
                isLevelSelected: { viewModel.selectedLevels.contains($0) },
                isReviewOnly: viewModel.reviewOnly,
                onToggleReviewOnly: { viewModel.toggleReviewOnly() },
                isShuffleLocked: viewModel.preferences.shuffleLocked,
                onToggleShuffleLocked: { viewModel.setShuffleLocked($0) },
                onToggleLevel: { viewModel.toggleLevel($0) },
                onClose: { isRangeSheetPresented = false }
            )
        }
        .overlay(alignment: .top) {
            if viewModel.isShuffling {
                ShuffleHUD(action: lastRefreshAction)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
    }

}

private extension WordListView {
    @ViewBuilder
    func emptyStateView() -> some View {
        VStack(spacing: 12) {
            Text("단어를 불러오지 못했어요")
                .font(.headline)
            Text("잠시 후 다시 시도해 주세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("다시 시도") {
                viewModel.load()
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LevelToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    private let chipHeight: CGFloat = 34
    private let chipMinWidth: CGFloat = 46

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? .white : Color(uiColor: .darkGray))
                .frame(minWidth: chipMinWidth, minHeight: chipHeight)
                .background(isOn ? Color.accentColor : Color(uiColor: .systemGray5))
                .overlay(
                    Capsule()
                        .stroke(isOn ? Color.accentColor : Color(uiColor: .systemGray3), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct BookChip: View {
    let isOn: Bool
    let onTap: () -> Void
    private let chipHeight: CGFloat = 34
    private let chipMinWidth: CGFloat = 46

    var body: some View {
        let activeColor: Color = .orange
        Button(action: onTap) {
            Image(systemName: "book.fill")
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? .white : Color(uiColor: .darkGray))
                .frame(minWidth: chipMinWidth, minHeight: chipHeight)
                .background(isOn ? activeColor : Color(uiColor: .systemGray5))
                .overlay(
                    Capsule()
                        .stroke(isOn ? activeColor : Color(uiColor: .systemGray3), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("복습")
    }
}

private struct ShuffleHUD: View {
    let action: WordListViewModel.RefreshAction
    @State private var isAnimating: Bool = false

    private var iconName: String {
        switch action {
        case .shuffled:
            return "shuffle"
        case .sortedAlphabetically:
            return "textformat.abc"
        }
    }

    private var message: String {
        switch action {
        case .shuffled:
            return "단어를 셔플합니다."
        case .sortedAlphabetically:
            return "단어를 사전순으로 정렬합니다."
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .rotationEffect(action == .shuffled ? (isAnimating ? .degrees(360) : .degrees(0)) : .degrees(0))
                .animation(action == .shuffled ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isAnimating)
            Text(message)
                .font(.footnote)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    WordListView(
        repository: StubDictionaryRepository(),
        viewModel: WordListViewModel(repository: StubDictionaryRepository())
    )
}

#Preview("필터-초기") {
    LevelFilterSheetPreview(
        initialLevels: [],
        availableLevels: [.n1, .n2, .n3, .n4, .n5]
    )
}

#Preview("필터-부분선택") {
    LevelFilterSheetPreview(
        initialLevels: [.n5, .n4, .n3],
        availableLevels: [.n1, .n2, .n3, .n4, .n5]
    )
}

private struct LevelFilterSheetContent: View {
    let availableLevels: [JLPTLevel]
    let isLevelSelected: (JLPTLevel) -> Bool
    let isReviewOnly: Bool
    let onToggleReviewOnly: () -> Void
    let isShuffleLocked: Bool
    let onToggleShuffleLocked: (Bool) -> Void
    let onToggleLevel: (JLPTLevel) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("범위 선택") {
                    VStack(alignment: .leading, spacing: 12) {
                        if availableLevels.isEmpty {
                            Text("사용 가능한 레벨이 없습니다.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(availableLevels, id: \.self) { level in
                                    LevelToggleButton(
                                        title: level.title,
                                        isOn: isLevelSelected(level)
                                    ) {
                                        onToggleLevel(level)
                                    }
                                }
                                BookChip(isOn: isReviewOnly) {
                                    onToggleReviewOnly()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                        }
                    }
                }

                Section {
                    Toggle("셔플 고정", isOn: Binding(
                        get: { isShuffleLocked },
                        set: { onToggleShuffleLocked($0) }
                    ))
                    Text(isShuffleLocked
                         ? "새로고침을 하면 셔플만 돼요"
                         : "새로고침을 하면 사전순 ↔ 셔플이 바뀌어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("필터")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        onClose()
                    }
                }
            }
        }
    }
}

private struct LevelFilterSheetPreview: View {
    @State private var selectedLevels: Set<JLPTLevel>
    @State private var reviewOnly: Bool
    @State private var shuffleLocked: Bool
    private let availableLevels: [JLPTLevel]

    init(initialLevels: Set<JLPTLevel>, availableLevels: [JLPTLevel]) {
        _selectedLevels = State(initialValue: initialLevels)
        _reviewOnly = State(initialValue: false)
        _shuffleLocked = State(initialValue: false)
        self.availableLevels = availableLevels
    }

    private func toggleLevel(_ level: JLPTLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    var body: some View {
        LevelFilterSheetContent(
            availableLevels: availableLevels,
            isLevelSelected: { selectedLevels.contains($0) },
            isReviewOnly: reviewOnly,
            onToggleReviewOnly: { reviewOnly.toggle() },
            isShuffleLocked: shuffleLocked,
            onToggleShuffleLocked: { shuffleLocked = $0 },
            onToggleLevel: { toggleLevel($0) },
            onClose: {}
        )
    }
}
