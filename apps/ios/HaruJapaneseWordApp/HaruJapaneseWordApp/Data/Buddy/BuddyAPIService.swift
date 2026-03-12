import Foundation

protocol BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse
    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse
    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse?
    func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse
    func answerTsunTsun(tsuntsunId: Int, meaningId: Int) async throws -> AnswerTsunTsunResponse
}

struct BuddyAPIService: BuddyAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        print("[BuddyAPI] GET /api/daily-words/today?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/daily-words/today",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: DailyWordsTodayResponse.self)
    }

    nonisolated func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse {
        print("[BuddyAPI] GET /api/tsuntsun/today?userId=\(userId)&buddyId=\(buddyId)")
        let endpoint = APIEndpoint(
            path: "api/tsuntsun/today",
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "buddyId", value: buddyId)
            ]
        )
        return try await client.get(endpoint, responseType: TsunTsunTodayResponse.self)
    }

    nonisolated func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse? {
        let endpoint = APIEndpoint(path: "api/tsuntsun", method: .post)
        let request = SendTsunTsunRequest(
            senderId: senderId,
            receiverId: receiverId,
            dailyWordItemId: dailyWordItemId
        )

        do {
            return try await client.post(endpoint, body: request, responseType: SendTsunTsunResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: request)
            return nil
        }
    }

    nonisolated func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse {
        print("[BuddyAPI] GET /api/tsuntsun/inbox?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/tsuntsun/inbox",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: TsunTsunInboxResponse.self)
    }

    nonisolated func answerTsunTsun(tsuntsunId: Int, meaningId: Int) async throws -> AnswerTsunTsunResponse {
        let endpoint = APIEndpoint(path: "api/tsuntsun/answer", method: .post)
        let request = AnswerTsunTsunRequest(tsuntsunId: tsuntsunId, meaningId: meaningId)

        do {
            return try await client.post(endpoint, body: request, responseType: AnswerTsunTsunResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: request)
            return AnswerTsunTsunResponse(
                tsuntsunId: tsuntsunId,
                success: true,
                message: nil,
                isCorrect: nil,
                correctMeaningId: nil,
                correctText: nil,
                selectedMeaningId: meaningId,
                selectedText: nil,
                remainingUnansweredCount: nil
            )
        }
    }
}
