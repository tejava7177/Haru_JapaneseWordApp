import SwiftUI
import UIKit

struct AddNotebookWordView: View {
    private enum DuplicateAlertContext: Identifiable {
        case notebook

        var id: String { "notebook" }
    }

    private enum Field: Hashable {
        case word
        case reading
        case meaning
        case note
    }

    @ObservedObject var store: NotebookStore
    private let repository: DictionaryRepository
    let notebookId: UUID
    let editingItemId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var word: String = ""
    @State private var reading: String = ""
    @State private var meaning: String = ""
    @State private var note: String = ""
    @State private var toastMessage: String?
    @State private var duplicateAlertContext: DuplicateAlertContext?
    @State private var isWordListDuplicateConfirmationPresented: Bool = false
    @FocusState private var focusedField: Field?

    private var isEditing: Bool {
        editingItemId != nil
    }

    init(
        store: NotebookStore,
        notebookId: UUID,
        repository: DictionaryRepository = StubDictionaryRepository(),
        editingItem: WordNotebookItem? = nil
    ) {
        self.store = store
        self.notebookId = notebookId
        self.repository = repository
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
                    TextField("예문, 암기 팁, 메모를 자유롭게 적어보세요", text: $note)
                        .focused($focusedField, equals: .note)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
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
                        .foregroundStyle(canSave ? Color.ctaPrimary : Color.textTertiary)
                        .disabled(canSave == false)
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("저장 후 계속") {
                            saveAndContinue()
                        }
                        .foregroundStyle(canSave ? Color.chipActive : Color.textTertiary)
                        .disabled(canSave == false)

                        Button("저장") {
                            saveAndDismiss()
                        }
                        .foregroundStyle(canSave ? Color.ctaPrimary : Color.textTertiary)
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
            .alert(item: $duplicateAlertContext) { context in
                switch context {
                case .notebook:
                    return Alert(
                        title: Text("이미 이 단어장에 있는 단어예요"),
                        message: Text("새로 추가하는 대신 수정해서 사용해보세요."),
                        primaryButton: .default(Text("단어장 보기")) {
                            dismiss()
                        },
                        secondaryButton: .cancel(Text("확인"))
                    )
                }
            }
            .alert("이미 Word 목록에 있는 단어예요", isPresented: $isWordListDuplicateConfirmationPresented) {
                Button("취소", role: .cancel) {}
                Button("추가하기") {
                    persistCurrentInput(shouldDismissOnSuccess: false)
                }
            } message: {
                Text("다른 의미나 메모와 함께 내 단어장에 추가할까요?")
            }
        }
    }

    private func saveAndDismiss() {
        attemptSave(shouldDismissOnSuccess: true)
    }

    private func saveAndContinue() {
        attemptSave(shouldDismissOnSuccess: false)
    }

    private func attemptSave(shouldDismissOnSuccess: Bool) {
        let expression = normalizedExpression

        if store.findItemWithSameExpression(in: notebookId, expression: expression, excluding: editingItemId) != nil {
            duplicateAlertContext = .notebook
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        if isEditing == false, hasMatchingDictionaryWord(expression: expression) {
            isWordListDuplicateConfirmationPresented = true
            return
        }

        persistCurrentInput(shouldDismissOnSuccess: shouldDismissOnSuccess)
    }

    private func persistCurrentInput(shouldDismissOnSuccess: Bool) {
        let result: NotebookStore.ManualWordSaveResult

        if let editingItemId {
            result = store.updateItem(
                in: notebookId,
                itemId: editingItemId,
                word: word,
                reading: reading,
                meaning: meaning,
                note: note
            )
        } else {
            result = store.addItem(to: notebookId, word: word, reading: reading, meaning: meaning, note: note)
        }

        switch result {
        case .success:
            if shouldDismissOnSuccess {
                dismiss()
            } else {
                clearInputs()
                focusedField = .word
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast("저장했어요")
            }
        case .duplicateExpression:
            duplicateAlertContext = .notebook
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .notebookNotFound, .itemNotFound:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast("저장하지 못했어요")
        }
    }

    private var normalizedExpression: String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    private func hasMatchingDictionaryWord(expression: String) -> Bool {
        guard expression.isEmpty == false else { return false }

        do {
            return try repository.findByExpression(expression) != nil
        } catch {
            return false
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
