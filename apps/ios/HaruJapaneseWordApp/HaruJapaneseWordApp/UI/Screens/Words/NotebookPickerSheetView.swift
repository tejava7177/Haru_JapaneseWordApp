import SwiftUI

struct NotebookPickerSheetView: View {
    @ObservedObject var store: NotebookStore
    let wordId: Int?
    let word: String
    let reading: String?
    let meaning: String
    let onSelect: (NotebookStore.AddJLPTWordResult) -> Void
    let onOpenNotebook: (WordNotebook) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var duplicateNotebook: WordNotebook?

    var body: some View {
        NavigationStack {
            List {
                previewSection

                if store.notebooks.isEmpty {
                    emptyState
                } else {
                    ForEach(store.notebooks) { notebook in
                        let isAlreadyAdded = store.containsJLPTWord(
                            wordId: wordId,
                            word: word,
                            reading: reading,
                            in: notebook.id
                        )

                        Button {
                            print("[NotebookPicker] notebook tapped title=\(notebook.title) isAlreadyAdded=\(isAlreadyAdded)")

                            if isAlreadyAdded {
                                print("[NotebookPicker] duplicate branch entered notebookId=\(notebook.id)")
                                duplicateNotebook = notebook
                                print("[NotebookPicker] alert state set true notebookId=\(notebook.id)")
                                return
                            }

                            let result = store.addJLPTWord(
                                to: notebook.id,
                                wordId: wordId,
                                word: word,
                                reading: reading,
                                meaning: meaning
                            )
                            print("[NotebookPicker] add result=\(String(describing: result)) notebookId=\(notebook.id)")
                            onSelect(result)
                            dismiss()
                        } label: {
                            notebookRow(notebook, isAlreadyAdded: isAlreadyAdded)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("내 단어장에 추가")
            .navigationBarTitleDisplayMode(.inline)
            .alert(item: $duplicateNotebook) { notebook in
                Alert(
                    title: Text("이미 추가된 단어예요"),
                    message: Text("이 단어는 이미 \"\(notebook.title)\" 단어장에 저장되어 있어요. 단어장을 열어 확인해볼까요?"),
                    primaryButton: .default(Text("단어장 보기")) {
                        print("[NotebookPicker] open notebook action tapped notebookId=\(notebook.id)")
                        dismiss()
                        onOpenNotebook(notebook)
                    },
                    secondaryButton: .cancel(Text("닫기")) {
                        print("[NotebookPicker] duplicate alert dismissed notebookId=\(notebook.id)")
                    }
                )
            }
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
    var resolvedWordId: Int? {
        wordId
    }

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

    func notebookRow(_ notebook: WordNotebook, isAlreadyAdded: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
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

            Spacer(minLength: 8)

            if isAlreadyAdded {
                Text("이미 추가됨")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
            }
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
    ) { _ in
    } onOpenNotebook: { _ in
    }
}
