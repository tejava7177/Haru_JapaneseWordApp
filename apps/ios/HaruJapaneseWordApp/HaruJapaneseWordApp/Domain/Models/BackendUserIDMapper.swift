import Foundation

enum BackendUserIDMapper {
    private static let mappings: [String: String] = [
        "juheun": "1",
        "1": "1",
        "dev-a": "1",
        "a": "1",
        "buddy2": "2",
        "2": "2",
        "dev-b": "2",
        "b": "2",
        "buddy3": "3",
        "3": "3",
        "dev-c": "3",
        "c": "3",
        "buddy4": "4",
        "4": "4",
        "dev-d": "4",
        "d": "4"
    ]

    static func backendUserId(for rawUserId: String, displayName: String? = nil) -> String? {
        let normalizedRawUserId = normalize(rawUserId)
        if let mapped = mappings[normalizedRawUserId] {
            return mapped
        }

        guard let displayName else { return nil }
        return mappings[normalize(displayName)]
    }

    static func candidateRawUserIds(forBackendUserId backendUserId: Int) -> [String] {
        let backendValue = String(backendUserId)
        return mappings
            .filter { $0.value == backendValue }
            .map(\.key)
            .sorted()
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
