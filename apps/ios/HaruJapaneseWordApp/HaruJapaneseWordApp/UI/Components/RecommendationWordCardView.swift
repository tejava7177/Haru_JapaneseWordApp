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

                    if reading.isEmpty == false {
                        Text(reading)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if meanings.isEmpty == false {
                        Text(meanings)
                            .font(.body)
                            .foregroundStyle(.secondary)
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
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isExcluded ? Color.black.opacity(0.16) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
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
            .foregroundStyle(isExcluded ? .primary : .secondary)
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
    .background(Color(uiColor: .systemGroupedBackground))
}
