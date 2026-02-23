import SwiftUI
import UserNotifications

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
    @StateObject private var deepLinkRouter = DeepLinkRouter()

    init() {
        do {
            repository = try SQLiteDictionaryRepository()
        } catch {
            print("❌ Repository init failed: \(error)")
            repository = ErrorDictionaryRepository(error: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository, deepLinkRouter: deepLinkRouter)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = deepLinkRouter
                }
        }
    }
}
