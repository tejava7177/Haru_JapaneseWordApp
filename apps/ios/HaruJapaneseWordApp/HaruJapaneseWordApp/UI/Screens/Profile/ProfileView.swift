import SwiftUI
import PhotosUI
import UIKit
import Foundation
import AuthenticationServices

private enum ProfileEditField: String, Hashable {
    case nickname
    case bio
    case instagramId
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isGuidePresented: Bool = false
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: ProfileEditField?

    private let levelOptions: [JLPTLevel] = [.n5, .n4, .n3, .n2, .n1]

    init(settingsStore: AppSettingsStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(settingsStore: settingsStore))
    }

    var body: some View {
        navigationContent
        .onAppear {
            viewModel.onViewAppear()
        }
        .onChange(of: viewModel.selectedPhotoItem) { newItem in
            print("[ProfileImage] picker item selected")
            Task {
                await viewModel.loadAvatar(from: newItem)
            }
        }
        .onChange(of: focusedField) { field in
            print("[ProfileEdit] focus changed field=\(field?.rawValue ?? "nil")")
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
        .onChange(of: viewModel.appleSignInNotice) { message in
            guard let message else { return }
            showToast(message: message)
            viewModel.clearAppleSignInNotice()
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
        .alert("Apple 로그인 실패", isPresented: Binding(get: {
            viewModel.appleSignInErrorMessage != nil
        }, set: { _ in
            viewModel.clearAppleSignInError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.appleSignInErrorMessage ?? "Apple 로그인에 실패했어요.")
        }
        .sheet(isPresented: $isGuidePresented) {
            GuideView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("저장") {
                    handleSaveButtonTap()
                }
                .disabled(viewModel.isSavingProfile)

                Button("완료") {
                    dismissKeyboard()
                }
            }
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            formContent
                .navigationTitle("프로필")
        }
    }

    private var formContent: some View {
        Form {
            if viewModel.hasAuthenticatedSession {
                loggedInContent
            } else {
                guestContent
            }
            appearanceSection
            notificationSettingsSection
            helpSection
            appInfoSection
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var toastOverlay: some View {
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

            ProfileInputField(
                title: "닉네임",
                prompt: "닉네임을 입력해 주세요",
                text: $viewModel.nicknameDraft,
                focusedField: $focusedField,
                field: .nickname
            )

            ProfileInputField(
                title: "한 줄 소개",
                prompt: "매일 한 문장씩 일본어 연습 중",
                text: $viewModel.bioDraft,
                axis: .vertical,
                focusedField: $focusedField,
                field: .bio
            )

            ProfileInputField(
                title: "인스타 아이디",
                prompt: "@haru_jp",
                text: $viewModel.instagramIdDraft,
                keyboardType: .asciiCapable,
                focusedField: $focusedField,
                field: .instagramId
            )

            VStack(spacing: 8) {
                Button {
                    handleSaveButtonTap()
                } label: {
                    HStack {
                        if viewModel.isSavingProfile {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.secondary)
                        }
                        Text(viewModel.isSavingProfile ? "저장 중..." : "저장")
                            .fontWeight(.semibold)
                            .font(.system(size: 15))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(viewModel.hasProfileDraftChanges ? Color.blue : Color.gray)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingProfile || viewModel.canSaveProfile == false)
                .opacity(viewModel.isSavingProfile ? 0.6 : 1.0)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)

            if viewModel.isSavingProfile {
                Text("프로필 저장 중...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let profileSaveErrorMessage = viewModel.profileSaveErrorMessage {
                Text(profileSaveErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isRefreshingServerProfile {
                ProgressView("프로필 동기화 중...")
                    .font(.footnote)
            }

            if let profileRefreshErrorMessage = viewModel.profileRefreshErrorMessage {
                Text(profileRefreshErrorMessage)
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
                AppleSignInButton(isLoading: viewModel.isSigningInWithApple) {
                    viewModel.signInWithApple()
                }
                if viewModel.isSigningInWithApple {
                    ProgressView("로그인 처리 중...")
                        .font(.footnote)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var accountSection: some View {
        Section("계정") {
            HStack {
                Text("로그인 상태")
                Spacer()
                if viewModel.serverUserIdPrefix.isEmpty == false {
                    Text("server \(viewModel.serverUserIdPrefix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Apple 로그인됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.hasResolvedServerSession {
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

            if let serverUserId = viewModel.currentServerUserId {
                HStack {
                    Text("서버 사용자 ID")
                    Spacer()
                    Text(serverUserId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .disabled(viewModel.hasResolvedServerSession == false || viewModel.isUpdatingLearningLevel)

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
            imageURLString: viewModel.avatarImageURLForDisplay,
            size: size
        )
        .background(Color.black.opacity(0.04))
    }

    private func dismissKeyboard() {
        print("[ProfileEdit] dismiss keyboard")
        guard focusedField != nil else { return }
        focusedField = nil
    }

    private func handleSaveButtonTap() {
        print("[ProfileEdit] save button tapped")
        let hadFocus = focusedField != nil
        dismissKeyboard()
        print("[ProfileEdit] save tapped focus cleared=\(hadFocus)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            viewModel.saveProfileEdits()
        }
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

private struct ProfileInputField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var keyboardType: UIKeyboardType = .default
    var focusedField: FocusState<ProfileEditField?>.Binding
    var field: ProfileEditField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "",
                text: $text,
                prompt: Text(prompt).foregroundStyle(.tertiary),
                axis: axis
            )
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .lineLimit(axis == .vertical ? 3 : 1)
            .focused(focusedField, equals: field)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 2)
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

struct AppleSignInButton: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        SignInWithAppleButtonRepresentable(onTap: onTap)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Apple로 로그인")
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)
    }
}

private struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        let onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func didTapButton() {
            onTap()
        }
    }
}
