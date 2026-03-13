import SwiftUI
import UIKit

struct BuddyProfilePreviewCard: View {
    let item: MateRoomCardItem
    let onClose: () -> Void

    private var bioText: String? {
        let trimmed = item.profile.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var instagramText: String? {
        let trimmed = item.profile.instagramId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "@\(trimmed)"
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                BuddyAvatarView(data: item.profile.avatarData, size: 104)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 8)

                VStack(spacing: 6) {
                    Text(item.counterpartLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Buddy mini profile")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                infoRow(icon: "graduationcap.fill", title: "JLPT 레벨", value: item.jlptLevel.title)

                if let instagramText {
                    infoRow(icon: "camera.fill", title: "Instagram", value: instagramText)
                }

                infoRow(icon: "clock.fill", title: "최근 접속", value: item.lastInteractionText)

                if let bioText {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("한 줄 소개", systemImage: "quote.opening")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(bioText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 14)
        )
        .padding(.horizontal, 24)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
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
                .stroke(Color.white.opacity(0.88), lineWidth: 1)
        }
    }
}
