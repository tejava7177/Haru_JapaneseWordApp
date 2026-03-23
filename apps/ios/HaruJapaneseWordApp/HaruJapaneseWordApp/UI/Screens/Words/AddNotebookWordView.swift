import SwiftUI
import UIKit

struct AddNotebookWordView: View {
    private enum Field: Hashable {
        case word
        case reading
        case meaning
        case note
    }

    @ObservedObject var store: NotebookStore
    let notebookId: UUID
    let editingItemId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var word: String = ""
    @State private var reading: String = ""
    @State private var meaning: String = ""
    @State private var note: String = ""
    @State private var toastMessage: String?
    @FocusState private var focusedField: Field?

    private var isEditing: Bool {
        editingItemId != nil
    }

    init(store: NotebookStore, notebookId: UUID, editingItem: WordNotebookItem? = nil) {
        self.store = store
        self.notebookId = notebookId
        self.editingItemId = editingItem?.id
        _word = State(initialValue: editingItem?.word ?? "")
        _reading = State(initialValue: editingItem?.reading ?? "")
        _meaning = State(initialValue: editingItem?.meaning ?? "")
        _note = State(initialValue: editingItem?.note ?? "")
    }

    private var canSave: Bool {
        word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("단어", text: $word)
                        .focused($focusedField, equals: .word)
                    TextField("읽기", text: $reading)
                        .focused($focusedField, equals: .reading)
                    TextField("의미", text: $meaning, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .meaning)
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
                            .focused($focusedField, equals: .note)
                    }
                }

                if isEditing == false {
                    Section {
                        HStack(spacing: 12) {
                            Spacer(minLength: 0)

                            Button("저장 후 계속") {
                                saveAndContinue()
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                            .disabled(canSave == false)
                            .opacity(canSave ? 1.0 : 0.4)

                            Button("저장") {
                                saveAndDismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            .disabled(canSave == false)
                            .opacity(canSave ? 1.0 : 0.4)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "단어 수정" : "단어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("저장") {
                            saveAndDismiss()
                        }
                        .disabled(canSave == false)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.82))
                        .clipShape(Capsule())
                        .padding(.bottom, isEditing ? 24 : 84)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toastMessage)
            .onAppear {
                if isEditing == false {
                    focusedField = .word
                }
            }
        }
    }

    private func saveAndDismiss() {
        saveCurrentInput()
        dismiss()
    }

    private func saveAndContinue() {
        saveCurrentInput()
        clearInputs()
        focusedField = .word
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast("저장했어요")
    }

    private func saveCurrentInput() {
        if let editingItemId {
            store.updateItem(
                in: notebookId,
                itemId: editingItemId,
                word: word,
                reading: reading,
                meaning: meaning,
                note: note
            )
        } else {
            store.addItem(to: notebookId, word: word, reading: reading, meaning: meaning, note: note)
        }
    }

    private func clearInputs() {
        word = ""
        reading = ""
        meaning = ""
        note = ""
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                withAnimation {
                    if toastMessage == message {
                        toastMessage = nil
                    }
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
