import SwiftUI

struct NotebookDetailView: View {
    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    @State private var isAddWordPresented: Bool = false
    @State private var isNotebookEditorPresented: Bool = false
    @State private var isNotebookDeleteDialogPresented: Bool = false
    @State private var notebookTitleDraft: String = ""
    @State private var notebookDescriptionDraft: String = ""
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
        .background(Color.appBackground)
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
                            .foregroundStyle(Color.iconPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceSecondary)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.divider, lineWidth: 1))
                            .shadow(color: Color.appShadow, radius: 10, x: 0, y: 4)
                    }

                    Menu {
                        Button("단어장 수정") {
                            notebookTitleDraft = notebook?.title ?? ""
                            notebookDescriptionDraft = notebook?.descriptionText ?? ""
                            isNotebookEditorPresented = true
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
        .sheet(isPresented: $isNotebookEditorPresented) {
            NotebookEditorSheet(
                title: $notebookTitleDraft,
                descriptionText: $notebookDescriptionDraft,
                onCancel: {
                    isNotebookEditorPresented = false
                },
                onSave: {
                    store.updateNotebook(
                        notebookId,
                        title: notebookTitleDraft,
                        descriptionText: notebookDescriptionDraft
                    )
                    isNotebookEditorPresented = false
                }
            )
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

private struct NotebookEditorSheet: View {
    private enum Field: Hashable {
        case title
        case description
    }

    @Binding var title: String
    @Binding var descriptionText: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var focusedField: Field?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("단어장 이름과 설명을 함께 수정할 수 있어요.")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("이름")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)

                            TextField("예: N3 문법 표현", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .title)
                                .id(Field.title)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("설명")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.surfaceSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.divider, lineWidth: 1)
                                    )

                                if trimmedDescription.isEmpty {
                                    Text("이 단어장을 어떻게 사용할지 적어보세요")
                                        .font(.body)
                                        .foregroundStyle(Color.textTertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 14)
                                }

                                TextEditor(text: $descriptionText)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(Color.textPrimary)
                                    .focused($focusedField, equals: .description)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .frame(minHeight: 112, maxHeight: 140)
                                    .background(Color.clear)
                            }
                            .frame(minHeight: 112, maxHeight: 140)
                            .id(Field.description)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color.appBackground)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .navigationTitle("단어장 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        focusedField = nil
                        onCancel()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        focusedField = nil
                        onSave()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                    .foregroundStyle(Color.textSecondary)
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
                .foregroundStyle(Color.iconSecondary)

            Text("아직 단어가 없어요")
                .font(.headline)

            Text("첫 단어를 추가해보세요")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 72)
        .appCardStyle(cornerRadius: 16, shadowRadius: 4, shadowY: 1)
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
                .foregroundStyle(Color.textSecondary)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .appCardStyle(cornerRadius: 16, shadowRadius: 4, shadowY: 1)
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
