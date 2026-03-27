import SwiftUI

struct PetalProgressView: View {
    let totalCount: Int
    let completedCount: Int

    private let petalColors: [Color] = [
        Color(red: 0.93, green: 0.77, blue: 0.82),
        Color(red: 0.97, green: 0.88, blue: 0.63),
        Color(red: 0.96, green: 0.82, blue: 0.73),
        Color(red: 0.88, green: 0.82, blue: 0.92)
    ]

    var body: some View {
        let clampedTotal = max(totalCount, 1)
        let clampedCompleted = min(max(completedCount, 0), clampedTotal)

        ZStack {
            ForEach(0..<clampedTotal, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(petalFillColor(for: index, completedCount: clampedCompleted))
                    .frame(width: 22, height: 48)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(petalBorderColor(for: index, completedCount: clampedCompleted), lineWidth: 0.8)
                    )
                    .shadow(color: shadowColor(for: index, completedCount: clampedCompleted), radius: 6, x: 0, y: 2)
                    .opacity(index < clampedCompleted ? 1 : 0.72)
                    .scaleEffect(index < clampedCompleted ? 1 : 0.94)
                    .offset(y: -36)
                    .rotationEffect(.degrees(Double(index) * (360.0 / Double(clampedTotal))))
                    .animation(.easeInOut(duration: 0.35), value: clampedCompleted)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.94),
                            Color(red: 0.98, green: 0.93, blue: 0.82)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 28
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .frame(width: 42, height: 42)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            Circle()
                .fill(Color(red: 0.89, green: 0.72, blue: 0.34).opacity(0.85))
                .frame(width: 12, height: 12)
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 꽃 진행도")
        .accessibilityValue("\(clampedCompleted)/\(clampedTotal)")
    }

    private func petalFillColor(for index: Int, completedCount: Int) -> Color {
        if index < completedCount {
            return petalColors[index % petalColors.count]
        }
        return Color(uiColor: .systemGray5).opacity(0.65)
    }

    private func petalBorderColor(for index: Int, completedCount: Int) -> Color {
        if index < completedCount {
            return Color.white.opacity(0.65)
        }
        return Color.white.opacity(0.4)
    }

    private func shadowColor(for index: Int, completedCount: Int) -> Color {
        if index < completedCount {
            return Color.black.opacity(0.06)
        }
        return .clear
    }
}

#Preview {
    PetalProgressView(totalCount: 10, completedCount: 6)
}
