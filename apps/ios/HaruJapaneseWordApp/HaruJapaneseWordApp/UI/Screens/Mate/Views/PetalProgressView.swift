import SwiftUI

struct PetalProgressView: View {
    @Environment(\.colorScheme) private var colorScheme

    let totalCount: Int
    let completedCount: Int

    private let petalColors: [Color] = [
        Color(red: 0.90, green: 0.74, blue: 0.80),
        Color(red: 0.95, green: 0.85, blue: 0.62),
        Color(red: 0.93, green: 0.78, blue: 0.70),
        Color(red: 0.91, green: 0.80, blue: 0.72)
    ]

    var body: some View {
        let clampedTotal = max(totalCount, 1)
        let clampedCompleted = min(max(completedCount, 0), clampedTotal)

        ZStack {
            ForEach(0..<clampedTotal, id: \.self) { index in
                let isCompleted = index < clampedCompleted
                let variation = petalVariation(for: index)
                let rotationDegrees: Double = (Double(index) * (360.0 / Double(clampedTotal))) + variation.rotation

                PetalLayerView(
                    isCompleted: isCompleted,
                    variation: variation,
                    colorScheme: colorScheme,
                    fill: petalGradient(for: index),
                    borderColor: petalBorderColor(isCompleted: isCompleted)
                )
                .offset(y: -36)
                .rotationEffect(.degrees(rotationDegrees))
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: clampedCompleted)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: centerGradientColors,
                        center: .center,
                        startRadius: 4,
                        endRadius: 28
                    )
                )
                .overlay(
                    Circle()
                        .stroke(centerStrokeColor, lineWidth: 1)
                )
                .frame(width: 42, height: 42)
                .shadow(color: centerShadowColor, radius: 8, x: 0, y: 3)

            Circle()
                .fill(Color(red: 0.89, green: 0.72, blue: 0.34).opacity(colorScheme == .dark ? 0.95 : 0.88))
                .frame(width: 12, height: 12)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 3, x: 0, y: 1)
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 꽃 진행도")
        .accessibilityValue("\(clampedCompleted)/\(clampedTotal)")
    }

    private func petalColor(for index: Int) -> Color {
        petalColors[index % petalColors.count]
    }

    private func petalGradient(for index: Int) -> LinearGradient {
        let baseColor = adjustedPetalColor(for: index)
        let lowerColor = baseColor.mix(with: Color.black, amount: colorScheme == .dark ? 0.14 : 0.1)

        let gradientColors: [Color] = [
            baseColor.opacity(0.98),
            lowerColor.opacity(0.96)
        ]
        return LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func petalBorderColor(isCompleted: Bool) -> Color {
        if isCompleted {
            return Color.white.opacity(colorScheme == .dark ? 0.34 : 0.58)
        }
        return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.2)
    }

    private func shadowColor(isCompleted: Bool) -> Color {
        guard isCompleted else { return .clear }
        return Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08)
    }

    private func adjustedPetalColor(for index: Int) -> Color {
        let color = petalColor(for: index)
        if colorScheme == .dark {
            return color.mix(with: .white, amount: 0.08)
        }
        return color
    }

    private func petalVariation(for index: Int) -> PetalVariation {
        let seed = Double((index * 37 + 11) % 100) / 100.0
        let seed2 = Double((index * 53 + 7) % 100) / 100.0

        return PetalVariation(
            rotation: -3 + (seed * 6),
            scale: 0.95 + (seed2 * 0.10),
            verticalScale: 0.96 + (seed * 0.08)
        )
    }

    private var centerGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.98, green: 0.89, blue: 0.80).opacity(0.9),
                Color(red: 0.80, green: 0.62, blue: 0.52).opacity(0.78)
            ]
        }

        return [
            Color(red: 1.0, green: 0.98, blue: 0.94),
            Color(red: 0.98, green: 0.93, blue: 0.82)
        ]
    }

    private var centerStrokeColor: Color {
        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.9)
    }

    private var centerShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07)
    }
}

private struct PetalLayerView: View {
    let isCompleted: Bool
    let variation: PetalVariation
    let colorScheme: ColorScheme
    let fill: LinearGradient
    let borderColor: Color

    var body: some View {
        let petal = PetalShape()
        let strokeWidth: CGFloat = isCompleted ? 0.9 : 0.75
        let overlayHighlight: Color? = (colorScheme == .dark) ? Color.white.opacity(0.05) : nil
        let shadowClr: Color = isCompleted ? Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08) : .clear
        let opacityValue: Double = isCompleted ? 1.0 : 0.24
        let blurRadius: CGFloat = isCompleted ? 0 : 0.5
        let scale: CGFloat = isCompleted ? 1.0 : 0.97
        let shadowRadius: CGFloat = isCompleted ? 4 : 3

        return petal
            .fill(fill)
            .frame(
                width: 24 * variation.scale,
                height: 50 * variation.verticalScale
            )
            .overlay(
                petal
                    .stroke(borderColor, lineWidth: strokeWidth)
            )
            .overlay(
                Group {
                    if let overlayHighlight {
                        petal.fill(overlayHighlight)
                    }
                }
            )
            .shadow(color: shadowClr, radius: shadowRadius, x: 0, y: 2)
            .opacity(opacityValue)
            .blur(radius: blurRadius)
            .scaleEffect(scale)
    }
}

private struct PetalVariation {
    let rotation: Double
    let scale: Double
    let verticalScale: Double
}

private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let midX = rect.midX
        let minY = rect.minY
        let maxY = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: midX, y: minY))
        path.addCurve(
            to: CGPoint(x: width * 0.86, y: height * 0.52),
            control1: CGPoint(x: width * 0.78, y: height * 0.08),
            control2: CGPoint(x: width * 0.98, y: height * 0.26)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: maxY),
            control1: CGPoint(x: width * 0.78, y: height * 0.8),
            control2: CGPoint(x: width * 0.6, y: height * 0.96)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.14, y: height * 0.52),
            control1: CGPoint(x: width * 0.4, y: height * 0.96),
            control2: CGPoint(x: width * 0.22, y: height * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: minY),
            control1: CGPoint(x: width * 0.02, y: height * 0.26),
            control2: CGPoint(x: width * 0.22, y: height * 0.08)
        )
        path.closeSubpath()
        return path
    }
}

private extension Color {
    func mix(with color: Color, amount: Double) -> Color {
        let amount = min(max(amount, 0), 1)
        return Color(
            UIColor(self).mixed(with: UIColor(color), amount: amount)
        )
    }
}

private extension UIColor {
    func mixed(with color: UIColor, amount: Double) -> UIColor {
        let amount = min(max(amount, 0), 1)

        var red1: CGFloat = 0
        var green1: CGFloat = 0
        var blue1: CGFloat = 0
        var alpha1: CGFloat = 0
        var red2: CGFloat = 0
        var green2: CGFloat = 0
        var blue2: CGFloat = 0
        var alpha2: CGFloat = 0

        getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        color.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)

        return UIColor(
            red: red1 + (red2 - red1) * amount,
            green: green1 + (green2 - green1) * amount,
            blue: blue1 + (blue2 - blue1) * amount,
            alpha: alpha1 + (alpha2 - alpha1) * amount
        )
    }
}

#Preview {
    PetalProgressView(totalCount: 10, completedCount: 6)
}
