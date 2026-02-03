import SwiftUI

struct WordRow: View {
    let word: WordSummary

    var body: some View {
        let meaningsText = word.meanings.isEmpty ? "—" : word.meanings
        VStack(alignment: .leading, spacing: 6) {
            Text(word.expression)
                .font(.headline)

            Text(meaningsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WordRow(word: WordSummary(id: 1, expression: "例", reading: "れい", meanings: "예 / 예시"))
        .padding()
}
