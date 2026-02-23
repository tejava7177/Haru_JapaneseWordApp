import Foundation

struct MateIdentityStore {
    private let userDefaults: UserDefaults
    private let userIdKey = "mate_user_id"
    private let inviteCodeKey = "mate_invite_code"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    mutating func userId() -> String {
        if let existing = userDefaults.string(forKey: userIdKey) {
            return existing
        }
        let id = UUID().uuidString
        userDefaults.set(id, forKey: userIdKey)
        return id
    }

    mutating func inviteCode() -> String {
        if let existing = userDefaults.string(forKey: inviteCodeKey) {
            return existing
        }
        let code = Self.generateCode()
        userDefaults.set(code, forKey: inviteCodeKey)
        return code
    }

    private static func generateCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        for _ in 0..<6 {
            if let value = characters.randomElement() {
                code.append(value)
            }
        }
        return code
    }
}
