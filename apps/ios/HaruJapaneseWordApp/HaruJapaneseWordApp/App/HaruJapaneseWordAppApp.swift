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
    @StateObject private var deepLinkRouter: DeepLinkRouter

    init() {
        let router = DeepLinkRouter()
        _deepLinkRouter = StateObject(wrappedValue: router)
        UNUserNotificationCenter.current().delegate = router

        do {
            repository = try SQLiteDictionaryRepository()
        } catch {
            print("❌ Repository init failed: \(error)")
            repository = ErrorDictionaryRepository(error: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.green.ignoresSafeArea()
                Text("APP ENTRY OK")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
