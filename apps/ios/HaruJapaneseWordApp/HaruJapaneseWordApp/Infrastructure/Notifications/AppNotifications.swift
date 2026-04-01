import Foundation

extension Notification.Name {
    static let dailyWordsDidRegenerate = Notification.Name("dailyWordsDidRegenerate")
    static let tsunTsunInboxDidChange = Notification.Name("tsunTsunInboxDidChange")
    static let buddyPetalStatusDidChange = Notification.Name("buddyPetalStatusDidChange")
}

enum BuddyPetalStatusChangeTrigger: String {
    case pushForeground = "pushForeground"
    case pushTap = "pushTap"
    case sceneActive = "sceneActive"
    case localSend = "localSend"
}

enum BuddyPushPayload {
    static let petalReceivedType = "PETAL_RECEIVED"
    static let triggerKey = "trigger"
    static let remoteUserInfoKey = "remoteUserInfo"

    static func isPetalReceived(userInfo: [AnyHashable: Any]) -> Bool {
        normalizedType(in: userInfo) == petalReceivedType
    }

    @MainActor
    static func postPetalStatusDidChange(
        trigger: BuddyPetalStatusChangeTrigger,
        remoteUserInfo: [AnyHashable: Any]? = nil
    ) {
        print("[BuddyPush] post internal notification trigger=\(trigger.rawValue)")
        var userInfo: [AnyHashable: Any] = [triggerKey: trigger.rawValue]
        if let remoteUserInfo {
            userInfo[remoteUserInfoKey] = remoteUserInfo
        }

        NotificationCenter.default.post(
            name: .buddyPetalStatusDidChange,
            object: nil,
            userInfo: userInfo
        )
    }

    static func trigger(from userInfo: [AnyHashable: Any]?) -> BuddyPetalStatusChangeTrigger? {
        guard let rawValue = userInfo?[triggerKey] as? String else { return nil }
        return BuddyPetalStatusChangeTrigger(rawValue: rawValue)
    }

    private static func normalizedType(in userInfo: [AnyHashable: Any]) -> String? {
        if let type = stringValue(userInfo["type"]) {
            return type.uppercased()
        }

        if let payload = userInfo["payload"] as? [AnyHashable: Any],
           let type = stringValue(payload["type"]) {
            return type.uppercased()
        }

        if let data = userInfo["data"] as? [AnyHashable: Any],
           let type = stringValue(data["type"]) {
            return type.uppercased()
        }

        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }
}
