import SwiftUI

struct NotebookWordDetailView: View {
    let item: WordNotebookItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoSection
                memoSection
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("단어")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension NotebookWordDetailView {
    var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("단어 정보")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.word)
                    .font(.system(size: 30, weight: .bold))

                Text(item.reading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text(item.meaning)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = item.note, note.isEmpty == false {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else {
                Text("메모가 없어요")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        NotebookWordDetailView(
            item: WordNotebookItem(
                word: "伝言",
                reading: "でんごん",
                meaning: "전언",
                note: "전화 오면 전해달라는 뜻으로 자주 써요."
            )
        )
    }
}
