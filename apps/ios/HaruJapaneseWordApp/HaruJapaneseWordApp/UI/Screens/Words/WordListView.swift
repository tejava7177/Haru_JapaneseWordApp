import SwiftUI

struct WordListView: View {
    @ObservedObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository
    @State private var isRangeSheetPresented: Bool = false

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
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        await viewModel.shuffleByPull()
                    }
                }
            }
            .navigationTitle("단어")
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "검색")
        .onChange(of: viewModel.searchText) { _ in
            viewModel.search()
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
                onToggleLevel: { viewModel.toggleLevel($0) },
                onClose: { isRangeSheetPresented = false }
            )
        }
        .overlay(alignment: .top) {
            if viewModel.isShuffling {
                ShuffleHUD()
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
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
        Button(action: onTap) {
            Image(systemName: "book.fill")
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
        .accessibilityLabel("복습")
    }
}

private struct ShuffleHUD: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shuffle")
                .rotationEffect(isAnimating ? .degrees(360) : .degrees(0))
                .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            Text("단어를 셔플합니다.")
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
    private let availableLevels: [JLPTLevel]

    init(initialLevels: Set<JLPTLevel>, availableLevels: [JLPTLevel]) {
        _selectedLevels = State(initialValue: initialLevels)
        _reviewOnly = State(initialValue: false)
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
            onToggleLevel: { toggleLevel($0) },
            onClose: {}
        )
    }
}
