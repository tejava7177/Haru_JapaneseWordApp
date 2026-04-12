import Foundation
import Combine

@MainActor
final class NotebookStore: ObservableObject {
    enum ManualWordSaveResult {
        case success
        case duplicateExpression(existingItem: WordNotebookItem)
        case notebookNotFound
        case itemNotFound
    }

    enum AddJLPTWordResult {
        case success
        case duplicate
        case notebookNotFound
    }

    @Published private(set) var notebooks: [WordNotebook] = []

    private let userDefaults: UserDefaults
    private let notebooksKey = "word_notebooks"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func addNotebook(title: String, descriptionText: String? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return }

        let notebook = WordNotebook(
            title: trimmedTitle,
            descriptionText: trimmedDescription?.isEmpty == false ? trimmedDescription : nil
        )
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

    func updateNotebook(_ notebookId: UUID, title: String, descriptionText: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.isEmpty == false,
              let index = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        notebooks[index].title = trimmedTitle
        notebooks[index].descriptionText = trimmedDescription?.isEmpty == false ? trimmedDescription : nil
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

    func containsJLPTWord(
        wordId: Int?,
        word: String,
        reading: String?,
        in notebookId: UUID
    ) -> Bool {
        guard let notebook = notebook(for: notebookId) else { return false }

        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)

        return notebook.items.contains {
            isDuplicate(
                existingItem: $0,
                newWordId: wordId,
                newWord: trimmedWord,
                newReading: reading
            )
        }
    }

    func findItemWithSameExpression(
        in notebookId: UUID,
        expression: String,
        excluding itemId: UUID? = nil
    ) -> WordNotebookItem? {
        guard let notebook = notebook(for: notebookId) else { return nil }
        let normalizedExpression = normalizedWordValue(expression)
        guard normalizedExpression.isEmpty == false else { return nil }

        return notebook.items.first { item in
            item.id != itemId && normalizedWordValue(item.word) == normalizedExpression
        }
    }

    func wordListItems(in notebookIds: Set<UUID>) -> [WordListItem] {
        notebooks
            .filter { notebookIds.contains($0.id) }
            .flatMap { notebook in
                notebook.items.map { WordListItem(notebookId: notebook.id, item: $0) }
            }
    }

    @discardableResult
    func addItem(
        to notebookId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String? = nil
    ) -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false,
              let index = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return .notebookNotFound
        }

        if let duplicateItem = findItemWithSameExpression(in: notebookId, expression: trimmedWord) {
            return .duplicateExpression(existingItem: duplicateItem)
        }

        let item = WordNotebookItem(
            word: trimmedWord,
            reading: trimmedReading.isEmpty == false ? trimmedReading : nil,
            meaning: trimmedMeaning,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil
        )
        notebooks[index].items.append(item)
        save()
        return .success
    }

    func addJLPTWord(
        to notebookId: UUID,
        wordId: Int? = nil,
        word: String,
        reading: String?,
        meaning: String
    ) -> AddJLPTWordResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = trimmedReading?.isEmpty == false ? trimmedReading : nil
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false,
              let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return .notebookNotFound
        }

        let hasDuplicate = notebooks[notebookIndex].items.contains {
            isDuplicate(
                existingItem: $0,
                newWordId: wordId,
                newWord: trimmedWord,
                newReading: normalizedReading
            )
        }
        guard hasDuplicate == false else {
            return .duplicate
        }

        notebooks[notebookIndex].items.append(
            WordNotebookItem(
                wordId: wordId,
                word: trimmedWord,
                reading: normalizedReading,
                meaning: trimmedMeaning,
                note: nil
            )
        )
        save()
        return .success
    }

    @discardableResult
    func updateItem(
        in notebookId: UUID,
        itemId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String? = nil
    ) -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false else {
            return .itemNotFound
        }

        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return .notebookNotFound
        }

        guard let itemIndex = notebooks[notebookIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return .itemNotFound
        }

        if let duplicateItem = findItemWithSameExpression(in: notebookId, expression: trimmedWord, excluding: itemId) {
            return .duplicateExpression(existingItem: duplicateItem)
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
        return .success
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
            let decoded = try JSONDecoder().decode([WordNotebook].self, from: data)
            let deduplicated = sanitizeNotebooks(decoded)
            notebooks = deduplicated

            if deduplicated != decoded {
                save()
            }
        } catch {
            notebooks = []
        }
    }

    func save() {
        do {
            notebooks = sanitizeNotebooks(notebooks)
            let data = try JSONEncoder().encode(notebooks)
            userDefaults.set(data, forKey: notebooksKey)
        } catch {
            assertionFailure("Failed to save notebooks: \(error)")
        }
    }

    private func sanitizeNotebooks(_ notebooks: [WordNotebook]) -> [WordNotebook] {
        notebooks.map { notebook in
            WordNotebook(
                id: notebook.id,
                title: notebook.title,
                descriptionText: notebook.descriptionText,
                items: deduplicatedItems(notebook.items),
                createdAt: notebook.createdAt
            )
        }
    }

    private func deduplicatedItems(_ items: [WordNotebookItem]) -> [WordNotebookItem] {
        var seenWords = Set<String>()
        var deduplicated: [WordNotebookItem] = []
        deduplicated.reserveCapacity(items.count)

        for item in items {
            let normalizedWord = normalizedWordValue(item.word)
            if seenWords.contains(normalizedWord) {
                continue
            }

            seenWords.insert(normalizedWord)
            deduplicated.append(item)
        }

        return deduplicated
    }

    private func isDuplicate(
        existingItem: WordNotebookItem,
        newWordId: Int?,
        newWord: String,
        newReading: String?
    ) -> Bool {
        let hasSameWordId: Bool
        if let newWordId, let existingWordId = existingItem.wordId {
            hasSameWordId = existingWordId == newWordId
        } else {
            hasSameWordId = false
        }

        let hasSameExpression = normalizedWordValue(existingItem.word) == normalizedWordValue(newWord)
        let hasSameFallback = normalizedWordValue(existingItem.word) == normalizedWordValue(newWord) &&
            normalizedReadingValue(existingItem.reading) == normalizedReadingValue(newReading)

        return hasSameWordId || hasSameExpression || hasSameFallback
    }

    private func normalizedReadingValue(_ reading: String?) -> String? {
        let trimmedReading = reading?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedReading?.isEmpty == false ? trimmedReading : nil
    }

    private func normalizedWordValue(_ word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }
}
