import Foundation

protocol ProfileAPIServiceProtocol {
    func fetchUserProfile(userId: String) async throws -> ServerUserProfileResponse
    func updateLearningLevel(userId: String, level: JLPTLevel) async throws -> UpdateLearningLevelResponse
    func regenerateTodayDailyWords(userId: String) async throws -> RegenerateDailyWordsResponse
    func updateRandomMatching(userId: String, enabled: Bool) async throws -> ToggleRandomMatchingResponse
}

extension ProfileAPIServiceProtocol {
    func fetchUserProfile(userId: String) async throws -> ServerUserProfileResponse {
        ServerUserProfileResponse(
            userId: Int(userId),
            nickname: nil,
            learningLevel: nil,
            bio: nil,
            instagramId: nil,
            avatarBase64: nil,
            randomMatchingEnabled: nil
        )
    }
}

struct ProfileAPIService: ProfileAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func fetchUserProfile(userId: String) async throws -> ServerUserProfileResponse {
        print("[ProfileAPI] GET /api/users/\(userId)")
        let endpoint = APIEndpoint(path: "api/users/\(userId)")
        return try await client.get(endpoint, responseType: ServerUserProfileResponse.self)
    }

    nonisolated func updateLearningLevel(userId: String, level: JLPTLevel) async throws -> UpdateLearningLevelResponse {
        print("[ProfileAPI] PATCH /api/users/\(userId)/learning-level learningLevel=\(level.rawValue)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/learning-level",
            method: .patch
        )
        let request = UpdateLearningLevelRequest(level: level)
        return try await client.patch(endpoint, body: request, responseType: UpdateLearningLevelResponse.self)
    }

    nonisolated func regenerateTodayDailyWords(userId: String) async throws -> RegenerateDailyWordsResponse {
        // Temporary development-only hook. Replace this with the real reset API later.
        print("[ProfileAPI] POST /api/dev/daily-words/\(userId)/regenerate-today")
        let endpoint = APIEndpoint(
            path: "api/dev/daily-words/\(userId)/regenerate-today",
            method: .post
        )
        return try await client.post(endpoint, body: EmptyRequestBody(), responseType: RegenerateDailyWordsResponse.self)
    }

    nonisolated func updateRandomMatching(userId: String, enabled: Bool) async throws -> ToggleRandomMatchingResponse {
        print("[ProfileAPI] PATCH /api/users/\(userId)/random-matching enabled=\(enabled)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/random-matching",
            method: .patch
        )
        let request = ToggleRandomMatchingRequest(enabled: enabled)
        return try await client.patch(endpoint, body: request, responseType: ToggleRandomMatchingResponse.self)
    }
}

private struct EmptyRequestBody: Encodable {}
