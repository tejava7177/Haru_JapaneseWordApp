import SwiftUI

struct WordDetailView: View {
    @StateObject private var viewModel: WordDetailViewModel
    @State private var isReadingExpanded: Bool = false
    private let wordId: Int
    private let repository: DictionaryRepository

    init(wordId: Int, repository: DictionaryRepository) {
        self.wordId = wordId
        self.repository = repository
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(repository: repository))
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
                    ReviewSwipeCard(isReviewWord: $viewModel.isReview, onToggle: {
                        viewModel.toggleReview()
                    }) {
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
                    }

                    MeaningCard(meanings: detail.meanings)

                    if viewModel.recommendations.isEmpty == false {
                        RecommendationSection(
                            recommendations: viewModel.recommendations,
                            repository: repository
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
        .task(id: wordId) {
            viewModel.load(wordId: wordId)
        }
    }

    private func displayExpression(for detail: WordDetail) -> String {
        let trimmed = detail.expression.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? detail.reading : detail.expression
    }
}

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
                        onToggleReview()
                    } label: {
                        Image(systemName: isReviewWord ? "book.fill" : "book")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isReviewWord ? Color.orange : .secondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
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

private struct ReviewSwipeCard<Content: View>: View {
    @Binding var isReviewWord: Bool
    let onToggle: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var cardWidth: CGFloat = 0
    private let content: Content
    private let cornerRadius: CGFloat = 18

    init(isReviewWord: Binding<Bool>, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        _isReviewWord = isReviewWord
        self.onToggle = onToggle
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ReviewActionBackground(isReviewWord: isReviewWord)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            content
                .offset(x: dragOffset)
        }
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ReviewCardWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ReviewCardWidthKey.self) { value in
            cardWidth = value
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let translation = max(0, value.translation.width)
                    dragOffset = min(translation, cardWidth)
                }
                .onEnded { value in
                    let translation = max(0, value.translation.width)
                    let threshold = cardWidth * 0.6
                    if translation >= threshold {
                        toggleReview()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
        )
    }

    private func toggleReview() {
        onToggle()
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
}

private struct ReviewActionBackground: View {
    let isReviewWord: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("복습 단어")
                .font(.footnote)
                .fontWeight(.semibold)
        }
        .foregroundStyle(isReviewWord ? Color(uiColor: .systemGreen) : Color.accentColor)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isReviewWord ? Color(uiColor: .systemGreen).opacity(0.18) : Color.accentColor.opacity(0.18))
    }
}

private struct ReviewCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                            WordDetailView(wordId: word.id, repository: repository)
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
