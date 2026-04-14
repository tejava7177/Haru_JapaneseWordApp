import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let repository: DictionaryRepository
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var wordListViewModel: WordListViewModel
    @StateObject private var mateViewModel: MateViewModel
    @StateObject private var appActivePingManager: AppActivePingManager
    @State private var selectedTab: RootTab = .home
    @State private var lastScenePhase: ScenePhase?

    enum RootTab: Hashable {
        case home
        case words
        case mate
        case profile
    }

    init(repository: DictionaryRepository) {
        self.repository = repository
        AppTheme.configureTabBarAppearance()
        let settingsStore = AppSettingsStore()
        ReviewWordStore.shared.configure(settingsStore: settingsStore)
        NotebookStore.shared.configure(settingsStore: settingsStore)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _mateViewModel = StateObject(wrappedValue: MateViewModel(settingsStore: settingsStore))
        _appActivePingManager = StateObject(wrappedValue: AppActivePingManager(settingsStore: settingsStore))

        _wordListViewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if settingsStore.hasSeenOnboarding {
                mainTabView
            } else {
                OnboardingView(isBuddyEnabled: settingsStore.hasResolvedServerSession) {
                    selectedTab = .home
                    settingsStore.markOnboardingSeen()
                }
            }
        }
        .preferredColorScheme(settingsStore.isDarkModeEnabled ? .dark : .light)
        .task {
            PushRegistrationManager.shared.configure(settingsStore: settingsStore)
            await NotificationManager.shared.syncDailyLearningReminder(
                isEnabled: settingsStore.settings.isLearningNotificationEnabled
            )
            await PushRegistrationManager.shared.syncRegistrationState()
        }
        .onChange(of: settingsStore.serverUserId) { _, _ in
            Task {
                await PushRegistrationManager.shared.syncRegistrationState()
            }
        }
        .onAppear {
            lastScenePhase = scenePhase
        }
        .onChange(of: scenePhase) { _, newPhase in
            defer { lastScenePhase = newPhase }

            guard newPhase == .active, lastScenePhase != .active else { return }
            appActivePingManager.sendActivePingIfNeeded(source: "scenePhase.active")
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(repository: repository, settingsStore: settingsStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(RootTab.home)

            WordListView(repository: repository, viewModel: wordListViewModel, settingsStore: settingsStore)
                .tabItem {
                    Label("Words", systemImage: "book")
                }
                .tag(RootTab.words)

            Group {
                if settingsStore.hasResolvedServerSession {
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
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(RootTab.profile)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .wordListRequiresLoginNavigation)) { _ in
            selectedTab = .profile
        }
    }
}

extension Notification.Name {
    static let wordListRequiresLoginNavigation = Notification.Name("wordListRequiresLoginNavigation")
}

#Preview {
    RootView(repository: StubDictionaryRepository())
}
