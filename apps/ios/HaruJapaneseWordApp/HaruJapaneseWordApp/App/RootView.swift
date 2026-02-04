import SwiftUI

struct RootView: View {
    @Environment(\.dictionaryRepository) private var repository
    @StateObject private var settingsStore = AppSettingsStore()

    var body: some View {
        TabView {
            HomeView(repository: repository, settingsStore: settingsStore)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            WordListView(repository: repository)
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
    }
}

#Preview {
    RootView()
        .environment(\.dictionaryRepository, StubDictionaryRepository())
}
