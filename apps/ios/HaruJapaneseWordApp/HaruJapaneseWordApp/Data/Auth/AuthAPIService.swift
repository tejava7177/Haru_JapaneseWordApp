import Foundation

protocol AuthAPIServiceProtocol {
    func authenticateWithApple(_ request: AppleAuthRequest) async throws -> AppleAuthResponse
}

struct AuthAPIService: AuthAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func authenticateWithApple(_ request: AppleAuthRequest) async throws -> AppleAuthResponse {
        let endpoint = APIEndpoint(path: "api/auth/apple", method: .post)
        return try await client.post(endpoint, body: request, responseType: AppleAuthResponse.self)
    }
}
