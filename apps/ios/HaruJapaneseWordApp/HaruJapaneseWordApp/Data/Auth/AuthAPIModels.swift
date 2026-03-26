import Foundation

struct AppleAuthRequest: Encodable, Sendable {
    let identityToken: String
    let appleUserId: String
    let email: String?
    let displayName: String?

    private enum CodingKeys: String, CodingKey {
        case identityToken
        case appleUserId
        case email
        case displayName
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identityToken, forKey: .identityToken)
        try container.encode(appleUserId, forKey: .appleUserId)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
    }
}

struct AppleAuthResponse: Decodable, Sendable {
    let userId: Int?
    let appleUserId: String?
    let nickname: String?
    let learningLevel: JLPTLevel?
    let email: String?
    let displayName: String?
    let isNewUser: Bool?
    let sessionToken: String?

    private enum CodingKeys: String, CodingKey {
        case userId
        case appleUserId
        case nickname
        case learningLevel
        case email
        case displayName
        case isNewUser
        case sessionToken
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        appleUserId = try container.decodeIfPresent(String.self, forKey: .appleUserId)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        let learningLevelRaw = try container.decodeIfPresent(String.self, forKey: .learningLevel)
        learningLevel = learningLevelRaw.flatMap { JLPTLevel(rawValue: $0.uppercased()) }
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        isNewUser = try container.decodeIfPresent(Bool.self, forKey: .isNewUser)
        sessionToken = try container.decodeIfPresent(String.self, forKey: .sessionToken)
    }
}
