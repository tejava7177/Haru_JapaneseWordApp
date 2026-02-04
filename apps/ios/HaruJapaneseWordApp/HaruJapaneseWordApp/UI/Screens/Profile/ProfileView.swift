import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isGuidePresented: Bool = false

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
                    Picker(
                        "덱 레벨",
                        selection: Binding(
                            get: { viewModel.settings.homeDeckLevel },
                            set: { viewModel.updateHomeDeckLevel($0) }
                        )
                    ) {
                        Text("N5").tag(JLPTLevel.n5)
                        Text("N4").tag(JLPTLevel.n4)
                    }
                    .pickerStyle(.segmented)

                    Text("덱 레벨 변경은 다음 날부터 적용돼요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker(
                        "제외 기간",
                        selection: Binding(
                            get: { viewModel.settings.excludeDays },
                            set: { viewModel.updateExcludeDays($0) }
                        )
                    ) {
                        Text("7일").tag(7)
                        Text("14일").tag(14)
                        Text("30일").tag(30)
                    }
                    .pickerStyle(.segmented)
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
}

#Preview {
    ProfileView(settingsStore: AppSettingsStore())
}
