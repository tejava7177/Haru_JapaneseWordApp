import Foundation

protocol HomeAPIServiceProtocol {
    func fetchTodayDailyWords(userId: String) async throws -> DailyWordsTodayResponse
}

struct HomeAPIService: HomeAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func fetchTodayDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        let endpoint = APIEndpoint(
            path: "api/daily-words/today",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: DailyWordsTodayResponse.self)
    }
}
