import SwiftUI
import UIKit

extension Color {
    static let appBackground = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.956, green: 0.964, blue: 0.972, alpha: 1),
            dark: UIColor(red: 0.067, green: 0.078, blue: 0.090, alpha: 1)
        )
    )

    static let surfacePrimary = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
            dark: UIColor(red: 0.110, green: 0.122, blue: 0.141, alpha: 1)
        )
    )

    static let surfaceSecondary = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.943, green: 0.953, blue: 0.968, alpha: 1),
            dark: UIColor(red: 0.149, green: 0.165, blue: 0.192, alpha: 1)
        )
    )

    static let textPrimary = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.094, green: 0.106, blue: 0.125, alpha: 1),
            dark: UIColor(red: 0.953, green: 0.965, blue: 0.980, alpha: 1)
        )
    )

    static let textSecondary = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.363, green: 0.392, blue: 0.445, alpha: 1),
            dark: UIColor(red: 0.737, green: 0.769, blue: 0.820, alpha: 1)
        )
    )

    static let textTertiary = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.525, green: 0.561, blue: 0.624, alpha: 1),
            dark: UIColor(red: 0.549, green: 0.588, blue: 0.651, alpha: 1)
        )
    )

    static let divider = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.843, green: 0.867, blue: 0.906, alpha: 1),
            dark: UIColor(red: 0.220, green: 0.247, blue: 0.286, alpha: 1)
        )
    )

    static let chipActive = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.937, green: 0.525, blue: 0.294, alpha: 1),
            dark: UIColor(red: 0.820, green: 0.478, blue: 0.286, alpha: 1)
        )
    )

    static let chipInactive = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.943, green: 0.953, blue: 0.968, alpha: 1),
            dark: UIColor(red: 0.149, green: 0.165, blue: 0.192, alpha: 1)
        )
    )

    static let iconPrimary = textPrimary
    static let iconSecondary = textSecondary
    static let brandSoft = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(red: 0.984, green: 0.713, blue: 0.490, alpha: 0.22),
            dark: UIColor(red: 0.820, green: 0.478, blue: 0.286, alpha: 0.22)
        )
    )
    static let appShadow = Color(
        uiColor: UIColor.dynamicColor(
            light: UIColor(white: 0, alpha: 0.07),
            dark: UIColor(white: 0, alpha: 0.28)
        )
    )
}

private extension UIColor {
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}
