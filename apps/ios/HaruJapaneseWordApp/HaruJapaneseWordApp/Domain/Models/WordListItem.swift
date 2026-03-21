import Foundation

struct WordListItem: Identifiable, Hashable {
    enum Source: Hashable {
        case jlpt(level: JLPTLevel, wordId: Int)
        case notebook(notebookId: UUID, itemId: UUID)
    }

    let id: String
    let word: String
    let reading: String?
    let meaning: String
    let source: Source

    init(id: String, word: String, reading: String?, meaning: String, source: Source) {
        self.id = id
        self.word = word
        self.reading = reading
        self.meaning = meaning
        self.source = source
    }

    init(wordSummary: WordSummary) {
        self.init(
            id: "jlpt-\(wordSummary.id)",
            word: wordSummary.expression,
            reading: wordSummary.reading,
            meaning: wordSummary.meanings,
            source: .jlpt(level: wordSummary.level, wordId: wordSummary.id)
        )
    }

    init(notebookId: UUID, item: WordNotebookItem) {
        self.init(
            id: "notebook-\(notebookId.uuidString)-\(item.id.uuidString)",
            word: item.word,
            reading: item.reading,
            meaning: item.meaning,
            source: .notebook(notebookId: notebookId, itemId: item.id)
        )
    }

    var jlptLevel: JLPTLevel? {
        guard case let .jlpt(level, _) = source else { return nil }
        return level
    }

    var jlptWordId: Int? {
        guard case let .jlpt(_, wordId) = source else { return nil }
        return wordId
    }

    var notebookReference: (notebookId: UUID, itemId: UUID)? {
        guard case let .notebook(notebookId, itemId) = source else { return nil }
        return (notebookId, itemId)
    }

    var isNotebookWord: Bool {
        if case .notebook = source {
            return true
        }
        return false
    }
}
