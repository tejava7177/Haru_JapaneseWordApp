import Foundation

protocol DeviceAPIServiceProtocol {
    func registerDeviceToken(userId: String, token: String) async throws
    func unregisterDeviceToken(userId: String, token: String) async throws
}

struct DeviceAPIService: DeviceAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func registerDeviceToken(userId: String, token: String) async throws {
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/devices",
            method: .post
        )
        let request = RegisterDeviceTokenRequest(deviceToken: token)
        try await client.post(endpoint, body: request)
    }

    nonisolated func unregisterDeviceToken(userId: String, token: String) async throws {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/devices/\(encodedToken)",
            method: .delete
        )
        try await client.delete(endpoint)
    }
}
