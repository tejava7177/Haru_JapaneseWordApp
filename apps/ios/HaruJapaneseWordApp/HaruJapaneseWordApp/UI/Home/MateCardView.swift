import SwiftUI

struct MateCardView: View {
    let title: String
    let description: String
    let myStatus: String?
    let mateStatus: String?
    let canPoke: Bool
    let isCTA: Bool
    let ctaTitle: String
    let onTapCTA: () -> Void
    let onPoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let myStatus, let mateStatus {
                HStack(spacing: 12) {
                    statusChip(title: "나", value: myStatus)
                    statusChip(title: "Mate", value: mateStatus)
                }
            }

            HStack {
                if isCTA {
                    Button(ctaTitle) {
                        onTapCTA()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                } else {
                    Button {
                        onPoke()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text("콕 찌르기")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(canPoke == false)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func statusChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    MateCardView(
        title: "🌿 함께 걷는 중",
        description: "오늘도 천천히 걸어봐요.",
        myStatus: "학습 완료",
        mateStatus: "아직 시작 전",
        canPoke: true,
        isCTA: false,
        ctaTitle: "동행 시작",
        onTapCTA: {},
        onPoke: {}
    )
    .padding()
}
