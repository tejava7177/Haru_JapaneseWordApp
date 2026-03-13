import SwiftUI
import UIKit

struct MateRoomCardView: View {
    let item: MateRoomCardItem

    @State private var isPreviewVisible: Bool = false
    @State private var previewActivationWorkItem: DispatchWorkItem?

    private let avatarSize: CGFloat = 52
    private let previewLongPressDuration: TimeInterval = 0.28

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarView

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
        .onDisappear {
            hidePreviewImmediately()
        }
    }

    private var avatarView: some View {
        BuddyAvatarView(data: item.profile.avatarData, size: avatarSize)
            .overlay(alignment: .topLeading) {
                if isPreviewVisible {
                    BuddyProfilePreviewCard(item: item)
                        .offset(x: avatarSize - 6, y: -14)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                        .zIndex(1)
                }
            }
            .onLongPressGesture(
                minimumDuration: previewLongPressDuration,
                maximumDistance: 24,
                pressing: handleAvatarPressing(_:),
                perform: {}
            )
    }

    private func handleAvatarPressing(_ isPressing: Bool) {
        if isPressing {
            previewActivationWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPreviewVisible = true
                }
            }
            previewActivationWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + previewLongPressDuration, execute: workItem)
        } else {
            hidePreviewImmediately()
        }
    }

    private func hidePreviewImmediately() {
        previewActivationWorkItem?.cancel()
        previewActivationWorkItem = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            isPreviewVisible = false
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

private struct BuddyProfilePreviewCard: View {
    let item: MateRoomCardItem

    private var bioText: String? {
        let trimmed = item.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var instagramText: String? {
        let trimmed = item.profile.instagramId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "@\(trimmed)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                BuddyAvatarView(data: item.profile.avatarData, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.counterpartLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("학습 레벨 \(item.jlptLevel.title)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let bioText {
                Text(bioText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            if let instagramText {
                Label(instagramText, systemImage: "camera")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 210, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
        )
        .overlay(alignment: .topLeading) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .rotationEffect(.degrees(135))
                .offset(x: 10, y: -5)
        }
        .allowsHitTesting(false)
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
