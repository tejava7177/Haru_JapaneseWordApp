import SwiftUI

struct NotebookWordDetailView: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    let itemId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var isEditPresented: Bool = false
    @State private var isDeleteDialogPresented: Bool = false

    private var item: WordNotebookItem? {
        store.item(for: notebookId, itemId: itemId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoSection
                if let note = item?.note, note.isEmpty == false {
                    memoSection(note: note)
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("단어")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("수정") {
                        isEditPresented = true
                    }

                    Button("삭제", role: .destructive) {
                        isDeleteDialogPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(item == nil)
            }
        }
        .sheet(isPresented: $isEditPresented) {
            if let item {
                AddNotebookWordView(store: store, notebookId: notebookId, editingItem: item)
            }
        }
        .confirmationDialog("이 단어를 삭제할까요?", isPresented: $isDeleteDialogPresented, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                store.deleteItem(in: notebookId, itemId: itemId)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }
}

private extension NotebookWordDetailView {
    var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("단어 정보")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(item?.word ?? "")
                    .font(.system(size: 30, weight: .bold))

                if let reading = item?.reading, reading.isEmpty == false {
                    Text(reading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(item?.meaning ?? "")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func memoSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note)
                .font(.body)
                .foregroundStyle(.primary)
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
            store: wordDetailPreviewStore,
            notebookId: wordDetailPreviewStore.notebooks[0].id,
            itemId: wordDetailPreviewStore.notebooks[0].items[0].id
        )
    }
}

@MainActor
private var wordDetailPreviewStore: NotebookStore {
    let defaults = UserDefaults(suiteName: "NotebookWordDetailView.preview")!
    defaults.removeObject(forKey: "word_notebooks")
    let store = NotebookStore(userDefaults: defaults)
    store.addNotebook(title: "표현")
    if let notebookId = store.notebooks.first?.id {
        store.addItem(to: notebookId, word: "伝言", reading: "でんごん", meaning: "전언", note: "전화 오면 전해달라는 뜻으로 자주 써요.")
    }
    return store
}
