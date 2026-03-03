import Foundation

protocol MateUserMetaProvider {
    func jlptLevel(for userId: String) -> JLPTLevel?
}

struct DevMateUserMetaProvider: MateUserMetaProvider {
    func jlptLevel(for userId: String) -> JLPTLevel? {
        switch userId {
        case "DEV-A":
            return .n5
        case "DEV-B":
            return .n4
        case "DEV-C":
            return .n3
        case "DEV-D":
            return .n2
        default:
            return nil
        }
    }
}
