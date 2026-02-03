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
