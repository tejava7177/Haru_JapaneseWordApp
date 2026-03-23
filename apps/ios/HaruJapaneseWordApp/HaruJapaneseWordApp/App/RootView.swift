import SwiftUI

struct RootView: View {
    private let repository: DictionaryRepository
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var wordListViewModel: WordListViewModel
    @StateObject private var mateViewModel: MateViewModel
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
        _mateViewModel = StateObject(wrappedValue: MateViewModel(settingsStore: settingsStore))

        _wordListViewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if settingsStore.hasSeenOnboarding {
                mainTabView
            } else {
                OnboardingView(isBuddyEnabled: settingsStore.isMateLoggedIn) {
                    selectedTab = .home
                    settingsStore.markOnboardingSeen()
                }
            }
        }
    }

    private var mainTabView: some View {
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
    }
}

#Preview {
    RootView(repository: StubDictionaryRepository())
}
