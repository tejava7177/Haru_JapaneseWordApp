import SwiftUI

struct WordDetailView: View {
    @StateObject private var viewModel: WordDetailViewModel
    @State private var isReadingExpanded: Bool = false

    init(wordId: Int, repository: DictionaryRepository) {
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(wordId: wordId, repository: repository))
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
                        isExpanded: $isReadingExpanded
                    )

                    MeaningCard(meanings: detail.meanings)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("단어 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
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
}
