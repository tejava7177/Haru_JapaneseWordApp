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
        _deepLinkRouter = ObservedObject(wrappedValue: deepLinkRouter)

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
            notifier: LocalNotificationPokeNotifier(),
            appUserIdProvider: { settingsStore.appUserId }
        )

        _mateViewModel = StateObject(
            wrappedValue: MateViewModel(mateService: mateService, settingsStore: settingsStore)
        )
        _wordListViewModel = StateObject(
            wrappedValue: WordListViewModel(repository: repository, mateService: mateService)
        )
    }

    var body: some View {
        contentRoot
            .onAppear {
                print("[RootView] onAppear")
                print("[RootView] hasSeenOnboarding=\(settingsStore.hasSeenOnboarding) isSignedIn=\(settingsStore.isSignedIn)")
                syncOnboardingPresentation()
                print("[RootView] isShowingOnboarding(after sync)=\(isShowingOnboarding)")
            }
            .onChange(of: settingsStore.hasSeenOnboarding) { _ in
                syncOnboardingPresentation()
            }
            .onChange(of: isShowingOnboarding) { value in
                print("[RootView] isShowingOnboarding -> \(value)")
            }
            .onReceive(deepLinkRouter.$pendingWordId) { _ in
                if let wordId = deepLinkRouter.consumeWordId() {
                    deepLinkWordId = WordLink(id: wordId)
                }
            }
            .sheet(item: $deepLinkWordId) { link in
                WordDetailView(
                    wordId: link.id,
                    repository: repository,
                    mateService: mateViewModel.mateService
                )
            }
            .fullScreenCover(isPresented: $isShowingOnboarding) {
                ZStack {
                    Color.green.ignoresSafeArea()
                    Text("COVER IS SHOWING")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
    }

    // MARK: - Root content (always visible)

    private var contentRoot: some View {
        ZStack(alignment: .top) {
            Color(white: 0.95).ignoresSafeArea()

            contentView

            debugOverlay
        }
    }

    private var debugOverlay: some View {
        VStack(spacing: 6) {
            Text("ROOTVIEW LIVE")
                .font(.caption).bold()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)

            Text("hasSeenOnboarding=\(settingsStore.hasSeenOnboarding ? "true" : "false")  isSignedIn=\(settingsStore.isSignedIn ? "true" : "false")")
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.top, 12)
        .zIndex(999)
    }

    // MARK: - Main branching view

    @ViewBuilder
    private var contentView: some View {
        if settingsStore.hasSeenOnboarding == false {
            VStack(spacing: 12) {
                ProgressView()
                Text("온보딩 준비 중…")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if settingsStore.isSignedIn == false {
            SignInRequiredView(settingsStore: settingsStore)
                .overlay(
                    Text("SIGN-IN VIEW")
                        .font(.caption).bold()
                        .padding(8)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(),
                    alignment: .bottom
                )
        } else {
            ZStack {
                TabView(selection: $selectedTab) {
                    HomeView(
                        repository: repository,
                        settingsStore: settingsStore,
                        mateViewModel: mateViewModel,
                        onRequestMate: { selectedTab = .mate }
                    )
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(RootTab.home)

                    WordListView(
                        repository: repository,
                        viewModel: wordListViewModel,
                        mateService: mateViewModel.mateService
                    )
                    .tabItem { Label("Words", systemImage: "book") }
                    .tag(RootTab.words)

                    MateView(viewModel: mateViewModel)
                        .tabItem { Label("Mate", systemImage: "person.2") }
                        .tag(RootTab.mate)

                    ProfileView(settingsStore: settingsStore)
                        .tabItem { Label("프로필", systemImage: "person.circle") }
                        .tag(RootTab.profile)
                }

                if repository is ErrorDictionaryRepository {
                    VStack(spacing: 12) {
                        Text("데이터 초기화에 실패했어요")
                            .font(.headline)
                        Text("앱을 다시 실행해도 동일하면, 시뮬레이터 앱 삭제 후 재설치로 DB를 초기화해보세요.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - Helpers

    private func syncOnboardingPresentation() {
        // 온보딩을 아직 안 봤으면 무조건 cover가 떠야 함
        isShowingOnboarding = (settingsStore.hasSeenOnboarding == false)
    }
}

private struct WordLink: Identifiable {
    let id: Int
}

#Preview {
    RootView(repository: StubDictionaryRepository(), deepLinkRouter: DeepLinkRouter())
}
