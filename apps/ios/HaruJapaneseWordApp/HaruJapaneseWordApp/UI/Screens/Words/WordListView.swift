import SwiftUI

struct WordListView: View {
    @StateObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository
    @State private var isRangeSheetPresented: Bool = false
    @State private var reviewWordIds: Set<Int> = []
    private let reviewStore = ReviewWordStore()
    @State private var navigationPath = NavigationPath()

    init(repository: DictionaryRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                } else if viewModel.selectedLevels.isEmpty {
                    Text("선택된 레벨이 없어요.")
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.displayedWords) { word in
                        ReviewSwipeRow(
                            isReviewWord: isReviewWord(word.id),
                            onToggleReview: { toggleReview(word.id) },
                            onTap: { navigationPath.append(word.id) }
                        ) {
                            WordRow(word: word, isReviewWord: isReviewWord(word.id))
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.shuffleByPull()
                    }
                }
            }
            .navigationTitle("단어")
        }
        .navigationDestination(for: Int.self) { wordId in
            WordDetailView(wordId: wordId, repository: repository)
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "검색")
        .onChange(of: viewModel.searchText) { _ in
            viewModel.search()
        }
        .task {
            viewModel.load()
            reviewWordIds = reviewStore.loadReviewSet()
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            LevelFilterSheetContent(
                availableLevels: viewModel.availableLevels,
                isAllOn: viewModel.isAllOn,
                isLevelSelected: { viewModel.selectedLevels.contains($0) },
                onToggleAll: { viewModel.setAllLevels($0) },
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

    private func isReviewWord(_ wordId: Int) -> Bool {
        reviewWordIds.contains(wordId)
    }

    private func addToReview(_ wordId: Int) {
        reviewWordIds.insert(wordId)
        reviewStore.saveReviewSet(reviewWordIds)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    private func removeFromReview(_ wordId: Int) {
        reviewWordIds.remove(wordId)
        reviewStore.saveReviewSet(reviewWordIds)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    private func toggleReview(_ wordId: Int) {
        if isReviewWord(wordId) {
            removeFromReview(wordId)
        } else {
            addToReview(wordId)
        }
    }
}

private struct LevelToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    private let chipHeight: CGFloat = 36
    private let chipMinWidth: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
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
    let onTap: () -> Void
    private let chipHeight: CGFloat = 36
    private let chipMinWidth: CGFloat = 52

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "book.fill")
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(Color(uiColor: .darkGray))
                .frame(minWidth: chipMinWidth, minHeight: chipHeight)
                .background(Color(uiColor: .systemGray5))
                .overlay(
                    Capsule()
                        .stroke(Color(uiColor: .systemGray3), lineWidth: 1)
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
    WordListView(repository: StubDictionaryRepository())
}

#Preview("필터-초기") {
    LevelFilterSheetPreview(
        initialLevels: Set(JLPTLevel.allCases),
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
    let isAllOn: Bool
    let isLevelSelected: (JLPTLevel) -> Bool
    let onToggleAll: (Bool) -> Void
    let onToggleLevel: (JLPTLevel) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("전체")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isAllOn },
                            set: { onToggleAll($0) }
                        ))
                        .labelsHidden()
                    }
                }

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
                                BookChip {
                                    // TODO: review filter
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
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
    private let availableLevels: [JLPTLevel]

    init(initialLevels: Set<JLPTLevel>, availableLevels: [JLPTLevel]) {
        _selectedLevels = State(initialValue: initialLevels)
        self.availableLevels = availableLevels
    }

    private var isAllOn: Bool {
        let availableSet = Set(availableLevels)
        return availableSet.isEmpty == false && selectedLevels == availableSet
    }

    private func setAll(_ isOn: Bool) {
        if isOn {
            selectedLevels = Set(availableLevels)
        } else if let fallback = availableLevels.last {
            selectedLevels = [fallback]
        }
    }

    private func toggleLevel(_ level: JLPTLevel) {
        if selectedLevels.contains(level) {
            if selectedLevels.count == 1 { return }
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    var body: some View {
        LevelFilterSheetContent(
            availableLevels: availableLevels,
            isAllOn: isAllOn,
            isLevelSelected: { selectedLevels.contains($0) },
            onToggleAll: { setAll($0) },
            onToggleLevel: { toggleLevel($0) },
            onClose: {}
        )
    }
}
