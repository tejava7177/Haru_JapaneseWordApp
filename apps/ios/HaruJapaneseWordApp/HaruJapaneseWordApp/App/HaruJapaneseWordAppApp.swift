import SwiftUI

private struct DictionaryRepositoryKey: EnvironmentKey {
    static let defaultValue: DictionaryRepository = StubDictionaryRepository()
}

extension EnvironmentValues {
    var dictionaryRepository: DictionaryRepository {
        get { self[DictionaryRepositoryKey.self] }
        set { self[DictionaryRepositoryKey.self] = newValue }
    }
}

@main
struct HaruJapaneseWordAppApp: App {
    private let repository: DictionaryRepository

    init() {
        repository = (try? SQLiteDictionaryRepository()) ?? StubDictionaryRepository()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dictionaryRepository, repository)
        }
    }
}
