import SwiftUI

struct NotebookDetailView: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    @State private var isAddWordPresented: Bool = false

    private var notebook: WordNotebook? {
        store.notebook(for: notebookId)
    }

    private var items: [WordNotebookItem] {
        store.items(for: notebookId)
    }

    var body: some View {
        List {
            summarySection

            if items.isEmpty {
                emptyState
            } else {
                ForEach(items) { item in
                    itemRow(item)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(notebook?.title ?? "단어장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddWordPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddWordPresented) {
            AddNotebookWordView(store: store, notebookId: notebookId)
        }
    }
}

private extension NotebookDetailView {
    var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notebook?.title ?? "단어장")
                .font(.title3.weight(.semibold))

            Text("단어 \(items.count)개")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("아직 단어가 없어요")
                .font(.headline)

            Text("첫 단어를 추가해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    func itemRow(_ item: WordNotebookItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.word)
                .font(.headline)

            Text(item.reading)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(item.meaning)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let note = item.note, note.isEmpty == false {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        NotebookDetailView(store: detailPreviewStore, notebookId: detailPreviewStore.notebooks[0].id)
    }
}

@MainActor
private var detailPreviewStore: NotebookStore {
    let defaults = UserDefaults(suiteName: "NotebookDetailView.preview")!
    defaults.removeObject(forKey: "word_notebooks")
    let store = NotebookStore(userDefaults: defaults)
    store.addNotebook(title: "자주 쓰는 표현")
    if let notebookId = store.notebooks.first?.id {
        store.addItem(to: notebookId, word: "食べる", reading: "たべる", meaning: "먹다")
        store.addItem(to: notebookId, word: "飲む", reading: "のむ", meaning: "마시다")
    }
    return store
}
