import SwiftUI

struct WordRow: View {
    let word: WordSummary

    var body: some View {
        let meaningsText = word.meanings.isEmpty ? "—" : word.meanings
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.expression)
                    .font(.headline)

                Spacer(minLength: 8)

                Text(word.level.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.04))
                    .clipShape(Capsule())
            }

            Text(meaningsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WordRow(word: WordSummary(id: 1, level: .n5, expression: "例", reading: "れい", meanings: "예 / 예시"))
        .padding()
}
