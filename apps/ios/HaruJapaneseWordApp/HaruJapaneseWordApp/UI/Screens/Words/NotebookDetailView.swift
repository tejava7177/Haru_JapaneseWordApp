import SwiftUI

struct NotebookDetailView: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    @State private var isAddWordPresented: Bool = false
    @State private var isNotebookTitleEditorPresented: Bool = false
    @State private var isNotebookDeleteDialogPresented: Bool = false
    @State private var notebookTitleDraft: String = ""
    @State private var selectedItem: WordNotebookItem?
    @Environment(\.dismiss) private var dismiss

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
                    Button {
                        selectedItem = item
                    } label: {
                        itemRow(item)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.deleteItem(in: notebookId, itemId: item.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(notebook?.title ?? "단어장")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            NotebookWordDetailView(store: store, notebookId: notebookId, itemId: item.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        isAddWordPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.96))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
                    }

                    Menu {
                        Button("이름 수정") {
                            notebookTitleDraft = notebook?.title ?? ""
                            isNotebookTitleEditorPresented = true
                        }

                        Button("삭제", role: .destructive) {
                            isNotebookDeleteDialogPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddWordPresented) {
            AddNotebookWordView(store: store, notebookId: notebookId)
        }
        .alert("단어장 이름 수정", isPresented: $isNotebookTitleEditorPresented) {
            TextField("단어장 이름", text: $notebookTitleDraft)
            Button("취소", role: .cancel) {}
            Button("저장") {
                store.updateNotebookTitle(notebookId, title: notebookTitleDraft)
            }
        } 
        .confirmationDialog("이 단어장을 삭제할까요?", isPresented: $isNotebookDeleteDialogPresented, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                store.deleteNotebook(notebookId)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("포함된 단어도 모두 삭제됩니다")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    func itemRow(_ item: WordNotebookItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.word)
                .font(.headline)

            Text(item.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
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
