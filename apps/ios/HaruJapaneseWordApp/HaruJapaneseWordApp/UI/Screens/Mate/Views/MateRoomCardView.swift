import SwiftUI

struct MateRoomCardView: View {
    let item: MateRoomCardItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("연결됨", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)

                    Text("상대: \(item.counterpartLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text("최근 콕: \(item.lastInteractionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    JLPTBadgeView(level: item.jlptLevel)
                    Text(item.extraInfoText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct JLPTBadgeView: View {
    let level: JLPTLevel

    private var fillColor: Color {
        switch level {
        case .n1:
            return .blue.opacity(0.2)
        case .n2:
            return .teal.opacity(0.2)
        case .n3:
            return .green.opacity(0.2)
        case .n4:
            return .orange.opacity(0.2)
        case .n5:
            return .gray.opacity(0.2)
        }
    }

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor)
            )
    }
}
