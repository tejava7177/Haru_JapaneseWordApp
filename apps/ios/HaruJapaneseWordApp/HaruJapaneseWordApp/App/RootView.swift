import SwiftUI

struct RootView: View {
    private let repository: DictionaryRepository
    @ObservedObject private var deepLinkRouter: DeepLinkRouter
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var mateViewModel: MateViewModel
    @StateObject private var wordListViewModel: WordListViewModel
    @State private var isShowingOnboarding: Bool = false
    @State private var selectedTab: RootTab = .home
    @State private var deepLinkWordId: WordLink?

    enum RootTab: Hashable {
        case home
        case words
        case mate
        case profile
    }

    init(repository: DictionaryRepository, deepLinkRouter: DeepLinkRouter) {
        self.repository = repository
        self.deepLinkRouter = deepLinkRouter
        let settingsStore = AppSettingsStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)

        let mateRepository: MateRepositoryProtocol
        do {
            mateRepository = try SQLiteMateRepository()
        } catch {
            mateRepository = StubMateRepository()
        }
        let mateService = MateService(
            repository: mateRepository,
            dictionaryRepository: repository,
            notifier: LocalNotificationPokeNotifier()
        )
        _mateViewModel = StateObject(wrappedValue: MateViewModel(mateService: mateService, settingsStore: settingsStore))
        _wordListViewModel = StateObject(wrappedValue: WordListViewModel(repository: repository, mateService: mateService))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                repository: repository,
                settingsStore: settingsStore,
                mateViewModel: mateViewModel,
                onRequestMate: { selectedTab = .mate }
            )
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(RootTab.home)

            WordListView(repository: repository, viewModel: wordListViewModel, mateService: mateViewModel.mateService)
                .tabItem {
                    Label("Words", systemImage: "book")
                }
                .tag(RootTab.words)

            MateView(viewModel: mateViewModel)
                .tabItem {
                    Label("Mate", systemImage: "person.2")
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
        .onReceive(deepLinkRouter.$pendingWordId) { _ in
            if let wordId = deepLinkRouter.consumeWordId() {
                deepLinkWordId = WordLink(id: wordId)
            }
        }
        .sheet(item: $deepLinkWordId) { link in
            WordDetailView(wordId: link.id, repository: repository, mateService: mateViewModel.mateService)
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingView {
                settingsStore.markOnboardingSeen()
                isShowingOnboarding = false
            }
        }
    }
}

private struct WordLink: Identifiable {
    let id: Int
}

#Preview {
    RootView(repository: StubDictionaryRepository(), deepLinkRouter: DeepLinkRouter())
}
