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
                if viewModel.isMateLoggedIn {
                    loggedInContent
                } else {
                    guestContent
                }
                appearanceSection
                notificationSettingsSection
                helpSection
                appInfoSection
            }
            .navigationTitle("프로필")
        }
        .onAppear {
            viewModel.onViewAppear()
        }
        .onChange(of: viewModel.selectedPhotoItem) { newItem in
            Task {
                await viewModel.loadAvatar(from: newItem)
            }
        }
        .onChange(of: viewModel.learningLevelNotice) { message in
            guard let message else { return }
            showToast(message: message)
            viewModel.clearLearningLevelNotice()
        }
        .onChange(of: viewModel.randomMatchingNotice) { message in
            guard let message else { return }
            showToast(message: message)
            viewModel.clearRandomMatchingNotice()
        }
        .onChange(of: viewModel.learningNotificationNotice) { message in
            guard let message else { return }
            showToast(message: message)
            viewModel.clearLearningNotificationNotice()
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
        .alert("학습 레벨 저장 실패", isPresented: Binding(get: {
            viewModel.learningLevelErrorMessage != nil
        }, set: { _ in
            viewModel.clearLearningLevelError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.learningLevelErrorMessage ?? "학습 레벨을 저장하지 못했어요.")
        }
        .alert("랜덤 매칭 설정 실패", isPresented: Binding(get: {
            viewModel.randomMatchingErrorMessage != nil
        }, set: { _ in
            viewModel.clearRandomMatchingError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.randomMatchingErrorMessage ?? "랜덤 매칭 설정을 저장하지 못했어요.")
        }
        .alert("사진 불러오기 실패", isPresented: Binding(get: {
            viewModel.avatarLoadErrorMessage != nil
        }, set: { _ in
            viewModel.clearAvatarLoadError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.avatarLoadErrorMessage ?? "선택한 사진을 불러오지 못했어요. 다른 사진으로 다시 시도해 주세요.")
        }
        .alert("학습 알림 설정 실패", isPresented: Binding(get: {
            viewModel.learningNotificationErrorMessage != nil
        }, set: { _ in
            viewModel.clearLearningNotificationError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.learningNotificationErrorMessage ?? "학습 알림 설정을 변경하지 못했어요.")
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

    @ViewBuilder
    private var loggedInContent: some View {
        profileSection
        accountSection
        learningSettingsSection
    }

    @ViewBuilder
    private var guestContent: some View {
        guestPromptSection
        guestLoginSection
    }

    private var profileSection: some View {
        Section("프로필") {
            HStack(spacing: 16) {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    avatarView
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    let nickname = viewModel.currentProfile.nickname
                    let bio = viewModel.currentProfile.bio.trimmingCharacters(in: .whitespacesAndNewlines)

                    Text(nickname.isEmpty ? "하루" : nickname)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if bio.isEmpty == false {
                        Text(bio)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text("현재 학습 레벨 \(viewModel.selectedLearningLevel.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)

            let nicknameBinding = Binding(
                get: { viewModel.currentProfile.nickname },
                set: { viewModel.updateNickname($0) }
            )
            let bioBinding = Binding(
                get: { viewModel.currentProfile.bio },
                set: { viewModel.updateBio($0) }
            )
            let instagramBinding = Binding(
                get: { viewModel.currentProfile.instagramId },
                set: { viewModel.updateInstagram($0) }
            )

            TextField("닉네임", text: nicknameBinding)
                .disabled(viewModel.isMateLoggedIn)

            TextField("한 줄 소개", text: bioBinding)
                .disabled(viewModel.isMateLoggedIn)

            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("인스타 아이디", text: instagramBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(viewModel.isMateLoggedIn)
            }

            if viewModel.isMateLoggedIn {
                Text("닉네임, 소개, 인스타는 현재 서버 값을 읽기 전용으로 표시해요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var guestPromptSection: some View {
        Section {
            GuestProfilePromptCardView()
        }
    }

    private var guestLoginSection: some View {
        Section("계정") {
            VStack(alignment: .leading, spacing: 12) {
                Text("로그인하면 프로필과 학습 설정을 저장하고, Mate 기능을 사용할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                AppleSignInButton { userId in
                    viewModel.signInWithApple(userId: userId)
                } onFailure: { error in
                    errorMessage = "Apple 로그인에 실패했어요. 다시 시도해 주세요.\n\(error.localizedDescription)"
                }
                .frame(height: 52)
            }
            .padding(.vertical, 4)
        }
    }

    private var accountSection: some View {
        Section("계정") {
            HStack {
                Text("로그인 상태")
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

            if viewModel.isMateLoggedIn {
                Toggle(isOn: Binding(
                    get: { viewModel.isRandomMatchingEnabled },
                    set: { viewModel.updateRandomMatchingEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("랜덤 매칭에 노출하기")
                        Text("켜두면 비슷한 레벨의 사용자에게 랜덤 후보로 보여져요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(viewModel.isUpdatingRandomMatching)

                if viewModel.isUpdatingRandomMatching {
                    ProgressView("설정 저장 중...")
                        .font(.footnote)
                }
            }

            Button(role: .destructive) {
                viewModel.signOutForMate()
            } label: {
                Text("로그아웃")
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
                                isSelected: viewModel.selectedLearningLevel == level
                            ) {
                                viewModel.updateProfileLevel(level)
                            }
                        }
                    }
                    .padding(.leading, viewModel.selectedLearningLevel == .n5 ? edgePadding + edgeCompensation : edgePadding)
                    .padding(.trailing, viewModel.selectedLearningLevel == .n1 ? edgePadding + edgeCompensation : edgePadding)
                    .padding(.vertical, 4)
                }
                .disabled(viewModel.isMateLoggedIn == false || viewModel.isUpdatingLearningLevel)

                if viewModel.isUpdatingLearningLevel {
                    ProgressView("학습 레벨 저장 중...")
                        .font(.footnote)
                }

                LevelDescriptionCard(level: viewModel.selectedLearningLevel)
            }
        }
    }

    private var appearanceSection: some View {
        Section("화면 설정") {
            Toggle(isOn: Binding(
                get: { viewModel.isDarkModeEnabled },
                set: { viewModel.updateDarkModeEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다크모드")
                    Text("앱 전체 화면을 어두운 테마로 표시해요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notificationSettingsSection: some View {
        Section("알림 설정") {
            Toggle(isOn: Binding(
                get: { viewModel.isLearningNotificationEnabled },
                set: { viewModel.updateLearningNotificationEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("학습 알림 받기")
                    Text("매일 정해진 시간에 오늘의 단어 알림을 받아요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.isUpdatingLearningNotification)

            if viewModel.isUpdatingLearningNotification {
                ProgressView("알림 설정 중...")
                    .font(.footnote)
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

    private var appInfoSection: some View {
        Section("앱 정보") {
            HStack {
                Text("버전")
                Spacer()
                Text(appVersionText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (shortVersion?, buildVersion?) where shortVersion != buildVersion:
            return "\(shortVersion) (\(buildVersion))"
        case let (shortVersion?, _):
            return shortVersion
        case let (_, buildVersion?):
            return buildVersion
        default:
            return "1.0.0"
        }
    }

    private var avatarView: some View {
        let size: CGFloat = 72
        return BuddyAvatarView(
            data: viewModel.localAvatarPreviewData ?? viewModel.currentProfile.avatarData,
            imageURLString: viewModel.currentProfile.profileImageUrl,
            size: size
        )
        .background(Color.black.opacity(0.04))
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

private struct GuestProfilePromptCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("로그인하고 동행을 시작해보세요")
                    .font(.headline)
                Text("로그인하면 프로필과 학습 설정을 저장하고, Mate 기능을 사용할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("로그인 후 사용 가능")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
