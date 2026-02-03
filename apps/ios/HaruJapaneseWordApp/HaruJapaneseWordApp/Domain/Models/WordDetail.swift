import Foundation

struct WordDetail: Identifiable, Hashable {
    let id: Int
    let expression: String
    let reading: String
    let meanings: [String]

    var meaningsJoined: String {
        meanings.joined(separator: " / ")
    }
}
