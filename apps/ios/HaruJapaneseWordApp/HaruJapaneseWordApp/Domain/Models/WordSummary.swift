import Foundation

struct WordSummary: Identifiable, Hashable {
    let id: Int
    let expression: String
    let reading: String
    let meanings: String
}
