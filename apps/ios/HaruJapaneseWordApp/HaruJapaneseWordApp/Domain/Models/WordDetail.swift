import Foundation

struct WordDetail: Identifiable, Hashable {
    let id: Int
    let expression: String
    let reading: String
    let meanings: [String]

    var meaningsJoined: String {
        let joined = meanings.joined(separator: " / ")
        return joined.isEmpty ? "—" : joined
    }
}
