import SwiftUI

struct NotebookListView<Header: View>: View {
    @ObservedObject var store: NotebookStore
    @ViewBuilder let header: () -> Header

    var body: some View {
        List {
            header()

            if store.notebooks.isEmpty {
                emptyState
            } else {
                ForEach(store.notebooks) { notebook in
                    NavigationLink {
                        NotebookDetailView(store: store, notebookId: notebook.id)
                    } label: {
                        notebookRow(notebook)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

private extension NotebookListView {
    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text("아직 만든 단어장이 없어요")
                .font(.headline)

            Text("+ 버튼으로 첫 단어장을 만들어 보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
    }
}

#Preview {
    NotebookListView(store: previewStore) {
        EmptyView()
    }
}

@MainActor
private var previewStore: NotebookStore {
    let defaults = UserDefaults(suiteName: "NotebookListView.preview")!
    defaults.removeObject(forKey: "word_notebooks")
    let store = NotebookStore(userDefaults: defaults)
    store.addNotebook(title: "N5 동사")
    store.addNotebook(title: "회화 표현")
    if let notebookId = store.notebooks.first?.id {
        store.addItem(to: notebookId, word: "食べる", reading: "たべる", meaning: "먹다")
    }
    return store
}
