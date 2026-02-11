import Foundation

struct LyricEntry: Identifiable, Hashable {
    let id: String
    let inspiredBy: String
    let jaLine: String
    let koLine: String
    let targetExpression: String
    let targetReading: String
    let targetMeaningKo: String
    let targetJlpt: String
    let tags: String
}
