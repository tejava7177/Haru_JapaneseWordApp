import SwiftUI

struct WordRow: View {
    let word: WordListItem
    let isReviewWord: Bool
    let showMeaning: Bool

    var body: some View {
        let meaningsText = word.meaning.isEmpty ? "—" : word.meaning
        let verticalPadding: CGFloat = showMeaning ? 12 : 15
        VStack(alignment: .leading, spacing: showMeaning ? 6 : 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.word)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Spacer(minLength: 8)

                if let level = word.jlptLevel {
                    Text(level.title)
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.chipInactive)
                        .clipShape(Capsule())
                }

                if word.isNotebookWord {
                    Text("📘")
                        .font(.caption2)
                }

                if isReviewWord {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.chipActive)
                }
            }

            if showMeaning {
                Text(meaningsText)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, verticalPadding)
        .appCardStyle(cornerRadius: 16)
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
