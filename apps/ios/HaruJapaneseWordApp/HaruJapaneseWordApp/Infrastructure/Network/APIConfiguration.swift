import Foundation

enum APIConfiguration {
    private static let userDefaultsBaseURLKey = "haru_api_base_url"
    private static let environmentBaseURLKey = "HARU_API_BASE_URL"
    private static let environmentNameKey = "HARU_API_ENV"

    enum Environment: String {
        case prod
        case dev

        var baseURLString: String {
            switch self {
            case .prod:
                return "https://api.worldharu-app.com"
            case .dev:
                return "http://localhost:8080"
            }
        }
    }

    static var currentEnvironment: Environment {
        guard let rawValue = ProcessInfo.processInfo.environment[environmentNameKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              let environment = Environment(rawValue: rawValue) else {
            return .prod
        }
        return environment
    }

    static var baseURL: URL {
        let candidate = ProcessInfo.processInfo.environment[environmentBaseURLKey]
            ?? UserDefaults.standard.string(forKey: userDefaultsBaseURLKey)
            ?? currentEnvironment.baseURLString

        guard let url = URL(string: candidate.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return URL(string: currentEnvironment.baseURLString)!
        }
        return url
    }
}
