import SwiftUI

struct RootView: View {
    private let repository: DictionaryRepository
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var wordListViewModel: WordListViewModel
    @StateObject private var mateViewModel: MateViewModel
    @State private var isShowingOnboarding: Bool = false
    @State private var selectedTab: RootTab = .home

    enum RootTab: Hashable {
        case home
        case words
        case mate
        case profile
    }

    init(repository: DictionaryRepository) {
        self.repository = repository
        let settingsStore = AppSettingsStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)

        let mateRepository = SQLiteMateRepository()
        let mateService = MateService(repository: mateRepository, appUserIdProvider: { settingsStore.mateUserId })
        _mateViewModel = StateObject(wrappedValue: MateViewModel(service: mateService, settingsStore: settingsStore))

        _wordListViewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(repository: repository, settingsStore: settingsStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(RootTab.home)

            WordListView(repository: repository, viewModel: wordListViewModel)
                .tabItem {
                    Label("Words", systemImage: "book")
                }
                .tag(RootTab.words)

            Group {
                if settingsStore.isMateLoggedIn {
                    MateView(viewModel: mateViewModel)
                } else {
                    MateSignInRequiredView {
                        selectedTab = .profile
                    }
                }
            }
            .tabItem {
                Label("Buddy", systemImage: "person.2")
            }
            .tag(RootTab.mate)

            ProfileView(settingsStore: settingsStore)
                .tabItem {
                    Label("프로필", systemImage: "person.circle")
                }
                .tag(RootTab.profile)
        }
        .onAppear {
            if settingsStore.hasSeenOnboarding == false {
                isShowingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingView {
                settingsStore.markOnboardingSeen()
                isShowingOnboarding = false
            }
        }
    }
}

#Preview {
    RootView(repository: StubDictionaryRepository())
}
