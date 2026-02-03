import Foundation

protocol DictionaryRepository {
    func fetchWords(level: JLPTLevel, limit: Int?, offset: Int?) throws -> [WordSummary]
    func searchWords(level: JLPTLevel, query: String, limit: Int?, offset: Int?) throws -> [WordSummary]
    func fetchWordDetail(wordId: Int) throws -> WordDetail?
}

struct StubDictionaryRepository: DictionaryRepository {
    func fetchWords(level: JLPTLevel, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func searchWords(level: JLPTLevel, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        nil
    }
}

struct ErrorDictionaryRepository: DictionaryRepository {
    let error: Error

    func fetchWords(level: JLPTLevel, limit: Int?, offset: Int?) throws -> [WordSummary] {
        throw error
    }

    func searchWords(level: JLPTLevel, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        throw error
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        throw error
    }
}
