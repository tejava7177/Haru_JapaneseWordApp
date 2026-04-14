import Combine
import CryptoKit
import Foundation

@MainActor
final class NotebookStore: ObservableObject {
    static let shared = NotebookStore()

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
    private let apiService: NotebookAPIServiceProtocol
    private let notebooksKey = "word_notebooks"
    private let cachedNotebooksKeyPrefix = "word_notebooks_cached_user_"
    private let migrationKeyPrefix = "notebooks_migrated_user_"
    private weak var settingsStore: AppSettingsStore?
    private var cancellables: Set<AnyCancellable> = []
    private var currentServerUserId: String?
    private var currentSyncTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = .standard,
        apiService: NotebookAPIServiceProtocol = NotebookAPIService()
    ) {
        self.userDefaults = userDefaults
        self.apiService = apiService
        self.notebooks = sanitizeNotebooks(loadLegacyLocalNotebooks())
    }

    func configure(settingsStore: AppSettingsStore) {
        guard self.settingsStore !== settingsStore else { return }

        self.settingsStore = settingsStore
        cancellables.removeAll()

        settingsStore.$serverUserId
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                self?.scheduleSessionSync(for: userId, triggerSource: "serverUserIdChanged")
            }
            .store(in: &cancellables)

        scheduleSessionSync(for: settingsStore.currentBackendUserId, triggerSource: "configure")
    }

    func reload(triggerSource: String = "manual") async {
        await syncForCurrentSession(userId: currentServerUserId, triggerSource: triggerSource)
    }

    func addNotebook(title: String, descriptionText: String? = nil) {
        addNotebookLocally(title: title, descriptionText: descriptionText)
    }

    @discardableResult
    func addNotebook(title: String, descriptionText: String? = nil) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = normalizedOptionalText(descriptionText)
        guard trimmedTitle.isEmpty == false else { return false }

        if let userId = currentServerUserId {
            print("[NotebookStore] notebook create start userId=\(userId) title=\(trimmedTitle)")
            do {
                let response = try await apiService.createNotebook(
                    userId: userId,
                    title: trimmedTitle,
                    description: normalizedDescription
                )
                upsertNotebook(mapNotebook(response, existingNotebook: notebooks.first(where: { $0.serverId == response.id })))
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook create success userId=\(userId) notebookId=\(response.id)")
                logCurrentNotebookCount()
                return true
            } catch {
                print("[NotebookStore] notebook create failure userId=\(userId) error=\(error.localizedDescription)")
                return false
            }
        }

        addNotebookLocally(title: trimmedTitle, descriptionText: normalizedDescription)
        print("[NotebookStore] notebook create success userId=local")
        return true
    }

    func updateNotebookTitle(_ notebookId: UUID, title: String) {
        updateNotebookLocally(notebookId, title: title, descriptionText: notebook(for: notebookId)?.descriptionText)
    }

    func updateNotebook(_ notebookId: UUID, title: String, descriptionText: String?) {
        updateNotebookLocally(notebookId, title: title, descriptionText: descriptionText)
    }

    @discardableResult
    func updateNotebook(_ notebookId: UUID, title: String, descriptionText: String?) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = normalizedOptionalText(descriptionText)
        guard trimmedTitle.isEmpty == false else { return false }

        guard let notebook = notebook(for: notebookId) else {
            return false
        }

        if let userId = currentServerUserId, let serverNotebookId = notebook.serverId {
            print("[NotebookStore] notebook update start userId=\(userId) notebookId=\(serverNotebookId)")
            do {
                let response = try await apiService.updateNotebook(
                    userId: userId,
                    notebookId: serverNotebookId,
                    title: trimmedTitle,
                    description: normalizedDescription
                )
                upsertNotebook(mapNotebook(response, existingNotebook: notebook))
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook update success userId=\(userId) notebookId=\(serverNotebookId)")
                logCurrentNotebookCount()
                return true
            } catch {
                print("[NotebookStore] notebook update failure userId=\(userId) notebookId=\(serverNotebookId) error=\(error.localizedDescription)")
                return false
            }
        }

        updateNotebookLocally(notebookId, title: trimmedTitle, descriptionText: normalizedDescription)
        print("[NotebookStore] notebook update success userId=local notebookId=\(notebookId.uuidString)")
        return true
    }

    func deleteNotebook(_ notebookId: UUID) {
        deleteNotebookLocally(notebookId)
    }

    @discardableResult
    func deleteNotebook(_ notebookId: UUID) async -> Bool {
        guard let notebook = notebook(for: notebookId) else {
            return false
        }

        if let userId = currentServerUserId, let serverNotebookId = notebook.serverId {
            print("[NotebookStore] notebook delete start userId=\(userId) notebookId=\(serverNotebookId)")
            do {
                try await apiService.deleteNotebook(userId: userId, notebookId: serverNotebookId)
                notebooks.removeAll { $0.id == notebookId }
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook delete success userId=\(userId) notebookId=\(serverNotebookId)")
                logCurrentNotebookCount()
                return true
            } catch {
                print("[NotebookStore] notebook delete failure userId=\(userId) notebookId=\(serverNotebookId) error=\(error.localizedDescription)")
                return false
            }
        }

        deleteNotebookLocally(notebookId)
        print("[NotebookStore] notebook delete success userId=local notebookId=\(notebookId.uuidString)")
        return true
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
        addItemLocally(to: notebookId, word: word, reading: reading, meaning: meaning, note: note)
    }

    @discardableResult
    func addItem(
        to notebookId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String? = nil
    ) async -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = normalizedOptionalText(note)

        guard trimmedWord.isEmpty == false, trimmedMeaning.isEmpty == false else {
            return .itemNotFound
        }

        guard let notebook = notebook(for: notebookId) else {
            return .notebookNotFound
        }

        if let duplicateItem = findItemWithSameExpression(in: notebookId, expression: trimmedWord) {
            return .duplicateExpression(existingItem: duplicateItem)
        }

        if let userId = currentServerUserId, let serverNotebookId = notebook.serverId {
            let payload = NotebookItemMutationPayload(
                itemType: .custom,
                wordId: nil,
                expression: trimmedWord,
                reading: normalizedReading,
                meaning: trimmedMeaning,
                memo: normalizedNote,
                sortOrder: notebook.items.count
            )

            print("[NotebookStore] notebook item create start userId=\(userId) notebookId=\(serverNotebookId) type=CUSTOM")
            do {
                let response = try await apiService.createNotebookItem(
                    userId: userId,
                    notebookId: serverNotebookId,
                    item: payload
                )
                replaceItems(in: notebookId) { items in
                    let mappedItem = self.mapItem(response, existingItem: items.first(where: { $0.serverId == response.id }))
                    return self.upsertItem(mappedItem, into: items)
                }
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook item create success userId=\(userId) notebookId=\(serverNotebookId) itemId=\(response.id)")
                logCurrentNotebookCount()
                return .success
            } catch {
                print("[NotebookStore] notebook item create failure userId=\(userId) notebookId=\(serverNotebookId) error=\(error.localizedDescription)")
                return .itemNotFound
            }
        }

        let result = addItemLocally(
            to: notebookId,
            word: trimmedWord,
            reading: normalizedReading ?? "",
            meaning: trimmedMeaning,
            note: normalizedNote
        )
        if case .success = result {
            print("[NotebookStore] notebook item create success userId=local notebookId=\(notebookId.uuidString)")
        }
        return result
    }

    func addJLPTWord(
        to notebookId: UUID,
        wordId: Int? = nil,
        word: String,
        reading: String?,
        meaning: String
    ) -> AddJLPTWordResult {
        addJLPTWordLocally(to: notebookId, wordId: wordId, word: word, reading: reading, meaning: meaning)
    }

    func addJLPTWord(
        to notebookId: UUID,
        wordId: Int? = nil,
        word: String,
        reading: String?,
        meaning: String
    ) async -> AddJLPTWordResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false,
              let notebook = notebook(for: notebookId) else {
            return .notebookNotFound
        }

        let hasDuplicate = notebook.items.contains {
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

        if let userId = currentServerUserId, let serverNotebookId = notebook.serverId {
            let payload = NotebookItemMutationPayload(
                itemType: wordId == nil ? .custom : .wordRef,
                wordId: wordId,
                expression: trimmedWord,
                reading: normalizedReading,
                meaning: trimmedMeaning,
                memo: nil,
                sortOrder: notebook.items.count
            )

            print("[NotebookStore] notebook item create start userId=\(userId) notebookId=\(serverNotebookId) type=\(payload.itemType.rawValue)")
            do {
                let response = try await apiService.createNotebookItem(
                    userId: userId,
                    notebookId: serverNotebookId,
                    item: payload
                )
                replaceItems(in: notebookId) { items in
                    let mappedItem = self.mapItem(response, existingItem: items.first(where: { $0.serverId == response.id }))
                    return self.upsertItem(mappedItem, into: items)
                }
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook item create success userId=\(userId) notebookId=\(serverNotebookId) itemId=\(response.id)")
                logCurrentNotebookCount()
                return .success
            } catch {
                print("[NotebookStore] notebook item create failure userId=\(userId) notebookId=\(serverNotebookId) error=\(error.localizedDescription)")
                return .notebookNotFound
            }
        }

        let result = addJLPTWordLocally(
            to: notebookId,
            wordId: wordId,
            word: trimmedWord,
            reading: normalizedReading,
            meaning: trimmedMeaning
        )
        if case .success = result {
            print("[NotebookStore] notebook item create success userId=local notebookId=\(notebookId.uuidString)")
        }
        return result
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
        updateItemLocally(in: notebookId, itemId: itemId, word: word, reading: reading, meaning: meaning, note: note)
    }

    @discardableResult
    func updateItem(
        in notebookId: UUID,
        itemId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String? = nil
    ) async -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = normalizedOptionalText(note)

        guard trimmedWord.isEmpty == false,
              trimmedMeaning.isEmpty == false else {
            return .itemNotFound
        }

        guard let notebook = notebook(for: notebookId) else {
            return .notebookNotFound
        }

        guard let existingItem = item(for: notebookId, itemId: itemId) else {
            return .itemNotFound
        }

        if let duplicateItem = findItemWithSameExpression(in: notebookId, expression: trimmedWord, excluding: itemId) {
            return .duplicateExpression(existingItem: duplicateItem)
        }

        if let userId = currentServerUserId,
           let serverNotebookId = notebook.serverId,
           let serverItemId = existingItem.serverId {
            let payload = NotebookItemMutationPayload(
                itemType: existingItem.wordId == nil ? .custom : .wordRef,
                wordId: existingItem.wordId,
                expression: trimmedWord,
                reading: normalizedReading,
                meaning: trimmedMeaning,
                memo: normalizedNote,
                sortOrder: notebook.items.firstIndex(where: { $0.id == itemId })
            )

            print("[NotebookStore] notebook item update start userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId)")
            do {
                let response = try await apiService.updateNotebookItem(
                    userId: userId,
                    notebookId: serverNotebookId,
                    itemId: serverItemId,
                    item: payload
                )
                replaceItems(in: notebookId) { items in
                    let mappedItem = self.mapItem(response, existingItem: existingItem)
                    return self.upsertItem(mappedItem, into: items)
                }
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook item update success userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId)")
                logCurrentNotebookCount()
                return .success
            } catch {
                print("[NotebookStore] notebook item update failure userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId) error=\(error.localizedDescription)")
                return .itemNotFound
            }
        }

        let result = updateItemLocally(
            in: notebookId,
            itemId: itemId,
            word: trimmedWord,
            reading: normalizedReading ?? "",
            meaning: trimmedMeaning,
            note: normalizedNote
        )
        if case .success = result {
            print("[NotebookStore] notebook item update success userId=local notebookId=\(notebookId.uuidString) itemId=\(itemId.uuidString)")
        }
        return result
    }

    func deleteItem(in notebookId: UUID, itemId: UUID) {
        deleteItemLocally(in: notebookId, itemId: itemId)
    }

    @discardableResult
    func deleteItem(in notebookId: UUID, itemId: UUID) async -> Bool {
        guard let notebook = notebook(for: notebookId),
              let existingItem = item(for: notebookId, itemId: itemId) else {
            return false
        }

        if let userId = currentServerUserId,
           let serverNotebookId = notebook.serverId,
           let serverItemId = existingItem.serverId {
            print("[NotebookStore] notebook item delete start userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId)")
            do {
                try await apiService.deleteNotebookItem(
                    userId: userId,
                    notebookId: serverNotebookId,
                    itemId: serverItemId
                )
                replaceItems(in: notebookId) { items in
                    items.filter { $0.id != itemId }
                }
                persistNotebooks(notebooks, cachedUserId: userId)
                print("[NotebookStore] notebook item delete success userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId)")
                logCurrentNotebookCount()
                return true
            } catch {
                print("[NotebookStore] notebook item delete failure userId=\(userId) notebookId=\(serverNotebookId) itemId=\(serverItemId) error=\(error.localizedDescription)")
                return false
            }
        }

        deleteItemLocally(in: notebookId, itemId: itemId)
        print("[NotebookStore] notebook item delete success userId=local notebookId=\(notebookId.uuidString) itemId=\(itemId.uuidString)")
        return true
    }

    private func scheduleSessionSync(for userId: String?, triggerSource: String) {
        currentSyncTask?.cancel()
        currentSyncTask = Task { [weak self] in
            await self?.syncForCurrentSession(userId: userId, triggerSource: triggerSource)
        }
    }

    private func syncForCurrentSession(userId: String?, triggerSource: String) async {
        let normalizedUserId = normalizedUserId(userId)
        currentServerUserId = normalizedUserId

        if let normalizedUserId {
            await syncFromServer(userId: normalizedUserId, triggerSource: triggerSource)
        } else {
            let localNotebooks = loadLegacyLocalNotebooks()
            print("[NotebookStore] notebook fetch skipped reason=noLoggedInUser trigger=\(triggerSource)")
            applyNotebooks(localNotebooks, cachedUserId: nil)
        }
    }

    private func syncFromServer(userId: String, triggerSource: String) async {
        print("[NotebookStore] notebook fetch start userId=\(userId) trigger=\(triggerSource)")

        do {
            var fetchedNotebooks = try await apiService.fetchNotebooks(userId: userId)
            print("[NotebookStore] notebook fetch success userId=\(userId) count=\(fetchedNotebooks.count)")

            let localNotebooks = loadLegacyLocalNotebooks()
            let hasMigrated = hasCompletedMigration(for: userId)

            if fetchedNotebooks.isEmpty == false {
                if hasMigrated == false {
                    markMigrationCompleted(for: userId)
                }
                print("[NotebookStore] notebook migration skipped userId=\(userId) reason=serverNotEmpty")
            } else if localNotebooks.isEmpty {
                print("[NotebookStore] notebook migration skipped userId=\(userId) reason=localEmpty")
            } else if hasMigrated {
                print("[NotebookStore] notebook migration skipped userId=\(userId) reason=alreadyMigrated")
            } else {
                print("[NotebookStore] notebook migration start userId=\(userId) notebookCount=\(localNotebooks.count)")
                try await apiService.migrateNotebooks(
                    userId: userId,
                    payload: makeMigrationPayload(from: localNotebooks)
                )
                markMigrationCompleted(for: userId)
                print("[NotebookStore] notebook migration success userId=\(userId) notebookCount=\(localNotebooks.count)")

                print("[NotebookStore] notebook fetch start userId=\(userId) trigger=postMigration")
                fetchedNotebooks = try await apiService.fetchNotebooks(userId: userId)
                print("[NotebookStore] notebook fetch success userId=\(userId) count=\(fetchedNotebooks.count)")
            }

            guard Task.isCancelled == false else { return }
            let mapped = mapNotebooks(fetchedNotebooks)
            applyNotebooks(mapped, cachedUserId: userId)
        } catch {
            print("[NotebookStore] notebook fetch failure userId=\(userId) error=\(error.localizedDescription)")
            let fallback = loadCachedNotebooks(for: userId) ?? loadLegacyLocalNotebooks()
            applyNotebooks(fallback, cachedUserId: userId)
        }
    }

    private func applyNotebooks(_ nextNotebooks: [WordNotebook], cachedUserId: String?) {
        notebooks = sanitizeNotebooks(nextNotebooks)
        persistNotebooks(notebooks, cachedUserId: cachedUserId)
        logCurrentNotebookCount()
    }

    private func persistNotebooks(_ notebooks: [WordNotebook], cachedUserId: String?) {
        do {
            let sanitized = sanitizeNotebooks(notebooks)
            let data = try JSONEncoder().encode(sanitized)
            userDefaults.set(data, forKey: notebooksKey)

            if let cachedUserId {
                userDefaults.set(data, forKey: cachedNotebooksKey(for: cachedUserId))
            }
        } catch {
            assertionFailure("Failed to save notebooks: \(error)")
        }
    }

    private func loadLegacyLocalNotebooks() -> [WordNotebook] {
        loadNotebooks(forKey: notebooksKey)
    }

    private func loadCachedNotebooks(for userId: String) -> [WordNotebook]? {
        let key = cachedNotebooksKey(for: userId)
        guard userDefaults.data(forKey: key) != nil else { return nil }
        return loadNotebooks(forKey: key)
    }

    private func loadNotebooks(forKey key: String) -> [WordNotebook] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        do {
            return sanitizeNotebooks(try JSONDecoder().decode([WordNotebook].self, from: data))
        } catch {
            return []
        }
    }

    private func hasCompletedMigration(for userId: String) -> Bool {
        userDefaults.bool(forKey: migrationKey(for: userId))
    }

    private func markMigrationCompleted(for userId: String) {
        userDefaults.set(true, forKey: migrationKey(for: userId))
    }

    private func cachedNotebooksKey(for userId: String) -> String {
        "\(cachedNotebooksKeyPrefix)\(userId)"
    }

    private func migrationKey(for userId: String) -> String {
        "\(migrationKeyPrefix)\(userId)"
    }

    private func addNotebookLocally(title: String, descriptionText: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = normalizedOptionalText(descriptionText)
        guard trimmedTitle.isEmpty == false else { return }

        let notebook = WordNotebook(
            title: trimmedTitle,
            descriptionText: trimmedDescription
        )
        notebooks.insert(notebook, at: 0)
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
    }

    private func updateNotebookLocally(_ notebookId: UUID, title: String, descriptionText: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = normalizedOptionalText(descriptionText)

        guard trimmedTitle.isEmpty == false,
              let index = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        notebooks[index].title = trimmedTitle
        notebooks[index].descriptionText = trimmedDescription
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
    }

    private func deleteNotebookLocally(_ notebookId: UUID) {
        notebooks.removeAll { $0.id == notebookId }
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
    }

    private func addItemLocally(
        to notebookId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String?
    ) -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = normalizedOptionalText(note)

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
            reading: normalizedReading,
            meaning: trimmedMeaning,
            note: normalizedNote
        )
        notebooks[index].items.append(item)
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
        return .success
    }

    private func addJLPTWordLocally(
        to notebookId: UUID,
        wordId: Int?,
        word: String,
        reading: String?,
        meaning: String
    ) -> AddJLPTWordResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
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
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
        return .success
    }

    private func updateItemLocally(
        in notebookId: UUID,
        itemId: UUID,
        word: String,
        reading: String,
        meaning: String,
        note: String?
    ) -> ManualWordSaveResult {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReading = normalizedOptionalText(reading)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = normalizedOptionalText(note)

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
            serverId: existing.serverId,
            wordId: existing.wordId,
            word: trimmedWord,
            reading: normalizedReading,
            meaning: trimmedMeaning,
            note: normalizedNote,
            addedAt: existing.addedAt
        )
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
        return .success
    }

    private func deleteItemLocally(in notebookId: UUID, itemId: UUID) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }) else {
            return
        }

        notebooks[notebookIndex].items.removeAll { $0.id == itemId }
        persistNotebooks(notebooks, cachedUserId: currentServerUserId)
        logCurrentNotebookCount()
    }

    private func replaceItems(in notebookId: UUID, transform: ([WordNotebookItem]) -> [WordNotebookItem]) {
        guard let notebookIndex = notebooks.firstIndex(where: { $0.id == notebookId }) else { return }
        notebooks[notebookIndex].items = sanitizeItems(
            transform(notebooks[notebookIndex].items)
        )
    }

    private func upsertNotebook(_ notebook: WordNotebook) {
        if let index = notebooks.firstIndex(where: { $0.id == notebook.id || ($0.serverId != nil && $0.serverId == notebook.serverId) }) {
            notebooks[index] = notebook
        } else {
            notebooks.insert(notebook, at: 0)
        }
        notebooks = sortNotebooks(notebooks)
    }

    private func upsertItem(_ item: WordNotebookItem, into items: [WordNotebookItem]) -> [WordNotebookItem] {
        var nextItems = items
        if let index = nextItems.firstIndex(where: { $0.id == item.id || ($0.serverId != nil && $0.serverId == item.serverId) }) {
            nextItems[index] = item
        } else {
            nextItems.append(item)
        }
        return sanitizeItems(nextItems)
    }

    private func mapNotebooks(_ serverNotebooks: [ServerNotebook]) -> [WordNotebook] {
        sortNotebooks(serverNotebooks.map { serverNotebook in
            mapNotebook(
                serverNotebook,
                existingNotebook: notebooks.first(where: { $0.serverId == serverNotebook.id })
            )
        })
    }

    private func mapNotebook(_ serverNotebook: ServerNotebook, existingNotebook: WordNotebook?) -> WordNotebook {
        let notebookId = existingNotebook?.id ?? stableUUID(namespace: "notebook", value: serverNotebook.id)
        let mappedItems = sanitizeItems(
            serverNotebook.items
                .sorted { lhs, rhs in
                    switch (lhs.sortOrder, rhs.sortOrder) {
                    case let (left?, right?):
                        if left == right {
                            return lhs.id < rhs.id
                        }
                        return left < right
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        return lhs.id < rhs.id
                    }
                }
                .map { serverItem in
                    mapItem(
                        serverItem,
                        existingItem: existingNotebook?.items.first(where: { $0.serverId == serverItem.id })
                    )
                }
        )

        return WordNotebook(
            id: notebookId,
            serverId: serverNotebook.id,
            title: serverNotebook.title,
            descriptionText: normalizedOptionalText(serverNotebook.description),
            items: mappedItems,
            createdAt: parseServerDate(serverNotebook.createdAt) ?? existingNotebook?.createdAt ?? Date()
        )
    }

    private func mapItem(_ serverItem: ServerNotebookItem, existingItem: WordNotebookItem?) -> WordNotebookItem {
        let itemId = existingItem?.id ?? stableUUID(namespace: "notebook-item", value: serverItem.id)
        return WordNotebookItem(
            id: itemId,
            serverId: serverItem.id,
            wordId: serverItem.itemType == .wordRef ? serverItem.wordId : nil,
            word: serverItem.expression,
            reading: normalizedOptionalText(serverItem.reading),
            meaning: serverItem.meaning,
            note: normalizedOptionalText(serverItem.memo),
            addedAt: parseServerDate(serverItem.createdAt) ?? existingItem?.addedAt ?? Date()
        )
    }

    private func makeMigrationPayload(from localNotebooks: [WordNotebook]) -> NotebookMigrationPayload {
        NotebookMigrationPayload(
            notebooks: localNotebooks.map { notebook in
                NotebookMigrationNotebookRequest(
                    title: notebook.title,
                    description: notebook.descriptionText,
                    items: sanitizeItems(notebook.items).map { item in
                        NotebookMigrationItemRequest(
                            wordId: item.wordId,
                            expression: item.word,
                            reading: item.reading,
                            meaning: item.meaning,
                            memo: item.note
                        )
                    }
                )
            }
        )
    }

    private func sanitizeNotebooks(_ notebooks: [WordNotebook]) -> [WordNotebook] {
        sortNotebooks(notebooks.map { notebook in
            WordNotebook(
                id: notebook.id,
                serverId: notebook.serverId,
                title: notebook.title,
                descriptionText: normalizedOptionalText(notebook.descriptionText),
                items: sanitizeItems(notebook.items),
                createdAt: notebook.createdAt
            )
        })
    }

    private func sanitizeItems(_ items: [WordNotebookItem]) -> [WordNotebookItem] {
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

    private func sortNotebooks(_ notebooks: [WordNotebook]) -> [WordNotebook] {
        notebooks.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.title < $1.title
            }
            return $0.createdAt > $1.createdAt
        }
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
        normalizedOptionalText(reading)
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText?.isEmpty == false ? trimmedText : nil
    }

    private func normalizedWordValue(_ word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    private func normalizedUserId(_ userId: String?) -> String? {
        let trimmedUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUserId?.isEmpty == false ? trimmedUserId : nil
    }

    private func parseServerDate(_ value: String?) -> Date? {
        guard let value, value.isEmpty == false else { return nil }
        return Self.iso8601Formatter.date(from: value) ?? Self.iso8601FallbackFormatter.date(from: value)
    }

    private func stableUUID(namespace: String, value: Int) -> UUID {
        let digest = Insecure.MD5.hash(data: Data("\(namespace)-\(value)".utf8))
        let bytes = Array(digest)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            (bytes[6] & 0x0F) | 0x30,
            (bytes[7] & 0x3F) | 0x80,
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func logCurrentNotebookCount() {
        print("[NotebookStore] current notebook count count=\(notebooks.count)")
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
