import Foundation

enum JLPTLevelRange: Equatable, CaseIterable, Identifiable {
    case all
    case n5ToN4
    case n5ToN3
    case n5ToN2
    case n5ToN1
    case n4ToN3
    case n4ToN2
    case n4ToN1
    case n3ToN2
    case n3ToN1
    case n2ToN1

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .all: return "전체"
        case .n5ToN4: return "N5~N4"
        case .n5ToN3: return "N5~N3"
        case .n5ToN2: return "N5~N2"
        case .n5ToN1: return "N5~N1"
        case .n4ToN3: return "N4~N3"
        case .n4ToN2: return "N4~N2"
        case .n4ToN1: return "N4~N1"
        case .n3ToN2: return "N3~N2"
        case .n3ToN1: return "N3~N1"
        case .n2ToN1: return "N2~N1"
        }
    }

    var levels: [JLPTLevel] {
        switch self {
        case .all:
            return JLPTLevel.allCases
        case .n5ToN4:
            return [.n5, .n4]
        case .n5ToN3:
            return [.n5, .n4, .n3]
        case .n5ToN2:
            return [.n5, .n4, .n3, .n2]
        case .n5ToN1:
            return [.n5, .n4, .n3, .n2, .n1]
        case .n4ToN3:
            return [.n4, .n3]
        case .n4ToN2:
            return [.n4, .n3, .n2]
        case .n4ToN1:
            return [.n4, .n3, .n2, .n1]
        case .n3ToN2:
            return [.n3, .n2]
        case .n3ToN1:
            return [.n3, .n2, .n1]
        case .n2ToN1:
            return [.n2, .n1]
        }
    }

    func contains(_ level: JLPTLevel) -> Bool {
        levels.contains(level)
    }

    static func availableRanges(availableLevels: Set<JLPTLevel>) -> [JLPTLevelRange] {
        let all = JLPTLevelRange.allCases
        guard availableLevels.isEmpty == false else {
            return [.all]
        }
        return all.filter { range in
            if range == .all {
                return true
            }
            let required = Set(range.levels)
            return required.isSubset(of: availableLevels)
        }
    }
}
