import SwiftUI

struct LyricTextBuilder {
    static func underlinedSubstring(text: String, target: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard target.isEmpty == false else { return attributed }

        if let range = attributed.range(of: target) {
            attributed[range].underlineStyle = Text.LineStyle(pattern: .solid, color: nil)
            // 또는:
            // attributed[range].underlineStyle = .init(pattern: .solid)
        }
        return attributed
    }
}
