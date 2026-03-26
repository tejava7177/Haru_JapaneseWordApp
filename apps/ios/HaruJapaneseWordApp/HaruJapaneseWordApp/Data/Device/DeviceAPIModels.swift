import Foundation

struct RegisterDeviceTokenRequest: Encodable, Sendable {
    let deviceToken: String
    let platform: String
    let pushEnabled: Bool

    init(deviceToken: String, platform: String = "IOS", pushEnabled: Bool = true) {
        self.deviceToken = deviceToken
        self.platform = platform
        self.pushEnabled = pushEnabled
    }
}
