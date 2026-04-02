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
    let profileImageUrl: String?
    let avatarData: Data?
    let primaryActionTitle: String
    let isPrimaryActionDisabled: Bool
}

struct BuddyDiscoverySectionView<Content: View, HeaderAccessory: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    let headerAccessory: HeaderAccessory

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) where HeaderAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = EmptyView()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                headerAccessory
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
    private enum Layout {
        static let buttonHeight: CGFloat = 36
        static let secondaryButtonWidth: CGFloat = 64
        static let primaryButtonWidth: CGFloat = 64
        static let singlePrimaryButtonWidth: CGFloat = 84
    }

    let item: BuddyDiscoveryCardItem
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let onPreviewTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onPreviewTap) {
                BuddyAvatarView(data: item.avatarData, imageURLString: item.profileImageUrl, size: 56)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                JLPTBadgeView(level: item.jlptLevel)
                    .layoutPriority(0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let secondaryActionTitle, let onSecondaryAction {
                    fixedActionButton(
                        title: secondaryActionTitle,
                        width: Layout.secondaryButtonWidth,
                        style: .secondary,
                        action: onSecondaryAction
                    )
                }

                fixedActionButton(
                    title: item.primaryActionTitle,
                    width: secondaryActionTitle == nil ? Layout.singlePrimaryButtonWidth : Layout.primaryButtonWidth,
                    style: .primary,
                    isDisabled: item.isPrimaryActionDisabled,
                    action: onPrimaryAction
                )
            }
            .frame(
                width: secondaryActionTitle == nil
                    ? Layout.singlePrimaryButtonWidth
                    : Layout.primaryButtonWidth + Layout.secondaryButtonWidth + 8,
                alignment: .trailing
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func fixedActionButton(
        title: String,
        width: CGFloat,
        style: BuddyDiscoveryActionButtonStyle.Kind,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(BuddyDiscoveryActionButtonStyle(kind: style, width: width, height: Layout.buttonHeight))
            .disabled(isDisabled)
            .contentShape(Capsule(style: .continuous))
    }
}

private struct BuddyDiscoveryActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind
    let width: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .frame(width: width, height: height)
            .foregroundStyle(foregroundColor(configuration: configuration))
            .background(backgroundColor(configuration: configuration))
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: kind == .secondary ? 1 : 0)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return .white
        case .secondary:
            return .primary
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return configuration.roleAwareBlack.opacity(configuration.isPressed ? 0.88 : 1)
        case .secondary:
            return Color(uiColor: .secondarySystemBackground)
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return .clear
        case .secondary:
            return Color(uiColor: .separator).opacity(0.28)
        }
    }
}

private extension ButtonStyleConfiguration {
    var roleAwareBlack: Color {
        Color.black
    }
}
