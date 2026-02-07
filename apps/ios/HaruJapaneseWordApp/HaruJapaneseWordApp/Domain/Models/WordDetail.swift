import Foundation

struct WordDetail: Identifiable, Hashable {
    let id: Int
    let level: JLPTLevel
    let expression: String
    let reading: String
    let meanings: [Meaning]
}
