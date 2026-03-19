import Foundation
import Combine

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notebooks: [WordNotebook] = []

    private let userDefaults: UserDefaults
    private let notebooksKey = "word_notebooks"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func addNotebook(title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return }

        let notebook = WordNotebook(title: trimmedTitle)
        notebooks.insert(notebook, at: 0)
        save()
    }

    func updateNotebookTitle(_ notebookId: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false,
              let index = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        notebooks[index].title = trimmedTitle
        save()
    }

    func deleteNotebook(_ notebookId: UUID) {
        notebooks.removeAll { $0.id == notebookId }
        save()
    }

    func notebook(for notebookId: UUID) -> WordNotebook? {
        notebooks.first { $0.id == notebookId }
    }

    func items(for notebookId: UUID) -> [WordNotebookItem] {
        notebook(for: notebookId)?.items ?? []
    }

    func item(for notebookId: UUID, itemId: UUID) -> WordNotebookItem? {
        items(for: notebookId).first { $0.id == itemId }
    }

    func addItem(to notebookId: UUID, word: String, reading: String, meaning: String, note: String? = nil) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false,
              let index = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        let item = WordNotebookItem(
            word: trimmedWord,
            reading: trimmedReading.isEmpty == false ? trimmedReading : nil,
            meaning: trimmedMeaning,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil
        )
        notebooks[index].items.append(item)
        save()
    }

    func updateItem(
        in notebookId: UUID,
        itemId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String? = nil
    ) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false,
              let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }),
              let itemIndex = notebooks[notebookIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }

        let existing = notebooks[notebookIndex].items[itemIndex]
        notebooks[notebookIndex].items[itemIndex] = WordNotebookItem(
            id: existing.id,
            wordId: existing.wordId,
            word: trimmedWord,
            reading: trimmedReading.isEmpty == false ? trimmedReading : nil,
            meaning: trimmedMeaning,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil,
            addedAt: existing.addedAt
        )
        save()
    }

    func deleteItem(in notebookId: UUID, itemId: UUID) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        notebooks[notebookIndex].items.removeAll { $0.id == itemId }
        save()
    }

    func load() {
        guard let data = userDefaults.data(forKey: notebooksKey) else {
            notebooks = []
            return
        }

        do {
            notebooks = try JSONDecoder().decode([WordNotebook].self, from: data)
        } catch {
            notebooks = []
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(notebooks)
            userDefaults.set(data, forKey: notebooksKey)
        } catch {
            assertionFailure("Failed to save notebooks: \(error)")
        }
    }
}
