import Foundation

enum JLPTLevel: String, CaseIterable, Identifiable {
    case n5 = "N5"
    case n4 = "N4"
    case n3 = "N3"
    case n2 = "N2"
    case n1 = "N1"

    var id: String { rawValue }

    var title: String { rawValue }

    var rank: Int {
        switch self {
        case .n1: return 1
        case .n2: return 2
        case .n3: return 3
        case .n4: return 4
        case .n5: return 5
        }
    }
}
