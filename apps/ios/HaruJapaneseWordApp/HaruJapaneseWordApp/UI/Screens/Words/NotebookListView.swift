import SwiftUI

struct NotebookListView<Header: View>: View {
    @ObservedObject var store: NotebookStore
    let isLoggedIn: Bool
    let onSelectNotebook: (WordNotebook) -> Void
    let onRequestLogin: () -> Void
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
            if isLoggedIn {
                Image(systemName: "books.vertical")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.iconSecondary)

                Text("아직 만든 단어장이 없어요")
                    .font(.headline)

                Text("+ 버튼으로 첫 단어장을 만들어 보세요")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.iconSecondary)

                Text("로그인하고 나만의 단어장을 만들어보세요")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("단어장을 만들고, 단어를 저장하고, \n다시 로그인해도 이어서 학습할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                Button("로그인하기") {
                    onRequestLogin()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
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
                            Color.brandSoft,
                            Color.surfaceSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "text.book.closed")
                        .foregroundStyle(Color.chipActive)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(notebook.title)
                    .font(.headline)

                Text("\(notebook.items.count)개 단어 · \(notebook.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 12)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCardStyle(cornerRadius: 16, shadowRadius: 12, shadowY: 4)
    }
}

#Preview {
    NotebookListView(store: previewStore, isLoggedIn: true, onSelectNotebook: { _ in }, onRequestLogin: {}) {
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
