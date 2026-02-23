import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    let onSuccess: (String) -> Void
    let onFailure: (Error) -> Void

    private let authService = AppleAuthService()

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = []
        } onCompletion: { result in
            Task {
                do {
                    let userId = try await authService.userId(from: result)
                    await MainActor.run {
                        onSuccess(userId)
                    }
                } catch {
                    await MainActor.run {
                        onFailure(error)
                    }
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
    }
}
