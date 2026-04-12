import Foundation

protocol ReviewWordAPIServiceProtocol {
    func fetchReviewWords(userId: String) async throws -> Set<Int>
    func addReviewWord(userId: String, wordId: Int) async throws
    func removeReviewWord(userId: String, wordId: Int) async throws
    func migrateReviewWords(userId: String, wordIds: [Int]) async throws
}

struct ReviewWordAPIService: ReviewWordAPIServiceProtocol, Sendable {
    private let client: APIClient

    nonisolated init(client: APIClient = APIClient()) {
        self.client = client
    }

    nonisolated func fetchReviewWords(userId: String) async throws -> Set<Int> {
        print("[ReviewWordAPI] GET /api/users/\(userId)/review-words")
        let endpoint = APIEndpoint(path: "api/users/\(userId)/review-words")
        let response = try await client.get(endpoint, responseType: ReviewWordsResponse.self)
        return response.wordIds
    }

    nonisolated func addReviewWord(userId: String, wordId: Int) async throws {
        print("[ReviewWordAPI] PUT /api/users/\(userId)/review-words/\(wordId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/review-words/\(wordId)",
            method: .put
        )

        do {
            _ = try await client.put(endpoint, responseType: ReviewWordMutationResponse.self)
        } catch APIError.decodingFailed {
            try await client.put(endpoint)
        }
    }

    nonisolated func removeReviewWord(userId: String, wordId: Int) async throws {
        print("[ReviewWordAPI] DELETE /api/users/\(userId)/review-words/\(wordId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/review-words/\(wordId)",
            method: .delete
        )

        do {
            _ = try await client.delete(endpoint, responseType: ReviewWordMutationResponse.self)
        } catch APIError.decodingFailed {
            try await client.delete(endpoint)
        }
    }

    nonisolated func migrateReviewWords(userId: String, wordIds: [Int]) async throws {
        let sortedWordIds = Array(Set(wordIds)).sorted()
        print("[ReviewWordAPI] POST /api/users/\(userId)/review-words/migration wordCount=\(sortedWordIds.count)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/review-words/migration",
            method: .post
        )
        let request = ReviewWordMigrationRequest(wordIds: sortedWordIds)

        do {
            _ = try await client.post(endpoint, body: request, responseType: ReviewWordMutationResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: request)
        }
    }
}

private struct ReviewWordMigrationRequest: Encodable {
    let wordIds: [Int]
}

private struct ReviewWordMutationResponse: Decodable {
    let success: Bool?
    let message: String?
}

private struct ReviewWordsResponse: Decodable {
    let wordIds: Set<Int>

    private enum CodingKeys: String, CodingKey {
        case wordIds
        case reviewWords
        case reviewWordIds
        case items
        case data
    }

    init(from decoder: Decoder) throws {
        if let intArray = try? [Int](from: decoder) {
            wordIds = Set(intArray)
            return
        }

        if let itemArray = try? [ReviewWordItem](from: decoder) {
            wordIds = Set(itemArray.map(\.wordId))
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intArray = try container.decodeFlexibleIntArrayIfPresent(forKeys: [.wordIds, .reviewWords, .reviewWordIds]) {
            wordIds = Set(intArray)
            return
        }

        if let itemArray = try container.decodeReviewWordItemsIfPresent(forKeys: [.items, .data, .reviewWords]) {
            wordIds = Set(itemArray.map(\.wordId))
            return
        }

        wordIds = []
    }
}

private struct ReviewWordItem: Decodable {
    let wordId: Int

    private enum CodingKeys: String, CodingKey {
        case wordId
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wordId = try container.decodeFlexibleInt(forKeys: [.wordId, .id])
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKeys keys: [Key]) throws -> Int {
        for key in keys {
            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return intValue
            }

            if let stringValue = try decodeIfPresent(String.self, forKey: key),
               let intValue = Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return intValue
            }
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected Int value for any of keys: \(keys)"
            )
        )
    }

    func decodeFlexibleIntArrayIfPresent(forKeys keys: [Key]) throws -> [Int]? {
        for key in keys {
            if let intArray = try decodeIfPresent([Int].self, forKey: key) {
                return intArray
            }

            if let stringArray = try decodeIfPresent([String].self, forKey: key) {
                let mapped = stringArray.compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                return mapped.isEmpty ? nil : mapped
            }
        }

        return nil
    }

    func decodeReviewWordItemsIfPresent(forKeys keys: [Key]) throws -> [ReviewWordItem]? {
        for key in keys {
            if let items = try decodeIfPresent([ReviewWordItem].self, forKey: key) {
                return items
            }
        }

        return nil
    }
}
