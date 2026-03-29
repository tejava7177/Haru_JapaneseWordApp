import SwiftUI
import UIKit

enum AppTheme {
    private static var didConfigureTabBarAppearance = false

    static func configureTabBarAppearance() {
        guard didConfigureTabBarAppearance == false else { return }
        didConfigureTabBarAppearance = true

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.surfacePrimary)
        appearance.shadowColor = UIColor(Color.divider)

        let normalColor = UIColor(Color.iconSecondary)
        let selectedColor = UIColor(Color.chipActive)

        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func appCardStyle(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 10, shadowY: CGFloat = 4) -> some View {
        self
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.divider, lineWidth: 1)
            )
            .shadow(color: Color.appShadow, radius: shadowRadius, x: 0, y: shadowY)
    }

    func appSecondarySurfaceStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.divider, lineWidth: 1)
            )
    }
}
