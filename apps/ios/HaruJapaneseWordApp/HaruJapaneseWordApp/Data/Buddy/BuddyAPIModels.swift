import Foundation

struct BuddySummaryResponse: Decodable, Identifiable, Equatable {
    let id: Int
    let userId: Int?
    let buddyUserId: Int?
    let buddyNickname: String?
    let status: String?
    let tikiTakaCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case buddyUserId
        case buddyNickname
        case status
        case tikiTakaCount
    }

    init(
        id: Int,
        userId: Int?,
        buddyUserId: Int?,
        buddyNickname: String?,
        status: String?,
        tikiTakaCount: Int?
    ) {
        self.id = id
        self.userId = userId
        self.buddyUserId = buddyUserId
        self.buddyNickname = buddyNickname
        self.status = status
        self.tikiTakaCount = tikiTakaCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        buddyUserId = try container.decodeFlexibleIntIfPresent(forKey: .buddyUserId)
        buddyNickname = try container.decodeIfPresent(String.self, forKey: .buddyNickname)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        tikiTakaCount = try container.decodeFlexibleIntIfPresent(forKey: .tikiTakaCount)
    }
}

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
    let tikiTakaCount: Int?
    let progressCount: Int?
    let progressGoal: Int?
    let pairCompletedToday: Bool?
    let items: [TsunTsunTodayItemResponse]

    private enum CodingKeys: String, CodingKey {
        case userId
        case buddyId
        case targetDate
        case sentCount
        case receivedCount
        case tikiTakaCount
        case progressCount
        case progressGoal
        case pairCompletedToday
        case items
    }

    init(
        userId: Int?,
        buddyId: Int?,
        targetDate: String,
        sentCount: Int,
        receivedCount: Int,
        tikiTakaCount: Int? = nil,
        progressCount: Int? = nil,
        progressGoal: Int? = nil,
        pairCompletedToday: Bool? = nil,
        items: [TsunTsunTodayItemResponse]
    ) {
        self.userId = userId
        self.buddyId = buddyId
        self.targetDate = targetDate
        self.sentCount = sentCount
        self.receivedCount = receivedCount
        self.tikiTakaCount = tikiTakaCount
        self.progressCount = progressCount
        self.progressGoal = progressGoal
        self.pairCompletedToday = pairCompletedToday
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        buddyId = try container.decodeFlexibleIntIfPresent(forKey: .buddyId)
        targetDate = try container.decode(String.self, forKey: .targetDate)
        sentCount = try container.decodeFlexibleInt(forKey: .sentCount)
        receivedCount = try container.decodeFlexibleInt(forKey: .receivedCount)
        tikiTakaCount = try container.decodeFlexibleIntIfPresent(forKey: .tikiTakaCount)
        progressCount = try container.decodeFlexibleIntIfPresent(forKey: .progressCount)
        progressGoal = try container.decodeFlexibleIntIfPresent(forKey: .progressGoal)
        pairCompletedToday = try container.decodeIfPresent(Bool.self, forKey: .pairCompletedToday)
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

struct TsunTsunInboxResponse: Decodable {
    let userId: Int?
    let unansweredCount: Int
    let items: [TsunTsunInboxItemResponse]

    private enum CodingKeys: String, CodingKey {
        case userId
        case unansweredCount
        case items
    }

    init(userId: Int?, unansweredCount: Int, items: [TsunTsunInboxItemResponse]) {
        self.userId = userId
        self.unansweredCount = unansweredCount
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeFlexibleIntIfPresent(forKey: .userId)
        unansweredCount = try container.decodeFlexibleInt(forKey: .unansweredCount)
        items = try container.decode([TsunTsunInboxItemResponse].self, forKey: .items)
    }
}

struct TsunTsunInboxItemResponse: Decodable, Identifiable, Hashable {
    let tsuntsunId: Int
    let senderId: Int?
    let senderName: String
    let wordId: Int
    let expression: String
    let reading: String
    let targetDate: String
    let choices: [TsunTsunChoiceResponse]

    var id: Int { tsuntsunId }

    private enum CodingKeys: String, CodingKey {
        case tsuntsunId
        case senderId
        case senderName
        case wordId
        case expression
        case reading
        case targetDate
        case choices
    }

    init(
        tsuntsunId: Int,
        senderId: Int?,
        senderName: String,
        wordId: Int,
        expression: String,
        reading: String,
        targetDate: String,
        choices: [TsunTsunChoiceResponse]
    ) {
        self.tsuntsunId = tsuntsunId
        self.senderId = senderId
        self.senderName = senderName
        self.wordId = wordId
        self.expression = expression
        self.reading = reading
        self.targetDate = targetDate
        self.choices = choices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tsuntsunId = try container.decodeFlexibleInt(forKey: .tsuntsunId)
        senderId = try container.decodeFlexibleIntIfPresent(forKey: .senderId)
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        wordId = try container.decodeFlexibleInt(forKey: .wordId)
        expression = try container.decode(String.self, forKey: .expression)
        reading = try container.decodeIfPresent(String.self, forKey: .reading) ?? ""
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate) ?? ""
        choices = try container.decodeIfPresent([TsunTsunChoiceResponse].self, forKey: .choices) ?? []
    }
}

struct TsunTsunChoiceResponse: Decodable, Identifiable, Hashable {
    let meaningId: Int
    let text: String

    var id: Int { meaningId }

    private enum CodingKeys: String, CodingKey {
        case meaningId
        case text
    }

    init(meaningId: Int, text: String) {
        self.meaningId = meaningId
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meaningId = try container.decodeFlexibleInt(forKey: .meaningId)
        text = try container.decode(String.self, forKey: .text)
    }
}

struct AnswerTsunTsunRequest: Encodable {
    let tsuntsunId: Int
    let meaningId: Int
}

struct AnswerTsunTsunResponse: Decodable {
    let tsuntsunId: Int?
    let success: Bool?
    let message: String?
    let isCorrect: Bool?
    let correctMeaningId: Int?
    let correctText: String?
    let selectedMeaningId: Int?
    let selectedText: String?
    let remainingUnansweredCount: Int?

    private enum CodingKeys: String, CodingKey {
        case tsuntsunId
        case success
        case message
        case isCorrect
        case correctMeaningId
        case correctText
        case selectedMeaningId
        case selectedText
        case remainingUnansweredCount
    }

    init(
        tsuntsunId: Int?,
        success: Bool?,
        message: String?,
        isCorrect: Bool?,
        correctMeaningId: Int?,
        correctText: String?,
        selectedMeaningId: Int?,
        selectedText: String?,
        remainingUnansweredCount: Int?
    ) {
        self.tsuntsunId = tsuntsunId
        self.success = success
        self.message = message
        self.isCorrect = isCorrect
        self.correctMeaningId = correctMeaningId
        self.correctText = correctText
        self.selectedMeaningId = selectedMeaningId
        self.selectedText = selectedText
        self.remainingUnansweredCount = remainingUnansweredCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tsuntsunId = try container.decodeFlexibleIntIfPresent(forKey: .tsuntsunId)
        success = try container.decodeFlexibleBoolIfPresent(forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isCorrect = try container.decodeFlexibleBoolIfPresent(forKey: .isCorrect)
        correctMeaningId = try container.decodeFlexibleIntIfPresent(forKey: .correctMeaningId)
        correctText = try container.decodeIfPresent(String.self, forKey: .correctText)
        selectedMeaningId = try container.decodeFlexibleIntIfPresent(forKey: .selectedMeaningId)
        selectedText = try container.decodeIfPresent(String.self, forKey: .selectedText)
        remainingUnansweredCount = try container.decodeFlexibleIntIfPresent(forKey: .remainingUnansweredCount)
    }
}

struct TsunTsunInboxSummary: Equatable {
    let unansweredCount: Int
    let senderName: String
    let expression: String
    let reading: String
    let promptText: String

    var arrivalText: String {
        "지금 \(unansweredCount)개의 츤츤이 도착했어요"
    }

    var senderHeadline: String {
        if senderName.isEmpty {
            return "버디가 츤츤을 보냈어요"
        }
        return "\(senderName)이 츤츤을 보냈어요"
    }

    static func fromInbox(
        _ response: TsunTsunInboxResponse,
        resolveSenderName: (TsunTsunInboxItemResponse) -> String
    ) -> TsunTsunInboxSummary? {
        let sortedItems = response.items.sorted(by: TsunTsunInboxItemResponse.sortForInbox)
        guard response.unansweredCount > 0, let firstItem = sortedItems.first else {
            return nil
        }

        return TsunTsunInboxSummary(
            unansweredCount: response.unansweredCount,
            senderName: resolveSenderName(firstItem),
            expression: firstItem.expression,
            reading: firstItem.reading,
            promptText: "『\(firstItem.expression)』의 뜻을 알고 있나요?"
        )
    }
}

extension TsunTsunInboxItemResponse {
    nonisolated static func sortForInbox(_ lhs: TsunTsunInboxItemResponse, _ rhs: TsunTsunInboxItemResponse) -> Bool {
        if lhs.targetDate != rhs.targetDate {
            return lhs.targetDate > rhs.targetDate
        }
        return lhs.tsuntsunId > rhs.tsuntsunId
    }
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
