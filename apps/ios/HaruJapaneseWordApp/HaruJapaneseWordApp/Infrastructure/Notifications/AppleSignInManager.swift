import AuthenticationServices
import Foundation
import UIKit

struct AppleSignInResult {
    let userId: String
    let fullName: PersonNameComponents?
    let email: String?
    let identityToken: Data?
}

@MainActor
final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentController: ASAuthorizationController?

    func signIn() async throws -> AppleSignInResult {
        guard continuation == nil else {
            throw NSError(
                domain: "AppleSignIn",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "이미 Apple 로그인이 진행 중이에요."]
            )
        }

        print("[AppleSignIn] button tapped")

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            currentController = controller
            controller.delegate = self
            controller.presentationContextProvider = self

            print("[AppleSignIn] authorization request started")
            controller.performRequests()
        }
    }

    private func finish(with result: Result<AppleSignInResult, Error>) {
        currentController = nil
        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(NSError(
                domain: "AppleSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "인증 자격 증명을 가져오지 못했어요."]
            )))
            return
        }

        let userId = credential.user
        let hasIdentityToken = credential.identityToken != nil
        let hasFullName = credential.fullName != nil
        let hasEmail = credential.email != nil

        print("[AppleSignIn] authorization success user=\(userId)")
        print("[AppleSignIn] identityToken exists=\(hasIdentityToken)")
        print("[AppleSignIn] fullName exists=\(hasFullName)")
        print("[AppleSignIn] email exists=\(hasEmail)")

        finish(with: .success(AppleSignInResult(
            userId: userId,
            fullName: credential.fullName,
            email: credential.email,
            identityToken: credential.identityToken
        )))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("[AppleSignIn] authorization failed error=\(error.localizedDescription)")
        finish(with: .failure(error))
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
