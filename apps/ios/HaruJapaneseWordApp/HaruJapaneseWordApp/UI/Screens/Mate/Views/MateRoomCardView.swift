import SwiftUI

struct MateRoomCardView: View {
    let item: MateRoomCardItem
    let isBusy: Bool
    let onSendPoke: () -> Void
    let onEndRoom: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            Divider()

            HStack(spacing: 10) {
                Button("콕 찌르기") {
                    onSendPoke()
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(item.canSendPokeToday == false || isBusy)

                Spacer()

                Button("동행 종료") {
                    onEndRoom()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }

            if let pokeStatusText = item.pokeStatusText, pokeStatusText.isEmpty == false {
                Text(pokeStatusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct JLPTBadgeView: View {
    let level: JLPTLevel?

    private var title: String {
        level?.title ?? "?"
    }

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
        case .none:
            return .gray.opacity(0.14)
        }
    }

    var body: some View {
        Text(title)
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
