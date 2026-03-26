import SwiftUI
import UIKit

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
    @UIApplicationDelegateAdaptor(HaruAppDelegate.self) private var appDelegate
    private let repository: DictionaryRepository

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
            RootView(repository: repository)
        }
    }
}
