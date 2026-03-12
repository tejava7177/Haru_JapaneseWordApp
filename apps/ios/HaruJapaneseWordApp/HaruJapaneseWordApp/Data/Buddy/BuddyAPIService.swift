import Foundation

protocol BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse
    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse
    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse?
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
}
