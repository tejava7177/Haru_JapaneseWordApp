import Foundation

protocol ProfileAPIServiceProtocol {
    func fetchUserProfile(userId: String) async throws -> ServerUserProfileResponse
    func updateUserProfile(userId: String, nickname: String, bio: String, instagramId: String) async throws -> ServerUserProfileResponse
    func uploadProfileImage(userId: String, imageData: Data, fileName: String, mimeType: String) async throws -> UploadProfileImageResponse
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
            buddyCode: nil,
            profileImageUrl: nil,
            avatarBase64: nil,
            randomMatchingEnabled: nil
        )
    }
    func updateUserProfile(userId: String, nickname: String, bio: String, instagramId: String) async throws -> ServerUserProfileResponse {
        try await fetchUserProfile(userId: userId)
    }
    func uploadProfileImage(userId: String, imageData: Data, fileName: String, mimeType: String) async throws -> UploadProfileImageResponse {
        UploadProfileImageResponse(userId: Int(userId), profileImageUrl: nil)
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

    nonisolated func updateUserProfile(
        userId: String,
        nickname: String,
        bio: String,
        instagramId: String
    ) async throws -> ServerUserProfileResponse {
        print("[ProfileAPI] PATCH /api/users/\(userId)/profile")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/profile",
            method: .patch
        )
        let request = UpdateUserProfileRequest(
            nickname: nickname,
            bio: bio,
            instagramId: instagramId
        )
        return try await client.patch(endpoint, body: request, responseType: ServerUserProfileResponse.self)
    }

    nonisolated func uploadProfileImage(
        userId: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> UploadProfileImageResponse {
        print("[ProfileAPI] POST /api/users/\(userId)/profile-image multipart fileName=\(fileName) mimeType=\(mimeType)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/profile-image",
            method: .post
        )
        do {
            return try await client.postMultipart(
                endpoint,
                fileData: imageData,
                fieldName: "file",
                fileName: fileName,
                mimeType: mimeType,
                responseType: UploadProfileImageResponse.self
            )
        } catch APIError.decodingFailed {
            _ = try await client.postMultipart(
                endpoint,
                fileData: imageData,
                fieldName: "file",
                fileName: fileName,
                mimeType: mimeType,
                responseType: EmptyUploadProfileImageResponse.self
            )
            return UploadProfileImageResponse(userId: Int(userId), profileImageUrl: nil)
        }
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
private struct EmptyUploadProfileImageResponse: Decodable {}
