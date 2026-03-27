import SwiftUI

struct WordRow: View {
    let word: WordListItem
    let isReviewWord: Bool
    let showMeaning: Bool

    var body: some View {
        let meaningsText = word.meaning.isEmpty ? "—" : word.meaning
        VStack(alignment: .leading, spacing: showMeaning ? 6 : 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.word)
                    .font(.headline)

                Spacer(minLength: 8)

                if let level = word.jlptLevel {
                    Text(level.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Capsule())
                }

                if word.isNotebookWord {
                    Text("📘")
                        .font(.caption2)
                }

                if isReviewWord {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if showMeaning {
                Text(meaningsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    WordRow(
        word: WordListItem(
            wordSummary: WordSummary(id: 1, level: .n5, expression: "例", reading: "れい", meanings: "예 / 예시")
        ),
        isReviewWord: true,
        showMeaning: true
    )
        .padding()
}
