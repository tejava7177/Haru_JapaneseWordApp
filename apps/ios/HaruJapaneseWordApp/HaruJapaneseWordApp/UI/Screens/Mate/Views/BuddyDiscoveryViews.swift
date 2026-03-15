import SwiftUI

struct BuddyDiscoveryCardItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case incoming(requestId: Int)
        case randomCandidate(userId: Int?)
    }

    let id: String
    let kind: Kind
    let displayName: String
    let jlptLevel: JLPTLevel
    let recentAccessText: String
    let bio: String
    let instagramId: String
    let avatarData: Data?
    let primaryActionTitle: String
    let isPrimaryActionDisabled: Bool
}

struct BuddyDiscoverySectionView<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
        )
    }
}

struct BuddyDiscoveryCardView: View {
    let item: BuddyDiscoveryCardItem
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let onPreviewTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onPreviewTap) {
                BuddyAvatarView(data: item.avatarData, size: 56)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                JLPTBadgeView(level: item.jlptLevel)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let secondaryActionTitle, let onSecondaryAction {
                    Button(secondaryActionTitle, action: onSecondaryAction)
                        .buttonStyle(.bordered)
                }

                Button(item.primaryActionTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(item.isPrimaryActionDisabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}
