import SwiftUI

struct NotebookListView<Header: View>: View {
    @ObservedObject var store: NotebookStore
    let onSelectNotebook: (WordNotebook) -> Void
    @ViewBuilder let header: () -> Header

    var body: some View {
        List {
            header()

            if store.notebooks.isEmpty {
                emptyState
            } else {
                ForEach(store.notebooks) { notebook in
                    Button {
                        onSelectNotebook(notebook)
                    } label: {
                        notebookRow(notebook)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.20),
                            Color.yellow.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "text.book.closed")
                        .foregroundStyle(Color.orange.opacity(0.95))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.title)
                    .font(.headline)

                Text("\(notebook.items.count)개 단어 · \(notebook.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    NotebookListView(store: previewStore, onSelectNotebook: { _ in }) {
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
