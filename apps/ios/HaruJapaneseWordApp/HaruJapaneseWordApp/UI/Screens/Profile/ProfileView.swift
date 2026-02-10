import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isGuidePresented: Bool = false
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""

    private let levelOptions: [JLPTLevel] = [.n5, .n4, .n3, .n2, .n1]

    init(settingsStore: AppSettingsStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                            avatarView
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.profile.nickname.isEmpty ? "하루" : viewModel.profile.nickname)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("프로필을 설정해 보세요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("프로필") {
                    TextField(
                        "닉네임",
                        text: Binding(
                            get: { viewModel.profile.nickname },
                            set: { viewModel.updateNickname($0) }
                        )
                    )

                    TextField(
                        "한 줄 소개",
                        text: Binding(
                            get: { viewModel.profile.bio },
                            set: { viewModel.updateBio($0) }
                        )
                    )

                    HStack {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField(
                            "인스타 아이디",
                            text: Binding(
                                get: { viewModel.profile.instagramId },
                                set: { viewModel.updateInstagram($0) }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }

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

                Section("도움말") {
                    Button {
                        isGuidePresented = true
                    } label: {
                        Text("사용 가이드")
                    }
                }

                Section("데이터") {
                    Button(role: .destructive) {
                        viewModel.isResetAlertPresented = true
                    } label: {
                        Text("학습 데이터 초기화")
                    }
                }
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
