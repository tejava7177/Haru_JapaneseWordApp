import Foundation

struct WordNotebook: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var descriptionText: String?
    var items: [WordNotebookItem]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        descriptionText: String? = nil,
        items: [WordNotebookItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.items = items
        self.createdAt = createdAt
    }
}

struct WordNotebookItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let wordId: Int?
    let word: String
    let reading: String?
    let meaning: String
    let note: String?
    let addedAt: Date

    init(
        id: UUID = UUID(),
        wordId: Int? = nil,
        word: String,
        reading: String? = nil,
        meaning: String,
        note: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.wordId = wordId
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.note = note
        self.addedAt = addedAt
    }
}
