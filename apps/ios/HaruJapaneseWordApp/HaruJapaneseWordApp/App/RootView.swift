import SwiftUI

struct RootView: View {
    @Environment(\.dictionaryRepository) private var repository

    var body: some View {
        TabView {
            Text("Home")
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

            Text("Record")
                .tabItem {
                    Label("Record", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    RootView()
        .environment(\.dictionaryRepository, StubDictionaryRepository())
}
