import SwiftUI

struct RecommendationWordCardView: View {
    let expression: String
    let reading: String
    let meanings: String
    let isExcluded: Bool
    let action: (() -> Void)?

    private let cornerRadius: CGFloat = 18
    private let bottomSafeSpace: CGFloat = 14

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(expression)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)

                    if reading.isEmpty == false {
                        Text(reading)
                            .font(.title3)
                            .foregroundStyle(Color.textSecondary)
                    }

                    if meanings.isEmpty == false {
                        Text(meanings)
                            .font(.body)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 18)
                .padding(.leading, 18)
                .padding(.trailing, 16)
                .padding(.bottom, 8)

                Spacer(minLength: 10)
                Spacer(minLength: bottomSafeSpace)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .padding(10)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isExcluded ? Color.chipActive.opacity(0.55) : Color.divider, lineWidth: 1)
            )
            .shadow(color: Color.appShadow, radius: 8, x: 0, y: 3)
        }
        .overlay(alignment: .topTrailing) {
            Group {
                if let action {
                    Button(action: action) {
                        checkIcon
                    }
                    .buttonStyle(.plain)
                } else {
                    checkIcon
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
    }

    private var checkIcon: some View {
        Image(systemName: isExcluded ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isExcluded ? Color.chipActive : Color.iconSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

#Preview {
    RecommendationWordCardView(
        expression: "食べる",
        reading: "たべる",
        meanings: "먹다",
        isExcluded: false,
        action: {}
    )
    .frame(height: 228)
    .padding()
    .background(Color.appBackground)
}
