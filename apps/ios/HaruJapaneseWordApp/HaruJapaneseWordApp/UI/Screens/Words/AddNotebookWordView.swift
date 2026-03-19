import SwiftUI

struct AddNotebookWordView: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var word: String = ""
    @State private var reading: String = ""
    @State private var meaning: String = ""
    @State private var note: String = ""

    private var canSave: Bool {
        word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("단어", text: $word)
                    TextField("읽기", text: $reading)
                    TextField("의미", text: $meaning, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("메모") {
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("예문, 암기 팁, 메모를 자유롭게 적어보세요")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("단어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        store.addItem(to: notebookId, word: word, reading: reading, meaning: meaning, note: note)
                        dismiss()
                    }
                    .disabled(canSave == false)
                }
            }
        }
    }
}

#Preview {
    AddNotebookWordView(store: addWordPreviewStore, notebookId: addWordPreviewStore.notebooks[0].id)
}

@MainActor
private var addWordPreviewStore: NotebookStore {
    let defaults = UserDefaults(suiteName: "AddNotebookWordView.preview")!
    defaults.removeObject(forKey: "word_notebooks")
    let store = NotebookStore(userDefaults: defaults)
    store.addNotebook(title: "동사 모음")
    return store
}
