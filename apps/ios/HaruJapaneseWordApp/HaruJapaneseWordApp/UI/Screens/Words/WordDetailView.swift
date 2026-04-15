import SwiftUI

struct WordDetailView: View {
    @StateObject private var viewModel: WordDetailViewModel
    @StateObject private var notebookStore: NotebookStore
    @ObservedObject private var settingsStore: AppSettingsStore
    @State private var isReadingExpanded: Bool = false
    @State private var isNotebookPickerPresented: Bool = false
    @State private var isCreateNotebookPresented: Bool = false
    @State private var isCreateNotebookPromptPresented: Bool = false
    @State private var shouldResumeNotebookAddFlow: Bool = false
    @State private var feedbackMessage: String?
    @State private var selectedNotebook: WordNotebook?
    private let wordId: Int
    private let repository: DictionaryRepository

    @MainActor
    init(wordId: Int, repository: DictionaryRepository) {
        self.init(
            wordId: wordId,
            repository: repository,
            notebookStore: NotebookStore.shared,
            settingsStore: AppSettingsStore()
        )
    }

    @MainActor
    init(wordId: Int, repository: DictionaryRepository, settingsStore: AppSettingsStore) {
        self.init(
            wordId: wordId,
            repository: repository,
            notebookStore: NotebookStore.shared,
            settingsStore: settingsStore
        )
    }

    @MainActor
    init(
        wordId: Int,
        repository: DictionaryRepository,
        notebookStore: NotebookStore,
        settingsStore: AppSettingsStore? = nil
    ) {
        self.wordId = wordId
        self.repository = repository
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(repository: repository))
        _notebookStore = StateObject(wrappedValue: notebookStore)
        _settingsStore = ObservedObject(wrappedValue: settingsStore ?? AppSettingsStore())
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 32)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)
            } else if let detail = viewModel.detail {
                VStack(alignment: .leading, spacing: 20) {
                    WordHeaderCard(
                        expression: displayExpression(for: detail),
                        rawExpression: detail.expression,
                        reading: detail.reading,
                        level: detail.level.title,
                        meanings: detail.meanings,
                        isExpanded: $isReadingExpanded,
                        isReviewWord: viewModel.isReview,
                        onToggleReview: { viewModel.toggleReview() }
                    )

                    MeaningCard(meanings: detail.meanings)

                    if viewModel.recommendations.isEmpty == false {
                        RecommendationSection(
                            recommendations: viewModel.recommendations,
                            repository: repository,
                            notebookStore: notebookStore,
                            settingsStore: settingsStore
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("단어 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.detail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("내 단어장에 추가") {
                            handleAddToNotebookTapped()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isNotebookPickerPresented) {
            if let detail = viewModel.detail {
                NotebookPickerSheetView(
                    store: notebookStore,
                    wordId: detail.id,
                    word: displayExpression(for: detail),
                    reading: detail.reading,
                    meaning: notebookMeaning(for: detail)
                ) { result in
                    handleNotebookPickResult(result)
                } onOpenNotebook: { notebook in
                    selectedNotebook = notebook
                }
            }
        }
        .sheet(isPresented: $isCreateNotebookPresented) {
            CreateNotebookView(store: notebookStore, onCreated: { notebook in
                handleNotebookCreated(notebook)
            })
        }
        .alert("단어장이 없어요", isPresented: $isCreateNotebookPromptPresented) {
            Button("취소", role: .cancel) {
                shouldResumeNotebookAddFlow = false
            }
            Button("단어장 만들기") {
                shouldResumeNotebookAddFlow = true
                isCreateNotebookPresented = true
            }
        } message: {
            Text("단어를 저장하려면 먼저 단어장을 만들어야 해요. 지금 바로 만들까요?")
        }
        .overlay(alignment: .top) {
            if let feedbackMessage {
                FeedbackBanner(message: feedbackMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedNotebook) { notebook in
            NavigationStack {
                NotebookDetailView(store: notebookStore, notebookId: notebook.id, repository: repository)
            }
        }
        .task(id: wordId) {
            viewModel.load(wordId: wordId)
        }
    }

    private func displayExpression(for detail: WordDetail) -> String {
        let trimmed = detail.expression.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? detail.reading : detail.expression
    }

    private func notebookMeaning(for detail: WordDetail) -> String {
        detail.meanings
            .sorted(by: { $0.ord < $1.ord })
            .map(\.text)
            .joined(separator: " / ")
    }

    private var isNotebookCreationAvailable: Bool {
        settingsStore.currentBackendUserId?.isEmpty == false
    }

    private func handleAddToNotebookTapped() {
        guard isNotebookCreationAvailable else {
            showFeedbackMessage("단어장은 로그인 후 만들 수 있어요")
            NotificationCenter.default.post(name: .wordListRequiresLoginNavigation, object: nil)
            return
        }

        guard notebookStore.notebooks.isEmpty else {
            isNotebookPickerPresented = true
            return
        }

        isCreateNotebookPromptPresented = true
    }

    private func handleNotebookCreated(_ notebook: WordNotebook) {
        guard shouldResumeNotebookAddFlow, let detail = viewModel.detail else { return }

        shouldResumeNotebookAddFlow = false

        Task {
            let result = await notebookStore.addJLPTWord(
                to: notebook.id,
                wordId: detail.id,
                word: displayExpression(for: detail),
                reading: detail.reading,
                meaning: notebookMeaning(for: detail)
            )

            if case .notebookNotFound = result {
                await MainActor.run {
                    isNotebookPickerPresented = true
                }
            }

            await MainActor.run {
                handleNotebookPickResult(result)
            }
        }
    }

    private func handleNotebookPickResult(_ result: NotebookStore.AddJLPTWordResult) {
        let message: String
        let feedbackType: UINotificationFeedbackGenerator.FeedbackType

        switch result {
        case .success:
            message = "단어장에 추가했어요"
            feedbackType = .success
        case .duplicate:
            message = "이미 이 단어장에 추가된 단어예요."
            feedbackType = .warning
        case .notebookNotFound:
            message = "단어장을 찾을 수 없어요"
            feedbackType = .error
        case .saveFailed:
            message = "단어를 저장하지 못했어요. 잠시 후 다시 시도해 주세요"
            feedbackType = .error
        }

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(feedbackType)

        withAnimation(.easeInOut(duration: 0.2)) {
            feedbackMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard feedbackMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                feedbackMessage = nil
            }
        }
    }

    private func showFeedbackMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            feedbackMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard feedbackMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                feedbackMessage = nil
            }
        }
    }
}

#if DEBUG
#Preview {
    let sampleDetail = WordDetail(
        id: 1,
        level: .n5,
        expression: "水曜日",
        reading: "すいようび",
        meanings: [
            Meaning(ord: 1, text: "수요일"),
            Meaning(ord: 2, text: "주중의 세 번째 날"),
            Meaning(ord: 3, text: "수요일(약어: 수)")
        ]
    )
    WordDetailView(wordId: 1, repository: PreviewDictionaryRepository(detail: sampleDetail))
}
#endif

private struct WordHeaderCard: View {
    let expression: String
    let rawExpression: String
    let reading: String
    let level: String
    let meanings: [Meaning]
    @Binding var isExpanded: Bool
    let isReviewWord: Bool
    let onToggleReview: () -> Void
    @State private var didCopy: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(expression)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(level)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(uiColor: .systemGray5)))
                        .foregroundStyle(.secondary)

                    Button {
                        print("[WordDetail] button hit source=reviewButton")
                        onToggleReview()
                    } label: {
                        Image(systemName: isReviewWord ? "book.fill" : "book")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isReviewWord ? Color.orange : .secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                    .accessibilityLabel("복습 단어")

                    copyButton
                }
            }

            if isExpanded {
                Text(reading)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text(isExpanded ? "탭하여 닫기" : "탭하여 읽기 보기")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            print("[WordDetail] surrounding tap ignored action=toggleReading")
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }

    private var copyButton: some View {
        Button {
            copyExpression()
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.2), value: didCopy)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("표제어 복사") { copyExpression() }
            Button("읽기 복사") { copyReading() }
            Button("표제어+읽기 복사") { copyExpressionAndReading() }
            Button("뜻 전체 복사") { copyMeanings() }
        }
        .accessibilityLabel("복사")
    }

    private func copyExpression() {
        let value = normalizedExpression()
        performCopy(value)
    }

    private func copyReading() {
        performCopy(reading)
    }

    private func copyExpressionAndReading() {
        let value = "\(normalizedExpression())\n\(reading)"
        performCopy(value)
    }

    private func copyMeanings() {
        let bullets = meanings
            .sorted { $0.ord < $1.ord }
            .map { "• \($0.text)" }
            .joined(separator: "\n")
        performCopy(bullets)
    }

    private func normalizedExpression() -> String {
        let trimmed = rawExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? reading : rawExpression
    }

    private func performCopy(_ text: String) {
        UIPasteboard.general.string = text
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }
}

private struct MeaningCard: View {
    let meanings: [Meaning]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("의미")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(meanings.sorted(by: { $0.ord < $1.ord })) { meaning in
                    Text("• \(meaning.text)")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct RecommendationSection: View {
    let recommendations: [(kanji: String, words: [WordSummary])]
    let repository: DictionaryRepository
    let notebookStore: NotebookStore
    let settingsStore: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 한자가 들어간 단어")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(recommendations, id: \.kanji) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.kanji)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(uiColor: .systemGray6)))
                        .foregroundStyle(.secondary)

                    ForEach(group.words) { word in
                        NavigationLink {
                            WordDetailView(
                                wordId: word.id,
                                repository: repository,
                                notebookStore: notebookStore,
                                settingsStore: settingsStore
                            )
                        } label: {
                            RecommendationCard(word: word)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
    }
}

private struct FeedbackBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(uiColor: .systemGray5), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct RecommendationCard: View {
    let word: WordSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.expression.isEmpty ? word.reading : word.expression)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                if word.meanings.isEmpty == false {
                    Text(word.meanings)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
    }
}

#if DEBUG
private struct PreviewDictionaryRepository: DictionaryRepository {
    let detail: WordDetail

    func fetchWords(level: JLPTLevel?, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func searchWords(level: JLPTLevel?, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        detail
    }

    func fetchWordSummary(wordId: Int) throws -> WordSummary? {
        nil
    }

    func randomWord(level: JLPTLevel) throws -> WordSummary? {
        nil
    }

    func randomWordIds(level: JLPTLevel, count: Int, excluding ids: Set<Int>) throws -> [Int] {
        []
    }

    func findByExpression(_ expression: String) throws -> WordSummary? {
        nil
    }

    func getRandomWords(limit: Int, excludingExpression: String?) throws -> [WordSummary] {
        []
    }

    func fetchRecommendedWords(level: JLPTLevel, limit: Int) throws -> [WordSummary] {
        []
    }

    func fetchRecommendedWords(
        containing kanji: String,
        currentLevel: JLPTLevel,
        excluding wordId: Int,
        limit: Int
    ) throws -> [WordSummary] {
        []
    }

    func fetchCheckedStates(wordIds: [Int]) throws -> Set<Int> {
        []
    }

    func setChecked(wordId: Int, checked: Bool) throws {
    }
}
#endif
