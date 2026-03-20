import SwiftUI

struct NotebookPickerSheetView: View {
    @ObservedObject var store: NotebookStore
    let wordId: Int?
    let word: String
    let reading: String?
    let meaning: String
    let onSelect: (NotebookStore.AddJLPTWordResult) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                previewSection

                if store.notebooks.isEmpty {
                    emptyState
                } else {
                    ForEach(store.notebooks) { notebook in
                        Button {
                            let result = store.addJLPTWord(
                                to: notebook.id,
                                wordId: wordId,
                                word: word,
                                reading: reading,
                                meaning: meaning
                            )
                            onSelect(result)
                            dismiss()
                        } label: {
                            notebookRow(notebook)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("내 단어장에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension NotebookPickerSheetView {
    var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(word)
                .font(.title3.weight(.semibold))

            if let reading, reading.isEmpty == false {
                Text(reading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("아직 만든 단어장이 없어요")
                .font(.headline)

            Text("먼저 내 단어장에서 단어장을 만들어 주세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    func notebookRow(_ notebook: WordNotebook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notebook.title)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(notebook.items.count)개 단어", systemImage: "text.book.closed")
                Text(notebook.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "NotebookPickerSheetView.preview")!
    defaults.removeObject(forKey: "word_notebooks")
    let store = NotebookStore(userDefaults: defaults)
    store.addNotebook(title: "N3 표현")

    return NotebookPickerSheetView(
        store: store,
        wordId: 1,
        word: "伝言",
        reading: "でんごん",
        meaning: "전언 / 전갈"
    ) { _ in }
}
