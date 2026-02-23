import Foundation
import AuthenticationServices

enum AppleAuthError: Error {
    case invalidCredential
}

final class AppleAuthService {
    func userId(from result: Result<ASAuthorization, Error>) async throws -> String {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleAuthError.invalidCredential
        }
        return credential.user
    }
}
