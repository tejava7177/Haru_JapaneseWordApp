import Foundation
import Combine
import UIKit

@MainActor
final class ReviewWordStore: ObservableObject {
    static let shared = ReviewWordStore()

    @Published private(set) var reviewWordIds: Set<Int>

    private let userDefaults: UserDefaults
    private let apiService: ReviewWordAPIServiceProtocol
    private let reviewWordsKey = "review_words"
    private let cachedReviewWordsKeyPrefix = "review_words_cached_user_"
    private let migrationKeyPrefix = "review_words_migrated_user_"
    private weak var settingsStore: AppSettingsStore?
    private var cancellables: Set<AnyCancellable> = []
    private var currentServerUserId: String?
    private var currentSyncTask: Task<Void, Never>?
    private var inFlightWordOperations: Set<Int> = []

    init(
        userDefaults: UserDefaults = .standard,
        apiService: ReviewWordAPIServiceProtocol = ReviewWordAPIService()
    ) {
        self.userDefaults = userDefaults
        self.apiService = apiService
        self.reviewWordIds = Set(userDefaults.array(forKey: reviewWordsKey) as? [Int] ?? [])
    }

    func loadReviewSet() -> Set<Int> {
        let loaded: Set<Int>
        if let currentServerUserId,
           let cachedSet = loadCachedReviewSet(for: currentServerUserId) {
            loaded = cachedSet
        } else {
            loaded = loadLegacyLocalReviewSet()
        }

        if loaded != reviewWordIds {
            reviewWordIds = loaded
        }
        return loaded
    }

    func contains(_ wordId: Int) -> Bool {
        reviewWordIds.contains(wordId)
    }

    func add(_ wordId: Int) {
        Task {
            await addReviewWord(wordId)
        }
    }

    func remove(_ wordId: Int) {
        Task {
            await removeReviewWord(wordId)
        }
    }

    func toggle(_ wordId: Int) {
        if contains(wordId) {
            remove(wordId)
        } else {
            add(wordId)
        }
    }

    func saveReviewSet(_ ids: Set<Int>) {
        reviewWordIds = ids
        userDefaults.set(Array(ids), forKey: reviewWordsKey)
    }

    func configure(settingsStore: AppSettingsStore) {
        guard self.settingsStore !== settingsStore else { return }

        self.settingsStore = settingsStore
        cancellables.removeAll()

        settingsStore.$serverUserId
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                self?.scheduleSessionSync(for: userId, triggerSource: "serverUserIdChanged")
            }
            .store(in: &cancellables)

        scheduleSessionSync(for: settingsStore.currentBackendUserId, triggerSource: "configure")
    }

    private func scheduleSessionSync(for userId: String?, triggerSource: String) {
        currentSyncTask?.cancel()
        currentSyncTask = Task { [weak self] in
            await self?.syncForCurrentSession(userId: userId, triggerSource: triggerSource)
        }
    }

    private func syncForCurrentSession(userId: String?, triggerSource: String) async {
        let normalizedUserId = normalizedUserId(userId)
        currentServerUserId = normalizedUserId

        if let normalizedUserId {
            await syncFromServer(userId: normalizedUserId, triggerSource: triggerSource)
        } else {
            let localIds = loadLegacyLocalReviewSet()
            print("[ReviewWordStore] review fetch skipped reason=noLoggedInUser trigger=\(triggerSource)")
            applyReviewWordIds(localIds, persistLegacyCache: true, cachedUserId: nil)
        }
    }

    private func syncFromServer(userId: String, triggerSource: String) async {
        print("[ReviewWordStore] review fetch start userId=\(userId) trigger=\(triggerSource)")

        do {
            var fetchedIds = try await apiService.fetchReviewWords(userId: userId)
            print("[ReviewWordStore] review fetch success userId=\(userId) count=\(fetchedIds.count)")

            let localIds = loadLegacyLocalReviewSet()
            let hasMigrated = hasCompletedMigration(for: userId)

            if fetchedIds.isEmpty == false {
                if hasMigrated == false {
                    markMigrationCompleted(for: userId)
                }
                print("[ReviewWordStore] review migration skipped userId=\(userId) reason=serverNotEmpty")
            } else if localIds.isEmpty {
                print("[ReviewWordStore] review migration skipped userId=\(userId) reason=localEmpty")
            } else if hasMigrated {
                print("[ReviewWordStore] review migration skipped userId=\(userId) reason=alreadyMigrated")
            } else {
                print("[ReviewWordStore] review migration start userId=\(userId) count=\(localIds.count)")
                try await apiService.migrateReviewWords(userId: userId, wordIds: Array(localIds))
                markMigrationCompleted(for: userId)
                print("[ReviewWordStore] review migration success userId=\(userId) count=\(localIds.count)")

                print("[ReviewWordStore] review fetch start userId=\(userId) trigger=postMigration")
                fetchedIds = try await apiService.fetchReviewWords(userId: userId)
                print("[ReviewWordStore] review fetch success userId=\(userId) count=\(fetchedIds.count)")
            }

            guard Task.isCancelled == false else { return }
            applyReviewWordIds(fetchedIds, persistLegacyCache: true, cachedUserId: userId)
        } catch {
            print("[ReviewWordStore] review fetch failed userId=\(userId) error=\(error.localizedDescription)")

            let fallbackIds = loadCachedReviewSet(for: userId) ?? loadLegacyLocalReviewSet()
            applyReviewWordIds(fallbackIds, persistLegacyCache: true, cachedUserId: userId)
        }
    }

    private func addReviewWord(_ wordId: Int) async {
        guard inFlightWordOperations.contains(wordId) == false else { return }
        inFlightWordOperations.insert(wordId)
        defer { inFlightWordOperations.remove(wordId) }

        if let userId = currentServerUserId {
            print("[ReviewWordStore] review add start userId=\(userId) wordId=\(wordId)")
            do {
                try await apiService.addReviewWord(userId: userId, wordId: wordId)
                var nextIds = reviewWordIds
                nextIds.insert(wordId)
                applyReviewWordIds(nextIds, persistLegacyCache: true, cachedUserId: userId)
                print("[ReviewWordStore] review add success userId=\(userId) wordId=\(wordId)")
                notifySuccessFeedback()
            } catch {
                print("[ReviewWordStore] review add failed userId=\(userId) wordId=\(wordId) error=\(error.localizedDescription)")
            }
            return
        }

        var nextIds = loadLegacyLocalReviewSet()
        nextIds.insert(wordId)
        applyReviewWordIds(nextIds, persistLegacyCache: true, cachedUserId: nil)
        print("[ReviewWordStore] review add success userId=local wordId=\(wordId)")
        notifySuccessFeedback()
    }

    private func removeReviewWord(_ wordId: Int) async {
        guard inFlightWordOperations.contains(wordId) == false else { return }
        inFlightWordOperations.insert(wordId)
        defer { inFlightWordOperations.remove(wordId) }

        if let userId = currentServerUserId {
            print("[ReviewWordStore] review remove start userId=\(userId) wordId=\(wordId)")
            do {
                try await apiService.removeReviewWord(userId: userId, wordId: wordId)
                var nextIds = reviewWordIds
                nextIds.remove(wordId)
                applyReviewWordIds(nextIds, persistLegacyCache: true, cachedUserId: userId)
                print("[ReviewWordStore] review remove success userId=\(userId) wordId=\(wordId)")
                notifySuccessFeedback()
            } catch {
                print("[ReviewWordStore] review remove failed userId=\(userId) wordId=\(wordId) error=\(error.localizedDescription)")
            }
            return
        }

        var nextIds = loadLegacyLocalReviewSet()
        nextIds.remove(wordId)
        applyReviewWordIds(nextIds, persistLegacyCache: true, cachedUserId: nil)
        print("[ReviewWordStore] review remove success userId=local wordId=\(wordId)")
        notifySuccessFeedback()
    }

    private func applyReviewWordIds(
        _ ids: Set<Int>,
        persistLegacyCache: Bool,
        cachedUserId: String?
    ) {
        reviewWordIds = ids

        if persistLegacyCache {
            userDefaults.set(Array(ids).sorted(), forKey: reviewWordsKey)
        }

        if let cachedUserId {
            userDefaults.set(Array(ids).sorted(), forKey: cachedReviewWordsKey(for: cachedUserId))
        }

        print("[ReviewWordStore] current review word count count=\(ids.count)")
    }

    private func loadLegacyLocalReviewSet() -> Set<Int> {
        Set(userDefaults.array(forKey: reviewWordsKey) as? [Int] ?? [])
    }

    private func loadCachedReviewSet(for userId: String) -> Set<Int>? {
        let ids = userDefaults.array(forKey: cachedReviewWordsKey(for: userId)) as? [Int]
        return ids.map(Set.init)
    }

    private func hasCompletedMigration(for userId: String) -> Bool {
        userDefaults.bool(forKey: migrationKey(for: userId))
    }

    private func markMigrationCompleted(for userId: String) {
        userDefaults.set(true, forKey: migrationKey(for: userId))
    }

    private func cachedReviewWordsKey(for userId: String) -> String {
        "\(cachedReviewWordsKeyPrefix)\(userId)"
    }

    private func migrationKey(for userId: String) -> String {
        "\(migrationKeyPrefix)\(userId)"
    }

    private func normalizedUserId(_ userId: String?) -> String? {
        let trimmedUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUserId?.isEmpty == false ? trimmedUserId : nil
    }

    private func notifySuccessFeedback() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
}
