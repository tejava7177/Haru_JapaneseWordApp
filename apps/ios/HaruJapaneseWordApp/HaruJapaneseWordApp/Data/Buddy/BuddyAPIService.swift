import Foundation

protocol BuddyAPIServiceProtocol {
    func fetchBuddies(userId: String) async throws -> [BuddySummaryResponse]
    func connectBuddy(userId: String, buddyCode: String) async throws -> BuddyMutationResponse?
    func deleteBuddy(userId: String, buddyUserId: Int) async throws -> BuddyMutationResponse?
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse
    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse
    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse?
    func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse
    func answerTsunTsun(tsuntsunId: Int, meaningId: Int) async throws -> AnswerTsunTsunResponse
    func fetchRandomCandidates(userId: String) async throws -> [RandomCandidateResponse]
    func fetchIncomingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse]
    func fetchOutgoingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse]
    func createBuddyRequest(requesterId: String, receiverId: String) async throws -> BuddyRequestActionResponse?
    func acceptBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse?
    func rejectBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse?
}

extension BuddyAPIServiceProtocol {
    func connectBuddy(userId: String, buddyCode: String) async throws -> BuddyMutationResponse? { nil }
    func deleteBuddy(userId: String, buddyUserId: Int) async throws -> BuddyMutationResponse? { nil }
    func fetchRandomCandidates(userId: String) async throws -> [RandomCandidateResponse] { [] }
    func fetchIncomingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse] { [] }
    func fetchOutgoingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse] { [] }
    func createBuddyRequest(requesterId: String, receiverId: String) async throws -> BuddyRequestActionResponse? { nil }
    func acceptBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse? { nil }
    func rejectBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse? { nil }
}

struct BuddyAPIService: BuddyAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func fetchBuddies(userId: String) async throws -> [BuddySummaryResponse] {
        print("[BuddyAPI] GET /api/buddies?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/buddies",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: [BuddySummaryResponse].self)
    }

    nonisolated func connectBuddy(userId: String, buddyCode: String) async throws -> BuddyMutationResponse? {
        let endpoint = APIEndpoint(path: "api/buddies/connect", method: .post)
        let request = ConnectBuddyRequest(userId: userId, buddyCode: buddyCode)
        print("[BuddyAPI] POST /api/buddies/connect body={\"userId\":\(userId),\"buddyCode\":\"\(buddyCode)\"}")

        do {
            return try await client.post(endpoint, body: request, responseType: BuddyMutationResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: request)
            return nil
        }
    }

    nonisolated func deleteBuddy(userId: String, buddyUserId: Int) async throws -> BuddyMutationResponse? {
        print("[BuddyAPI] DELETE /api/buddies?userId=\(userId)&buddyUserId=\(buddyUserId)")
        let endpoint = APIEndpoint(
            path: "api/buddies",
            method: .delete,
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "buddyUserId", value: String(buddyUserId))
            ]
        )

        do {
            return try await client.delete(endpoint, responseType: BuddyMutationResponse.self)
        } catch APIError.decodingFailed {
            try await client.delete(endpoint)
            return nil
        }
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

    nonisolated func fetchRandomCandidates(userId: String) async throws -> [RandomCandidateResponse] {
        print("[BuddyAPI] GET /api/buddies/random-candidates?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/buddies/random-candidates",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: [RandomCandidateResponse].self)
    }

    nonisolated func fetchIncomingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse] {
        print("[BuddyAPI] GET /api/buddy-requests/incoming?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/buddy-requests/incoming",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: [BuddyRequestResponse].self)
    }

    nonisolated func fetchOutgoingBuddyRequests(userId: String) async throws -> [BuddyRequestResponse] {
        print("[BuddyAPI] GET /api/buddy-requests/outgoing?userId=\(userId)")
        let endpoint = APIEndpoint(
            path: "api/buddy-requests/outgoing",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )
        return try await client.get(endpoint, responseType: [BuddyRequestResponse].self)
    }

    nonisolated func createBuddyRequest(requesterId: String, receiverId: String) async throws -> BuddyRequestActionResponse? {
        let endpoint = APIEndpoint(path: "api/buddy-requests", method: .post)
        let request = CreateBuddyRequestRequest(requesterId: requesterId, receiverId: receiverId)

        do {
            return try await client.post(endpoint, body: request, responseType: BuddyRequestActionResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: request)
            return nil
        }
    }

    nonisolated func acceptBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse? {
        let endpoint = APIEndpoint(path: "api/buddy-requests/\(requestId)/accept", method: .post)

        do {
            return try await client.post(endpoint, body: EmptyBuddyRequestBody(), responseType: BuddyRequestActionResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: EmptyBuddyRequestBody())
            return nil
        }
    }

    nonisolated func rejectBuddyRequest(requestId: Int) async throws -> BuddyRequestActionResponse? {
        let endpoint = APIEndpoint(path: "api/buddy-requests/\(requestId)/reject", method: .post)

        do {
            return try await client.post(endpoint, body: EmptyBuddyRequestBody(), responseType: BuddyRequestActionResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: EmptyBuddyRequestBody())
            return nil
        }
    }
}

private struct EmptyBuddyRequestBody: Encodable {}
