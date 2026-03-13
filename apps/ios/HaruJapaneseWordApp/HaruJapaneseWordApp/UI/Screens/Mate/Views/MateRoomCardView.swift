import SwiftUI
import UIKit

struct MateRoomCardView: View {
    let item: MateRoomCardItem
    let onAvatarTap: (() -> Void)?
    let onCardTap: (() -> Void)?

    private let avatarSize: CGFloat = 52

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarView

            HStack(alignment: .top, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("연결됨", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)

                        Text("상대: \(item.counterpartLabel)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("최근 콕: \(item.lastInteractionText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        JLPTBadgeView(level: item.jlptLevel)
                        Text(item.buddyStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onCardTap?()
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .onTapGesture {
                        onCardTap?()
                    }
            }
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

    private var avatarView: some View {
        BuddyAvatarView(data: item.profile.avatarData, size: avatarSize)
            .contentShape(Circle())
            .onTapGesture {
                onAvatarTap?()
            }
    }
}

private struct BuddyAvatarView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemGray5))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(Color(uiColor: .systemGray2))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
        }
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
