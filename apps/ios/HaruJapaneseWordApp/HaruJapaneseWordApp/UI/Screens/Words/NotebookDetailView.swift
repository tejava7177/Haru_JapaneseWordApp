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
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
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
        VStack(alignment: .leading, spacing: 10) {
            Text("단어 \(items.count)개")
                .font(.headline)
                .foregroundStyle(.primary)

            if let descriptionText = notebook?.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
               descriptionText.isEmpty == false {
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 10, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text("아직 단어가 없어요")
                .font(.headline)

            Text("첫 단어를 추가해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 72)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    func itemRow(_ item: WordNotebookItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.word)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(item.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.015), radius: 2, x: 0, y: 1)
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
