import Foundation

enum JLPTLevel: String, CaseIterable, Identifiable {
    case n5 = "N5"
    case n4 = "N4"

    var id: String { rawValue }

    var title: String { rawValue }
}
