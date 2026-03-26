import Foundation

struct ServerUserProfileResponse: Decodable {
    let userId: Int?
    let nickname: String?
    let learningLevel: JLPTLevel?
    let bio: String?
    let instagramId: String?
    let buddyCode: String?
    let profileImageUrl: String?
    let avatarBase64: String?
    let randomMatchingEnabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case userId
        case id
        case nickname
        case displayName
        case name
        case learningLevel
        case jlptLevel
        case level
        case bio
        case introduction
        case oneLineIntro
        case instagramId
        case instagram
        case instagramHandle
        case buddyCode
        case profileImageUrl
        case profileImageURL
        case profileImage
        case imageUrl
        case imageURL
        case avatarBase64
        case avatarImageBase64
        case avatar
        case randomMatchingEnabled
        case enabled
        case isEnabled
    }

    init(
        userId: Int?,
        nickname: String?,
        learningLevel: JLPTLevel?,
        bio: String?,
        instagramId: String?,
        buddyCode: String?,
        profileImageUrl: String?,
        avatarBase64: String?,
        randomMatchingEnabled: Bool?
    ) {
        self.userId = userId
        self.nickname = nickname
        self.learningLevel = learningLevel
        self.bio = bio
        self.instagramId = instagramId
        self.buddyCode = buddyCode
        self.profileImageUrl = profileImageUrl
        self.avatarBase64 = avatarBase64
        self.randomMatchingEnabled = randomMatchingEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
            ?? container.decodeFlexibleIntIfPresent(forKey: .id)
        nickname = try container.decodeFirstNonEmptyString(forKeys: [.nickname, .displayName, .name])
        let levelRaw = try container.decodeFirstNonEmptyString(forKeys: [.learningLevel, .jlptLevel, .level])
        learningLevel = levelRaw.flatMap { JLPTLevel(rawValue: $0.uppercased()) }
        bio = try container.decodeFirstNonEmptyString(forKeys: [.bio, .introduction, .oneLineIntro])
        instagramId = try container.decodeFirstNonEmptyString(forKeys: [.instagramId, .instagram, .instagramHandle])
        buddyCode = try container.decodeFirstNonEmptyString(forKeys: [.buddyCode])
        profileImageUrl = try container.decodeFirstNonEmptyString(forKeys: [.profileImageUrl, .profileImageURL, .profileImage, .imageUrl, .imageURL])
        avatarBase64 = try container.decodeFirstNonEmptyString(forKeys: [.avatarBase64, .avatarImageBase64, .avatar])
        randomMatchingEnabled = try container.decodeFlexibleBoolIfPresent(forKey: .randomMatchingEnabled)
            ?? container.decodeFlexibleBoolIfPresent(forKey: .enabled)
            ?? container.decodeFlexibleBoolIfPresent(forKey: .isEnabled)
    }
}

struct UploadProfileImageResponse: Decodable {
    let userId: Int?
    let profileImageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case userId
        case id
        case profileImageUrl
        case profileImageURL
        case profileImage
        case imageUrl
        case imageURL
    }

    init(userId: Int?, profileImageUrl: String?) {
        self.userId = userId
        self.profileImageUrl = profileImageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
            ?? container.decodeFlexibleIntIfPresent(forKey: .id)
        profileImageUrl = try container.decodeFirstNonEmptyString(forKeys: [.profileImageUrl, .profileImageURL, .profileImage, .imageUrl, .imageURL])
    }
}

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
        case randomMatchingEnabled
    }

    init(userId: Int?, enabled: Bool?) {
        self.userId = userId
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        enabled = try container.decodeFlexibleBoolIfPresent(forKey: .randomMatchingEnabled)
            ?? container.decodeFlexibleBoolIfPresent(forKey: .enabled)
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

    func decodeFirstNonEmptyString(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               value.isEmpty == false {
                return value
            }
        }
        return nil
    }
}
