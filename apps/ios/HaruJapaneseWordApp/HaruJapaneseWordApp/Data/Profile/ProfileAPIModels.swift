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

struct ToggleRandomMatchingRequest: Encodable {
    let enabled: Bool
}

struct ToggleRandomMatchingResponse: Decodable {
    let userId: Int?
    let enabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case userId
        case enabled
        case isEnabled
    }

    init(userId: Int?, enabled: Bool?) {
        self.userId = userId
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        enabled = try container.decodeFlexibleBoolIfPresent(forKey: .enabled)
            ?? container.decodeFlexibleBoolIfPresent(forKey: .isEnabled)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    func decodeFlexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let boolValue = try decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        }

        return nil
    }
}
