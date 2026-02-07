import Foundation

struct Meaning: Identifiable, Hashable {
    let ord: Int
    let text: String

    var id: Int { ord }
}
