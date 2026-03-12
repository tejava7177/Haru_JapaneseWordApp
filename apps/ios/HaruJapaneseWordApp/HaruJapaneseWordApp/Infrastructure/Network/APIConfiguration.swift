import Foundation

enum APIConfiguration {
    private static let userDefaultsBaseURLKey = "haru_api_base_url"
    private static let environmentBaseURLKey = "HARU_API_BASE_URL"
    private static let defaultBaseURLString = "http://localhost:8080"

    static var baseURL: URL {
        let candidate = ProcessInfo.processInfo.environment[environmentBaseURLKey]
            ?? UserDefaults.standard.string(forKey: userDefaultsBaseURLKey)
            ?? defaultBaseURLString

        guard let url = URL(string: candidate.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return URL(string: defaultBaseURLString)!
        }
        return url
    }
}
