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
    @State private var isTimeRangeSheetPresented: Bool = false
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var errorMessage: String?
    @State private var isEditingProfile: Bool = false
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
            guard newItem != nil else { return }
            print("[ProfileImage] item selected")
            Task {
                await viewModel.loadAvatar(from: newItem)
                viewModel.selectedPhotoItem = nil
            }
        }
        .onChange(of: focusedField) { field in
            print("[ProfileEdit] focus changed field=\(field?.rawValue ?? "nil")")
        }
        .onChange(of: viewModel.profileSaveSuccessMessage) { message in
            guard let message else { return }
            isEditingProfile = false
            dismissKeyboard()
            showToast(message: message)
            viewModel.profileSaveSuccessMessage = nil
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
        .onChange(of: viewModel.petalNotificationNotice) { message in
            guard let message else { return }
            showToast(message: message)
            viewModel.clearPetalNotificationNotice()
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
        .alert("꽃잎 알림 설정 실패", isPresented: Binding(get: {
            viewModel.petalNotificationErrorMessage != nil
        }, set: { _ in
            viewModel.clearPetalNotificationError()
        })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.petalNotificationErrorMessage ?? "꽃잎 알림 설정을 변경하지 못했어요.")
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
        .sheet(isPresented: $isTimeRangeSheetPresented) {
            LearningNotificationRangeSheet(
                startTime: viewModel.learningNotificationSettings.isRepeating
                    ? viewModel.learningNotificationSettings.repeatStartTime
                    : viewModel.learningNotificationSettings.notificationTime,
                endTime: viewModel.learningNotificationSettings.repeatEndTime,
                isRepeating: viewModel.learningNotificationSettings.isRepeating,
                selectedInterval: viewModel.learningNotificationSettings.repeatInterval,
                onApply: { start, end, interval in
                    if viewModel.learningNotificationSettings.isRepeating {
                        viewModel.updateLearningNotificationRange(start: start, end: end, interval: interval)
                    } else {
                        viewModel.updateLearningNotificationTime(start)
                    }
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
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
            if isEditingProfile {
                ProfileEditCardView(
                    nickname: $viewModel.nicknameDraft,
                    bio: $viewModel.bioDraft,
                    instagramId: $viewModel.instagramIdDraft,
                    isSaving: viewModel.isSavingProfile,
                    canSave: viewModel.canSaveProfile,
                    focusedField: $focusedField,
                    onSave: handleSaveButtonTap,
                    onCancel: cancelProfileEditing
                )
            } else {
                ProfileSummaryCardView(
                    nickname: profileSummaryNickname,
                    bio: profileSummaryBio,
                    instagramId: profileSummaryInstagram,
                    learningLevelTitle: viewModel.selectedLearningLevel.title,
                    avatarView: {
                        PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                            avatarView
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissKeyboard()
                                print("[ProfileImage] picker opened")
                            }
                        )
                    },
                    onEdit: beginProfileEditing
                )
            }

            if let profileSaveErrorMessage = viewModel.profileSaveErrorMessage {
                Text(profileSaveErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
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
            if viewModel.hasResolvedServerSession {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { viewModel.isRandomMatchingEnabled },
                        set: { viewModel.updateRandomMatchingEnabled($0) }
                    )) {
                        Text("랜덤 매칭 노출하기")
                    }
                    .disabled(viewModel.isUpdatingRandomMatching)

                    if viewModel.isUpdatingRandomMatching {
                        ProgressView("설정 저장 중...")
                            .font(.footnote)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(role: .destructive) {
                viewModel.signOutForMate()
            } label: {
                Text("로그아웃")
            }
            .padding(.vertical, viewModel.hasResolvedServerSession ? 2 : 4)
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
                                isSelected: viewModel.selectedLearningLevel == level,
                                isSaving: viewModel.isUpdatingLearningLevel && viewModel.selectedLearningLevel == level
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

            if viewModel.isLearningNotificationEnabled {
                Toggle(isOn: Binding(
                    get: { viewModel.learningNotificationSettings.isRepeating },
                    set: { viewModel.updateLearningNotificationRepeating($0) }
                )) {
                    Text("반복 알림")
                }
                .disabled(viewModel.isUpdatingLearningNotification)

                Button {
                    isTimeRangeSheetPresented = true
                } label: {
                    HStack {
                        Text("알림 시간")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.learningNotificationSummaryText)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdatingLearningNotification)

                if viewModel.learningNotificationAuthorizationStatus == .denied {
                    Text("알림 권한이 꺼져 있어요. 설정 앱에서 알림을 허용해 주세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: Binding(
                get: { viewModel.isPetalNotificationEnabled },
                set: { viewModel.updatePetalNotificationEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("꽃잎 알림 받기")
                    Text("버디가 꽃잎을 보내면 알림으로 받아요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.isUpdatingPetalNotification)

            if viewModel.isUpdatingPetalNotification {
                ProgressView("꽃잎 알림 설정 중...")
                    .font(.footnote)
            }

            if viewModel.isPetalNotificationEnabled,
               viewModel.learningNotificationAuthorizationStatus == .denied {
                Text("알림 권한이 꺼져 있어요. 설정 앱에서 알림을 허용해 주세요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

    private var profileSummaryNickname: String {
        let nickname = viewModel.currentProfile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? "하루" : nickname
    }

    private var profileSummaryBio: String? {
        let bio = viewModel.currentProfile.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return bio.isEmpty ? nil : bio
    }

    private var profileSummaryInstagram: String? {
        let instagram = viewModel.currentProfile.instagramId.trimmingCharacters(in: .whitespacesAndNewlines)
        return instagram.isEmpty ? nil : instagram
    }

    private func beginProfileEditing() {
        viewModel.nicknameDraft = viewModel.currentProfile.nickname
        viewModel.bioDraft = viewModel.currentProfile.bio
        viewModel.instagramIdDraft = viewModel.currentProfile.instagramId
        viewModel.clearProfileSaveError()
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingProfile = true
        }
    }

    private func cancelProfileEditing() {
        dismissKeyboard()
        viewModel.nicknameDraft = viewModel.currentProfile.nickname
        viewModel.bioDraft = viewModel.currentProfile.bio
        viewModel.instagramIdDraft = viewModel.currentProfile.instagramId
        viewModel.clearProfileSaveError()
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingProfile = false
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

private struct LearningNotificationRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedInterval: LearningNotificationSettings.RepeatInterval?
    let isRepeating: Bool
    let onApply: (Date, Date, LearningNotificationSettings.RepeatInterval?) -> Void

    init(
        startTime: Date,
        endTime: Date,
        isRepeating: Bool,
        selectedInterval: LearningNotificationSettings.RepeatInterval,
        onApply: @escaping (Date, Date, LearningNotificationSettings.RepeatInterval?) -> Void
    ) {
        _startTime = State(initialValue: startTime)
        _endTime = State(initialValue: endTime)
        _selectedInterval = State(initialValue: selectedInterval)
        self.isRepeating = isRepeating
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("시작 시간", selection: $startTime, displayedComponents: .hourAndMinute)

                if isRepeating {
                    DatePicker("종료 시간", selection: $endTime, displayedComponents: .hourAndMinute)

                    Picker("반복 간격", selection: Binding(
                        get: { selectedInterval },
                        set: { selectedInterval = $0 }
                    )) {
                        ForEach(availableIntervals) { interval in
                            Text(interval.title).tag(Optional(interval))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(availableIntervals.isEmpty)

                    if availableIntervals.isEmpty {
                        Text("시간 범위를 더 넓혀야 반복 간격을 선택할 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("알림 시간")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("적용") {
                        onApply(startTime, endTime, selectedInterval)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedInterval = resolvedInterval(for: selectedInterval)
        }
        .onChange(of: startTime) { _ in
            selectedInterval = resolvedInterval(for: selectedInterval)
        }
        .onChange(of: endTime) { _ in
            selectedInterval = resolvedInterval(for: selectedInterval)
        }
    }

    private var availableIntervals: [LearningNotificationSettings.RepeatInterval] {
        LearningNotificationSettings.availableRepeatIntervals(
            startMinutes: LearningNotificationSettings.minutes(from: startTime),
            endMinutes: LearningNotificationSettings.minutes(from: endTime)
        )
    }

    private func resolvedInterval(
        for current: LearningNotificationSettings.RepeatInterval?
    ) -> LearningNotificationSettings.RepeatInterval? {
        if let current, availableIntervals.contains(current) {
            return current
        }
        return LearningNotificationSettings.preferredInterval(from: availableIntervals)
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
                .foregroundStyle(Color.textSecondary)

            TextField(
                "",
                text: $text,
                prompt: Text(prompt).foregroundStyle(Color.textTertiary),
                axis: axis
            )
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .lineLimit(axis == .vertical ? 3 : 1)
            .focused(focusedField, equals: field)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(Color.textPrimary)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.divider, lineWidth: 1)
            )
        }
        .padding(.vertical, 2)
    }
}

private struct LevelSelectionChip: View {
    let level: JLPTLevel
    let isSelected: Bool
    let isSaving: Bool
    let onTap: () -> Void

    var body: some View {
        let trailingAccessoryWidth: CGFloat = 18
        Button(action: onTap) {
            Text(level.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .padding(.trailing, isSelected ? trailingAccessoryWidth : 0)
                .background(isSelected ? Color.chipActive : Color.surfaceSecondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.chipActive : Color.divider, lineWidth: 1)
                )
                .clipShape(Capsule())
                .overlay(alignment: .trailing) {
                    if isSelected {
                        ZStack {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .opacity(isSaving ? 0 : 1)

                            if isSaving {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            }
                        }
                        .frame(width: trailingAccessoryWidth, alignment: .center)
                        .padding(.trailing, 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.title) 레벨")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct ProfileSummaryCardView<AvatarContent: View>: View {
    let nickname: String
    let bio: String?
    let instagramId: String?
    let learningLevelTitle: String
    @ViewBuilder let avatarView: () -> AvatarContent
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                avatarView()

                VStack(alignment: .leading, spacing: 6) {
                    Text(nickname)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let bio {
                        Text(bio)
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Text(learningLevelTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.surfaceSecondary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.divider, lineWidth: 1))

                        if let instagramId {
                            Label("@\(instagramId)", systemImage: "camera")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button("수정", action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chipActive)
            }
        }
        .padding(14)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.divider, lineWidth: 1)
        )
    }
}

private struct ProfileEditCardView: View {
    @Binding var nickname: String
    @Binding var bio: String
    @Binding var instagramId: String
    let isSaving: Bool
    let canSave: Bool
    var focusedField: FocusState<ProfileEditField?>.Binding
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("프로필 수정")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            ProfileInputField(
                title: "닉네임",
                prompt: "닉네임을 입력해 주세요",
                text: $nickname,
                focusedField: focusedField,
                field: .nickname
            )

            ProfileInputField(
                title: "한 줄 소개",
                prompt: "매일 한 문장씩 일본어 연습 중",
                text: $bio,
                axis: .vertical,
                focusedField: focusedField,
                field: .bio
            )

            ProfileInputField(
                title: "인스타 아이디",
                prompt: "@haru_jp",
                text: $instagramId,
                keyboardType: .asciiCapable,
                focusedField: focusedField,
                field: .instagramId
            )

            HStack(spacing: 10) {
                Button("취소", action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.surfaceSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.divider, lineWidth: 1))

                Button(action: onSave) {
                    ZStack {
                        Text("저장")
                            .font(.subheadline.weight(.semibold))
                            .opacity(isSaving ? 0 : 1)

                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(canSave || isSaving ? Color.chipActive : Color.textTertiary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(canSave == false && isSaving == false)
                .opacity(isSaving || canSave ? 1 : 0.65)
            }
        }
        .padding(14)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.divider, lineWidth: 1)
        )
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
