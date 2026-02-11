import Foundation

protocol DictionaryRepository {
    func fetchWords(level: JLPTLevel?, limit: Int?, offset: Int?) throws -> [WordSummary]
    func searchWords(level: JLPTLevel?, query: String, limit: Int?, offset: Int?) throws -> [WordSummary]
    func fetchWordDetail(wordId: Int) throws -> WordDetail?
    func fetchWordSummary(wordId: Int) throws -> WordSummary?
    func randomWord(level: JLPTLevel) throws -> WordSummary?
    func randomWordIds(level: JLPTLevel, count: Int, excluding ids: Set<Int>) throws -> [Int]
    func findByExpression(_ expression: String) throws -> WordSummary?
    func getRandomWords(limit: Int, excludingExpression: String?) throws -> [WordSummary]
}

struct StubDictionaryRepository: DictionaryRepository {
    func fetchWords(level: JLPTLevel?, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func searchWords(level: JLPTLevel?, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        []
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        nil
    }

    func fetchWordSummary(wordId: Int) throws -> WordSummary? {
        nil
    }

    func randomWord(level: JLPTLevel) throws -> WordSummary? {
        nil
    }

    func randomWordIds(level: JLPTLevel, count: Int, excluding ids: Set<Int>) throws -> [Int] {
        []
    }

    func findByExpression(_ expression: String) throws -> WordSummary? {
        nil
    }

    func getRandomWords(limit: Int, excludingExpression: String?) throws -> [WordSummary] {
        []
    }
}

struct ErrorDictionaryRepository: DictionaryRepository {
    let error: Error

    func fetchWords(level: JLPTLevel?, limit: Int?, offset: Int?) throws -> [WordSummary] {
        throw error
    }

    func searchWords(level: JLPTLevel?, query: String, limit: Int?, offset: Int?) throws -> [WordSummary] {
        throw error
    }

    func fetchWordDetail(wordId: Int) throws -> WordDetail? {
        throw error
    }

    func fetchWordSummary(wordId: Int) throws -> WordSummary? {
        throw error
    }

    func randomWord(level: JLPTLevel) throws -> WordSummary? {
        throw error
    }

    func randomWordIds(level: JLPTLevel, count: Int, excluding ids: Set<Int>) throws -> [Int] {
        throw error
    }

    func findByExpression(_ expression: String) throws -> WordSummary? {
        throw error
    }

    func getRandomWords(limit: Int, excludingExpression: String?) throws -> [WordSummary] {
        throw error
    }
}
