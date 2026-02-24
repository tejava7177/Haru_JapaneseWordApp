import SwiftUI
import PhotosUI
import UIKit
import Foundation
import AuthenticationServices

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isGuidePresented: Bool = false
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var errorMessage: String?

    private let levelOptions: [JLPTLevel] = [.n5, .n4, .n3, .n2, .n1]

    init(settingsStore: AppSettingsStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            Form {
                profileHeaderSection
                signInSection
                profileEditSection
                learningSettingsSection
                helpSection
                dataSection
            }
            .navigationTitle("프로필")
        }
        .onChange(of: viewModel.selectedPhotoItem) { newItem in
            Task {
                await viewModel.loadAvatar(from: newItem)
            }
        }
        .alert("학습 데이터 초기화", isPresented: $viewModel.isResetAlertPresented) {
            Button("초기화", role: .destructive) {
                viewModel.resetLearningData()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("오늘의 덱과 학습 체크 기록을 초기화합니다.")
        }
        .alert("로그인 실패", isPresented: Binding(get: {
            errorMessage != nil
        }, set: { _ in
            errorMessage = nil
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $isGuidePresented) {
            GuideView()
        }
        .overlay(alignment: .bottom) {
            if isShowingToast {
                Text(toastMessage)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var profileHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    avatarView
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    let nickname = viewModel.profile.nickname
                    Text(nickname.isEmpty ? "하루" : nickname)
                        .font(.title3)
                        .fontWeight(.semibold)
                            Text(viewModel.isMateLoggedIn ? "Mate 로그인됨" : "프로필을 설정해 보세요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var signInSection: some View {
        Section("로그인") {
                    if viewModel.isMateLoggedIn {
                        HStack {
                            Text("Mate 로그인 상태예요.")
                            Spacer()
                            if viewModel.mateUserIdPrefix.isEmpty == false {
                                Text(viewModel.mateUserIdPrefix)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("연결됨")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            viewModel.signOutForMate()
                        } label: {
                            Text("Mate 로그아웃")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Apple로 로그인하면 Mate(동행) 기능을 사용할 수 있어요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            #if targetEnvironment(simulator)
                            VStack(alignment: .leading, spacing: 8) {
                                Button("Dev Slot A로 로그인") {
                                    viewModel.signInForMateDevSlot(.A)
                                }
                                Button("Dev Slot B로 로그인") {
                                    viewModel.signInForMateDevSlot(.B)
                                }
                                Button("Dev Slot C로 로그인") {
                                    viewModel.signInForMateDevSlot(.C)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.black)
                            #else
                            AppleSignInButton { userId in
                                viewModel.signInWithApple(userId: userId)
                            } onFailure: { error in
                                errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요.\n\(error.localizedDescription)"
                            }
                            .frame(height: 52)
                            #endif
                        }
                        .padding(.vertical, 4)
                    }
                }
    }

    private var profileEditSection: some View {
        Section("프로필") {
            let nicknameBinding = Binding(
                get: { viewModel.profile.nickname },
                set: { viewModel.updateNickname($0) }
            )
            let bioBinding = Binding(
                get: { viewModel.profile.bio },
                set: { viewModel.updateBio($0) }
            )
            let instagramBinding = Binding(
                get: { viewModel.profile.instagramId },
                set: { viewModel.updateInstagram($0) }
            )

            TextField("닉네임", text: nicknameBinding)

            TextField("한 줄 소개", text: bioBinding)

            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("인스타 아이디", text: instagramBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var learningSettingsSection: some View {
        Section("학습 설정") {
            VStack(alignment: .leading, spacing: 12) {
                Text("학습 레벨은 하나만 선택할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                let edgePadding: CGFloat = 16
                let edgeCompensation: CGFloat = 16

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(levelOptions) { level in
                            LevelSelectionChip(
                                level: level,
                                isSelected: viewModel.settings.homeDeckLevel == level
                            ) {
                                viewModel.updateHomeDeckLevel(level)
                                showToast(message: "학습 레벨이 \(level.title)로 설정됐어요")
                            }
                        }
                    }
                    .padding(.leading, viewModel.settings.homeDeckLevel == .n5 ? edgePadding + edgeCompensation : edgePadding)
                    .padding(.trailing, viewModel.settings.homeDeckLevel == .n1 ? edgePadding + edgeCompensation : edgePadding)
                    .padding(.vertical, 4)
                }

                LevelDescriptionCard(level: viewModel.settings.homeDeckLevel)
            }
        }
    }

    private var helpSection: some View {
        Section("도움말") {
            Button {
                isGuidePresented = true
            } label: {
                Text("사용 가이드")
            }
        }
    }

    private var dataSection: some View {
        Section("데이터") {
            Button(role: .destructive) {
                viewModel.isResetAlertPresented = true
            } label: {
                Text("학습 데이터 초기화")
            }
        }
    }

    private var avatarView: some View {
        let size: CGFloat = 72
        return Group {
            if let data = viewModel.profile.avatarData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.04))
        .clipShape(Circle())
    }

    private func showToast(message: String) {
        toastMessage = message
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingToast = false
            }
        }
    }
}

private struct LevelSelectionChip: View {
    let level: JLPTLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        let extraTrailingForCheck: CGFloat = 16
        Button(action: onTap) {
            Text(level.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .padding(.trailing, isSelected ? extraTrailingForCheck : 0)
                .background(isSelected ? Color.accentColor : Color.clear)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accentColor : Color(uiColor: .systemGray3), lineWidth: 1)
                )
                .clipShape(Capsule())
                .overlay(alignment: .trailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.trailing, 8)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.title) 레벨")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct LevelDescriptionCard: View {
    let level: JLPTLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(level.title) 레벨")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(descriptionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var descriptionText: String {
        switch level {
        case .n5:
            return "기초 어휘와 문형 중심으로 학습해요."
        case .n4:
            return "일상 표현을 자연스럽게 익힐 수 있어요."
        case .n3:
            return "중급 문법과 어휘를 균형 있게 학습해요."
        case .n2:
            return "상급 독해와 표현을 강화하는 단계예요."
        case .n1:
            return "고급 어휘와 복잡한 표현을 학습해요."
        }
    }
}

#Preview {
    ProfileView(settingsStore: AppSettingsStore())
}

// Real implementation of Sign in with Apple button using AuthenticationServices
struct AppleSignInButton: View {
    let onSuccess: (String) -> Void
    let onFailure: (Error) -> Void

    var body: some View {
        SignInWithAppleButtonRepresentable(onSuccess: onSuccess, onFailure: onFailure)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Apple로 로그인")
    }
}

private struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onSuccess: (String) -> Void
    let onFailure: (Error) -> Void
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        print("[AppleSignInButton] makeUIView")
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        print("[AppleSignInButton] makeCoordinator")
        return Coordinator(onSuccess: onSuccess, onFailure: onFailure)
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onSuccess: (String) -> Void
        let onFailure: (Error) -> Void
        private var hasCallback: Bool = false
        private var watchdogWorkItem: DispatchWorkItem?

        init(onSuccess: @escaping (String) -> Void, onFailure: @escaping (Error) -> Void) {
            self.onSuccess = onSuccess
            self.onFailure = onFailure
            super.init()
            print("[AppleSignInButton] coordinatorInit")
        }

        deinit {
            print("[AppleSignInButton] coordinatorDeinit")
        }

        @objc func didTapButton() {
            print("[AppleSignInButton] tap")
            hasCallback = false
            watchdogWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, self.hasCallback == false else { return }
                print("[AppleSignInButton] watchdogTimeout (no callback within 8s)")
            }
            watchdogWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)

            print("[AppleAuth] start")
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            print("[AppleAuth] makeRequest")

            let controller = ASAuthorizationController(authorizationRequests: [request])
            print("[AppleAuth] controllerCreated")
            controller.delegate = self
            controller.presentationContextProvider = self
            print("[AppleAuth] performRequests")
            controller.performRequests()
        }

        // MARK: - ASAuthorizationControllerDelegate
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            hasCallback = true
            watchdogWorkItem?.cancel()
            print("[AppleSignInButton] didCompleteWithAuthorization")
            print("[AppleAuth] success")
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // The stable user identifier for the app and developer team
                let userID = credential.user
                onSuccess(userID)
            } else {
                onFailure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "인증 자격 증명을 가져올 수 없어요."]))
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            hasCallback = true
            watchdogWorkItem?.cancel()
            print("[AppleSignInButton] didCompleteWithError")
            let nsError = error as NSError
            let authCode = ASAuthorizationError.Code(rawValue: nsError.code)
            let userInfoKeys = nsError.userInfo.keys.map { "\($0)" }
            if nsError.domain == ASAuthorizationError.errorDomain, let authCode {
                print("[AppleAuth] failure domain=\(nsError.domain) code=\(nsError.code) authCode=\(authCode) description=\(nsError.localizedDescription)")
            } else {
                print("[AppleAuth] failure domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)")
            }
            print("[AppleAuth] failure userInfoKeys=\(userInfoKeys)")
            onFailure(error)
        }

        // MARK: - ASAuthorizationControllerPresentationContextProviding
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            print("[AppleSignInButton] presentationAnchor")
            // Try to find a key window for presentation
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
