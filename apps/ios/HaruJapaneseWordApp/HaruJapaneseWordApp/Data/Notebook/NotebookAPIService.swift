import Foundation

protocol NotebookAPIServiceProtocol {
    func fetchNotebooks(userId: String) async throws -> [ServerNotebook]
    func createNotebook(userId: String, title: String, description: String?) async throws -> ServerNotebook
    func updateNotebook(userId: String, notebookId: Int, title: String, description: String?) async throws -> ServerNotebook
    func deleteNotebook(userId: String, notebookId: Int) async throws
    func createNotebookItem(
        userId: String,
        notebookId: Int,
        item: NotebookItemMutationPayload
    ) async throws -> ServerNotebookItem
    func updateNotebookItem(
        userId: String,
        notebookId: Int,
        itemId: Int,
        item: NotebookItemMutationPayload
    ) async throws -> ServerNotebookItem
    func deleteNotebookItem(userId: String, notebookId: Int, itemId: Int) async throws
    func migrateNotebooks(userId: String, payload: NotebookMigrationPayload) async throws
}

struct NotebookAPIService: NotebookAPIServiceProtocol {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchNotebooks(userId: String) async throws -> [ServerNotebook] {
        print("[NotebookAPI] GET /api/users/\(userId)/notebooks")
        let endpoint = APIEndpoint(path: "api/users/\(userId)/notebooks")
        let response = try await client.get(endpoint, responseType: NotebookListResponse.self)
        return response.notebooks
    }

    func createNotebook(userId: String, title: String, description: String?) async throws -> ServerNotebook {
        print("[NotebookAPI] POST /api/users/\(userId)/notebooks")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks",
            method: .post
        )
        let request = NotebookCreateRequest(title: title, description: description)
        return try await client.post(endpoint, body: request, responseType: ServerNotebook.self)
    }

    func updateNotebook(
        userId: String,
        notebookId: Int,
        title: String,
        description: String?
    ) async throws -> ServerNotebook {
        print("[NotebookAPI] PATCH /api/users/\(userId)/notebooks/\(notebookId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/\(notebookId)",
            method: .patch
        )
        let request = NotebookUpdateRequest(title: title, description: description)
        return try await client.patch(endpoint, body: request, responseType: ServerNotebook.self)
    }

    func deleteNotebook(userId: String, notebookId: Int) async throws {
        print("[NotebookAPI] DELETE /api/users/\(userId)/notebooks/\(notebookId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/\(notebookId)",
            method: .delete
        )

        do {
            _ = try await client.delete(endpoint, responseType: NotebookDeleteResponse.self)
        } catch APIError.decodingFailed {
            try await client.delete(endpoint)
        }
    }

    func createNotebookItem(
        userId: String,
        notebookId: Int,
        item: NotebookItemMutationPayload
    ) async throws -> ServerNotebookItem {
        print("[NotebookAPI] POST /api/users/\(userId)/notebooks/\(notebookId)/items")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/\(notebookId)/items",
            method: .post
        )
        let request = NotebookItemCreateRequest(
            itemType: item.itemType,
            wordId: item.wordId,
            expression: item.expression,
            reading: item.reading,
            meaning: item.meaning,
            memo: item.memo,
            sortOrder: item.sortOrder
        )
        return try await client.post(endpoint, body: request, responseType: ServerNotebookItem.self)
    }

    func updateNotebookItem(
        userId: String,
        notebookId: Int,
        itemId: Int,
        item: NotebookItemMutationPayload
    ) async throws -> ServerNotebookItem {
        print("[NotebookAPI] PATCH /api/users/\(userId)/notebooks/\(notebookId)/items/\(itemId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/\(notebookId)/items/\(itemId)",
            method: .patch
        )
        let request = NotebookItemUpdateRequest(
            itemType: item.itemType,
            wordId: item.wordId,
            expression: item.expression,
            reading: item.reading,
            meaning: item.meaning,
            memo: item.memo,
            sortOrder: item.sortOrder
        )
        return try await client.patch(endpoint, body: request, responseType: ServerNotebookItem.self)
    }

    func deleteNotebookItem(userId: String, notebookId: Int, itemId: Int) async throws {
        print("[NotebookAPI] DELETE /api/users/\(userId)/notebooks/\(notebookId)/items/\(itemId)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/\(notebookId)/items/\(itemId)",
            method: .delete
        )

        do {
            _ = try await client.delete(endpoint, responseType: NotebookItemDeleteResponse.self)
        } catch APIError.decodingFailed {
            try await client.delete(endpoint)
        }
    }

    func migrateNotebooks(userId: String, payload: NotebookMigrationPayload) async throws {
        print("[NotebookAPI] POST /api/users/\(userId)/notebooks/migration notebookCount=\(payload.notebooks.count)")
        let endpoint = APIEndpoint(
            path: "api/users/\(userId)/notebooks/migration",
            method: .post
        )

        do {
            _ = try await client.post(endpoint, body: payload, responseType: NotebookMigrationResponse.self)
        } catch APIError.decodingFailed {
            try await client.post(endpoint, body: payload)
        }
    }
}

struct NotebookItemMutationPayload: Encodable, Sendable {
    let itemType: NotebookItemType
    let wordId: Int?
    let expression: String
    let reading: String?
    let meaning: String
    let memo: String?
    let sortOrder: Int?
}

struct NotebookMigrationPayload: Encodable, Sendable {
    let notebooks: [NotebookMigrationNotebookRequest]
}

struct NotebookMigrationNotebookRequest: Encodable, Sendable {
    let title: String
    let description: String?
    let items: [NotebookMigrationItemRequest]
}

struct NotebookMigrationItemRequest: Encodable, Sendable {
    let wordId: Int?
    let expression: String
    let reading: String?
    let meaning: String
    let memo: String?
}

enum NotebookItemType: String, Codable, Sendable {
    case wordRef = "WORD_REF"
    case custom = "CUSTOM"
}

struct ServerNotebook: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String?
    let createdAt: String?
    let updatedAt: String?
    let items: [ServerNotebookItem]
}

struct ServerNotebookItem: Decodable, Sendable {
    let id: Int
    let itemType: NotebookItemType
    let wordId: Int?
    let expression: String
    let reading: String?
    let meaning: String
    let memo: String?
    let sortOrder: Int?
    let createdAt: String?
    let updatedAt: String?
}

private struct NotebookListResponse: Decodable {
    let userId: Int?
    let notebooks: [ServerNotebook]
}

private struct NotebookCreateRequest: Encodable {
    let title: String
    let description: String?
}

private struct NotebookUpdateRequest: Encodable {
    let title: String?
    let description: String?
}

private struct NotebookItemCreateRequest: Encodable {
    let itemType: NotebookItemType
    let wordId: Int?
    let expression: String
    let reading: String?
    let meaning: String
    let memo: String?
    let sortOrder: Int?
}

private struct NotebookItemUpdateRequest: Encodable {
    let itemType: NotebookItemType?
    let wordId: Int?
    let expression: String?
    let reading: String?
    let meaning: String?
    let memo: String?
    let sortOrder: Int?
}

private struct NotebookMigrationResponse: Decodable {
    let userId: Int?
    let migratedNotebookCount: Int?
    let totalNotebookCount: Int?
}

private struct NotebookDeleteResponse: Decodable {
    let deleted: Bool?
}

private struct NotebookItemDeleteResponse: Decodable {
    let deleted: Bool?
}
