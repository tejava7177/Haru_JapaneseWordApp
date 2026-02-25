import Foundation

struct MatchCelebrationMessage: Hashable {
    let title: String
    let subtitle: String

    var isJapaneseOnly: Bool {
        let combined = title + subtitle
        let hasHangul = combined.range(of: "[\\uAC00-\\uD7A3]", options: .regularExpression) != nil
        let hasJapanese = combined.range(of: "[\\u3040-\\u30FF\\u4E00-\\u9FAF]", options: .regularExpression) != nil
        return hasJapanese && hasHangul == false
    }
}

enum MatchCelebrationMessageProvider {
    private static let koOnly: [MatchCelebrationMessage] = [
        .init(title: "Mate가 성사되었어요 🎉", subtitle: "이제 함께 공부해요 ✨"),
        .init(title: "동행이 시작됐어요 🌸", subtitle: "오늘도 꾸준히 가볼까요?"),
        .init(title: "새로운 메이트가 생겼어요 💙", subtitle: "이제 혼자가 아니에요")
    ]

    private static let jpOnly: [MatchCelebrationMessage] = [
        .init(title: "メイトが成立しました 🎉", subtitle: "一緒にがんばりましょう ✨"),
        .init(title: "同行が始まりました 🌸", subtitle: "今日もコツコツいこう"),
        .init(title: "新しいメイトができました 💙", subtitle: "これからよろしくね")
    ]

    private static let mixed: [MatchCelebrationMessage] = [
        .init(title: "Mate가 성사되었어요 🎉", subtitle: "一緒にがんばりましょう ✨"),
        .init(title: "동행 성공 💫", subtitle: "今日から一緒に勉強です"),
        .init(title: "이제 콕 찌를 수 있어요 👈", subtitle: "さあ、はじめましょう")
    ]

    static func random() -> MatchCelebrationMessage {
        let roll = Double.random(in: 0...1)
        if roll < 0.5 {
            return mixed.randomElement() ?? koOnly[0]
        }
        if roll < 0.75 {
            return koOnly.randomElement() ?? mixed[0]
        }
        return jpOnly.randomElement() ?? mixed[0]
    }
}
