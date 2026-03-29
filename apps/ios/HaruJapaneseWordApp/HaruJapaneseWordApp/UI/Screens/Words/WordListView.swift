import SwiftUI

struct WordListView: View {
    enum WordTab {
        case jlpt
        case notebook
    }

    @ObservedObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository
    @StateObject private var notebookStore = NotebookStore()
    @State private var isRangeSheetPresented: Bool = false
    @State private var isCreateNotebookPresented: Bool = false
    @State private var lastRefreshAction: WordListViewModel.RefreshAction = .shuffled
    @State private var selectedTab: WordTab = .jlpt
    @State private var selectedWord: WordListItem?
    @State private var selectedNotebook: WordNotebook?
    @AppStorage("words.showMeaning") private var showMeaning: Bool = true

    init(repository: DictionaryRepository, viewModel: WordListViewModel) {
        self.repository = repository
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                screenBackground
                    .ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .jlpt:
                        jlptContent
                    case .notebook:
                        notebookContent
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedWord) { word in
                    destinationView(for: word)
                }
                .navigationDestination(item: $selectedNotebook) { notebook in
                    NotebookDetailView(store: notebookStore, notebookId: notebook.id)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: viewModel.searchText) {
            viewModel.search()
        }
        .onAppear {
            viewModel.refreshReviewState()
        }
        .onReceive(notebookStore.$notebooks) { notebooks in
            viewModel.updateNotebooks(notebooks)
        }
        .task {
            viewModel.updateNotebooks(notebookStore.notebooks)
            viewModel.load()
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            LevelFilterSheetContent(
                showMeaning: showMeaning,
                onSetShowMeaning: { showMeaning = $0 },
                showJLPTWords: viewModel.showJLPTWords,
                onSetShowJLPTWords: { viewModel.setShowJLPTWords($0) },
                showNotebookWords: viewModel.showNotebookWords,
                onSetShowNotebookWords: { viewModel.setShowNotebookWords($0) },
                availableLevels: viewModel.availableLevels,
                isLevelSelected: { viewModel.selectedLevels.contains($0) },
                notebooks: notebookStore.notebooks,
                isNotebookSelected: { viewModel.isNotebookSelected($0) },
                onToggleNotebook: { viewModel.toggleNotebookSelection($0) },
                isReviewOnly: viewModel.reviewOnly,
                onToggleReviewOnly: { viewModel.toggleReviewOnly() },
                isShuffleLocked: viewModel.preferences.shuffleLocked,
                onToggleShuffleLocked: { viewModel.setShuffleLocked($0) },
                onToggleLevel: { viewModel.toggleLevel($0) },
                onClose: { isRangeSheetPresented = false }
            )
        }
        .sheet(isPresented: $isCreateNotebookPresented) {
            CreateNotebookView(store: notebookStore)
        }
        .overlay(alignment: .top) {
            if selectedTab == .jlpt, viewModel.isShuffling {
                ShuffleHUD(action: lastRefreshAction)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
    }

}

private extension WordListView {
    @ViewBuilder
    var jlptContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.hasError {
            emptyStateView()
        } else {
            List {
                headerRow
                tabRow
                searchRow

                if viewModel.displayedWords.isEmpty {
                    emptyFilteredStateRow
                } else {
                    ForEach(viewModel.displayedWords) { word in
                        Button {
                            selectedWord = word
                        } label: {
                            WordRow(
                                word: word,
                                isReviewWord: viewModel.isReviewWord(word),
                                showMeaning: showMeaning
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let wordId = word.jlptWordId {
                                if viewModel.isReviewWord(wordId) {
                                    Button {
                                        viewModel.toggleReview(wordId)
                                    } label: {
                                        Label("해제", systemImage: "book.fill")
                                    }
                                    .tint(.secondary)
                                } else {
                                    Button {
                                        viewModel.toggleReview(wordId)
                                    } label: {
                                        Label("복습", systemImage: "book.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                let action = await viewModel.pullToRefresh()
                lastRefreshAction = action
            }
        }
    }

    var notebookContent: some View {
        NotebookListView(store: notebookStore, onSelectNotebook: { notebook in
            selectedNotebook = notebook
        }) {
            headerRow
            tabRow
            searchRow
        }
    }

    var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                isCreateNotebookPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.iconPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.surfaceSecondary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.divider, lineWidth: 1))
                    .shadow(color: Color.appShadow, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                isRangeSheetPresented = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(selectedTab == .jlpt ? Color.iconPrimary : Color.iconSecondary)
                    .frame(width: 38, height: 38)
                    .background(Color.surfaceSecondary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.divider, lineWidth: 1))
                    .shadow(color: Color.appShadow, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedTab != .jlpt)
        }
    }

    var headerRow: some View {
        headerContent
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var tabRow: some View {
        tabContent
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var searchRow: some View {
        searchContent
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    var headerContent: some View {
        HStack(spacing: 12) {
            Text("단어")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            actionButtons
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    var searchContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.iconSecondary)

            TextField("", text: $viewModel.searchText, prompt: Text("검색").foregroundStyle(Color.textTertiary))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Color.textPrimary)

            if viewModel.searchText.isEmpty == false {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.iconSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appSecondarySurfaceStyle(cornerRadius: 16)
    }

    var tabContent: some View {
        HStack(spacing: 10) {
            WordTabButton(title: "단어", isSelected: selectedTab == .jlpt) {
                selectedTab = .jlpt
            }

            WordTabButton(title: "내 단어장", isSelected: selectedTab == .notebook) {
                selectedTab = .notebook
            }

            Spacer()
        }
    }

    @ViewBuilder
    func emptyStateView() -> some View {
        VStack(spacing: 12) {
            Text("단어를 불러오지 못했어요")
                .font(.headline)
            Text("잠시 후 다시 시도해 주세요")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Button("다시 시도") {
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)

            #if DEBUG
            if let debugError = viewModel.debugError {
                Text(debugError)
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            #endif
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    func destinationView(for word: WordListItem) -> some View {
        switch word.source {
        case let .jlpt(_, wordId):
            WordDetailView(wordId: wordId, repository: repository, notebookStore: notebookStore)
        case let .notebook(notebookId, itemId):
            NotebookWordDetailView(store: notebookStore, notebookId: notebookId, itemId: itemId)
        }
    }

    var emptyFilteredStateRow: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundStyle(Color.iconSecondary)

            Text("선택한 조건에 맞는 단어가 없어요")
                .font(.headline)

            Text("데이터 소스나 레벨, 단어장을 다시 선택해 보세요")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var screenBackground: some View {
        Color.appBackground
    }
}

private struct WordTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.chipActive : Color.chipInactive)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.chipActive.opacity(0.65) : Color.divider, lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: Color.appShadow.opacity(isSelected ? 0.9 : 0.55), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(isOn ? Color.white : Color.textSecondary)
                .frame(minWidth: chipMinWidth, minHeight: chipHeight)
                .background(isOn ? Color.chipActive : Color.chipInactive)
                .overlay(
                    Capsule()
                        .stroke(isOn ? Color.chipActive : Color.divider, lineWidth: 1)
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
        let activeColor: Color = .chipActive
        Button(action: onTap) {
            Image(systemName: "book.fill")
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? Color.white : Color.textSecondary)
                .frame(minWidth: chipMinWidth, minHeight: chipHeight)
                .background(isOn ? activeColor : Color.chipInactive)
                .overlay(
                    Capsule()
                        .stroke(isOn ? activeColor : Color.divider, lineWidth: 1)
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
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.surfaceSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.divider, lineWidth: 1))
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
    let showMeaning: Bool
    let onSetShowMeaning: (Bool) -> Void
    let showJLPTWords: Bool
    let onSetShowJLPTWords: (Bool) -> Void
    let showNotebookWords: Bool
    let onSetShowNotebookWords: (Bool) -> Void
    let availableLevels: [JLPTLevel]
    let isLevelSelected: (JLPTLevel) -> Bool
    let notebooks: [WordNotebook]
    let isNotebookSelected: (UUID) -> Bool
    let onToggleNotebook: (UUID) -> Void
    let isReviewOnly: Bool
    let onToggleReviewOnly: () -> Void
    let isShuffleLocked: Bool
    let onToggleShuffleLocked: (Bool) -> Void
    let onToggleLevel: (JLPTLevel) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("데이터 소스") {
                    Toggle("JLPT 단어", isOn: Binding(
                        get: { showJLPTWords },
                        set: { onSetShowJLPTWords($0) }
                    ))

                    Toggle("내 단어장", isOn: Binding(
                        get: { showNotebookWords },
                        set: { onSetShowNotebookWords($0) }
                    ))
                }

                if showJLPTWords {
                    Section("JLPT 레벨 선택") {
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

                if showNotebookWords {
                    Section("내 단어장 선택") {
                        if notebooks.isEmpty {
                            Text("아직 만든 단어장이 없어요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(notebooks) { notebook in
                                Button {
                                    onToggleNotebook(notebook.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(notebook.title)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text("\(notebook.items.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: isNotebookSelected(notebook.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isNotebookSelected(notebook.id) ? Color.accentColor : Color.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Toggle("뜻 보기", isOn: Binding(
                        get: { showMeaning },
                        set: { onSetShowMeaning($0) }
                    ))
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
    @State private var showMeaning: Bool
    @State private var showJLPTWords: Bool
    @State private var showNotebookWords: Bool
    @State private var selectedNotebookIds: Set<UUID>
    private let availableLevels: [JLPTLevel]
    private let notebooks: [WordNotebook]

    init(initialLevels: Set<JLPTLevel>, availableLevels: [JLPTLevel]) {
        _selectedLevels = State(initialValue: initialLevels)
        _reviewOnly = State(initialValue: false)
        _shuffleLocked = State(initialValue: false)
        _showMeaning = State(initialValue: true)
        _showJLPTWords = State(initialValue: true)
        _showNotebookWords = State(initialValue: true)
        let previewNotebooks = [
            WordNotebook(title: "회화 표현", items: [WordNotebookItem(word: "伝言", reading: "でんごん", meaning: "전언")]),
            WordNotebook(title: "N4 동사", items: [WordNotebookItem(word: "続ける", reading: "つづける", meaning: "계속하다")])
        ]
        _selectedNotebookIds = State(initialValue: Set(previewNotebooks.map(\.id)))
        self.availableLevels = availableLevels
        self.notebooks = previewNotebooks
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
            showMeaning: showMeaning,
            onSetShowMeaning: { showMeaning = $0 },
            showJLPTWords: showJLPTWords,
            onSetShowJLPTWords: { showJLPTWords = $0 },
            showNotebookWords: showNotebookWords,
            onSetShowNotebookWords: { showNotebookWords = $0 },
            availableLevels: availableLevels,
            isLevelSelected: { selectedLevels.contains($0) },
            notebooks: notebooks,
            isNotebookSelected: { selectedNotebookIds.contains($0) },
            onToggleNotebook: { notebookId in
                if selectedNotebookIds.contains(notebookId) {
                    selectedNotebookIds.remove(notebookId)
                } else {
                    selectedNotebookIds.insert(notebookId)
                }
            },
            isReviewOnly: reviewOnly,
            onToggleReviewOnly: { reviewOnly.toggle() },
            isShuffleLocked: shuffleLocked,
            onToggleShuffleLocked: { shuffleLocked = $0 },
            onToggleLevel: { toggleLevel($0) },
            onClose: {}
        )
    }
}
