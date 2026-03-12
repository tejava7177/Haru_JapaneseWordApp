import Foundation

struct UpdateLearningLevelRequest: Encodable {
    let learningLevel: String

    init(level: JLPTLevel) {
        self.learningLevel = level.rawValue
    }
}

struct UpdateLearningLevelResponse: Decodable {
    let userId: Int?
    let learningLevel: String?

    private enum CodingKeys: String, CodingKey {
        case userId
        case learningLevel
    }
}

struct RegenerateDailyWordsResponse: Decodable {
    let success: Bool?
    let message: String?
}
