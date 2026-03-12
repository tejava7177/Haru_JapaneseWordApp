import Foundation

struct DailyWordsTodayResponse: Decodable {
    let userId: Int?
    let targetDate: String
    let level: String?
    let items: [DailyWordsTodayItemResponse]

    private enum CodingKeys: String, CodingKey {
        case userId
        case targetDate
        case level
        case items
    }

    init(userId: Int?, targetDate: String, level: String?, items: [DailyWordsTodayItemResponse]) {
        self.userId = userId
        self.targetDate = targetDate
        self.level = level
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        targetDate = try container.decode(String.self, forKey: .targetDate)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        items = try container.decode([DailyWordsTodayItemResponse].self, forKey: .items)
    }
}

struct DailyWordsTodayItemResponse: Decodable {
    let dailyWordItemId: Int
    let wordId: Int
    let expression: String
    let reading: String
    let level: String
    let orderIndex: Int

    private enum CodingKeys: String, CodingKey {
        case dailyWordItemId
        case wordId
        case expression
        case reading
        case level
        case orderIndex
    }

    init(
        dailyWordItemId: Int,
        wordId: Int,
        expression: String,
        reading: String,
        level: String,
        orderIndex: Int
    ) {
        self.dailyWordItemId = dailyWordItemId
        self.wordId = wordId
        self.expression = expression
        self.reading = reading
        self.level = level
        self.orderIndex = orderIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyWordItemId = try container.decodeFlexibleInt(forKey: .dailyWordItemId)
        wordId = try container.decodeFlexibleInt(forKey: .wordId)
        expression = try container.decode(String.self, forKey: .expression)
        reading = try container.decode(String.self, forKey: .reading)
        level = try container.decode(String.self, forKey: .level)
        orderIndex = try container.decodeFlexibleInt(forKey: .orderIndex)
    }
}

struct TsunTsunTodayResponse: Decodable {
    let userId: Int?
    let buddyId: Int?
    let targetDate: String
    let sentCount: Int
    let receivedCount: Int
    let items: [TsunTsunTodayItemResponse]

    private enum CodingKeys: String, CodingKey {
        case userId
        case buddyId
        case targetDate
        case sentCount
        case receivedCount
        case items
    }

    init(
        userId: Int?,
        buddyId: Int?,
        targetDate: String,
        sentCount: Int,
        receivedCount: Int,
        items: [TsunTsunTodayItemResponse]
    ) {
        self.userId = userId
        self.buddyId = buddyId
        self.targetDate = targetDate
        self.sentCount = sentCount
        self.receivedCount = receivedCount
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        buddyId = try container.decodeFlexibleIntIfPresent(forKey: .buddyId)
        targetDate = try container.decode(String.self, forKey: .targetDate)
        sentCount = try container.decodeFlexibleInt(forKey: .sentCount)
        receivedCount = try container.decodeFlexibleInt(forKey: .receivedCount)
        items = try container.decode([TsunTsunTodayItemResponse].self, forKey: .items)
    }
}

struct TsunTsunTodayItemResponse: Decodable {
    let dailyWordItemId: Int
    let wordId: Int
    let direction: BuddyWordDirection
    let status: BuddyWordStatus

    private enum CodingKeys: String, CodingKey {
        case dailyWordItemId
        case wordId
        case direction
        case status
    }

    init(dailyWordItemId: Int, wordId: Int, direction: BuddyWordDirection, status: BuddyWordStatus) {
        self.dailyWordItemId = dailyWordItemId
        self.wordId = wordId
        self.direction = direction
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyWordItemId = try container.decodeFlexibleInt(forKey: .dailyWordItemId)
        wordId = try container.decodeFlexibleInt(forKey: .wordId)
        direction = try container.decode(BuddyWordDirection.self, forKey: .direction)
        status = try container.decode(BuddyWordStatus.self, forKey: .status)
    }
}

struct SendTsunTsunRequest: Encodable {
    let senderId: FlexibleUserID
    let receiverId: FlexibleUserID
    let dailyWordItemId: Int

    init(senderId: String, receiverId: String, dailyWordItemId: Int) {
        self.senderId = FlexibleUserID(rawValue: senderId)
        self.receiverId = FlexibleUserID(rawValue: receiverId)
        self.dailyWordItemId = dailyWordItemId
    }
}

struct SendTsunTsunResponse: Decodable {
    let success: Bool?
    let message: String?
}

enum BuddyWordDirection: String, Codable {
    case none = "NONE"
    case sent = "SENT"
    case received = "RECEIVED"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard let direction = BuddyWordDirection(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported BuddyWordDirection rawValue: \(rawValue)"
            )
        }

        self = direction
    }
}

enum BuddyWordStatus: String, Codable {
    case none = "NONE"
    case sent = "SENT"
    case answered = "ANSWERED"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard let status = BuddyWordStatus(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported BuddyWordStatus rawValue: \(rawValue)"
            )
        }

        self = status
    }
}

struct FlexibleUserID: Encodable, Equatable {
    let rawValue: String

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let numericValue = Int(rawValue) {
            try container.encode(numericValue)
        } else {
            try container.encode(rawValue)
        }
    }
}

struct BuddyWordItemUIModel: Identifiable, Equatable {
    let dailyWordItemId: Int
    let wordId: Int
    let expression: String
    let reading: String
    let level: JLPTLevel
    let orderIndex: Int
    let direction: BuddyWordDirection
    let status: BuddyWordStatus
    var isSelected: Bool

    var id: Int { dailyWordItemId }

    var isSelectable: Bool {
        status == .none
    }

    static func merge(
        dailyWords: [DailyWordsTodayItemResponse],
        statuses: [TsunTsunTodayItemResponse],
        selectedItemId: Int?
    ) -> [BuddyWordItemUIModel] {
        let statusByDailyWordId = Dictionary(uniqueKeysWithValues: statuses.map { ($0.dailyWordItemId, $0) })

        return dailyWords
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { item in
                let mergedStatus = statusByDailyWordId[item.dailyWordItemId]
                return BuddyWordItemUIModel(
                    dailyWordItemId: item.dailyWordItemId,
                    wordId: item.wordId,
                    expression: item.expression,
                    reading: item.reading,
                    level: JLPTLevel(rawValue: item.level) ?? .n5,
                    orderIndex: item.orderIndex,
                    direction: mergedStatus?.direction ?? .none,
                    status: mergedStatus?.status ?? .none,
                    isSelected: selectedItemId == item.dailyWordItemId
                )
            }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key),
           let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return intValue
        }

        if contains(key) == false {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Required Int field is missing: \(key.stringValue)"
                )
            )
        }

        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int or numeric String for key \(key.stringValue)"
            )
        )
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}
