import SwiftUI

struct RootView: View {
    private let repository: DictionaryRepository
    @StateObject private var settingsStore = AppSettingsStore()
    @StateObject private var wordListViewModel: WordListViewModel
    @State private var isShowingOnboarding: Bool = false

    init(repository: DictionaryRepository) {
        self.repository = repository
        _wordListViewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        TabView {
            HomeView(repository: repository, settingsStore: settingsStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            WordListView(repository: repository, viewModel: wordListViewModel)
                .tabItem {
                    Label("Words", systemImage: "book")
                }

            Text("Mate")
                .tabItem {
                    Label("Mate", systemImage: "person.2")
                }

            ProfileView(settingsStore: settingsStore)
                .tabItem {
                    Label("프로필", systemImage: "person.circle")
                }
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
