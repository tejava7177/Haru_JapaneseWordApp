import SwiftUI

struct ReviewSwipeRow<Content: View>: View {
    let isReviewWord: Bool
    let onToggleReview: () -> Void
    let onTap: () -> Void
    private let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var didDragHorizontally: Bool = false
    @State private var progress: CGFloat = 0
    private let actionWidth: CGFloat = 92

    init(isReviewWord: Bool, onToggleReview: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isReviewWord = isReviewWord
        self.onToggleReview = onToggleReview
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        let shouldShowBackground = dragOffset != 0

        ZStack {
            HStack {
                // Reserved for future left actions.
                Spacer()
                ReviewBackgroundView(
                    progress: progress,
                    isReviewWord: isReviewWord
                )
                .frame(width: actionWidth)
                .opacity(shouldShowBackground ? 1 : 0)
            }
            .allowsHitTesting(false)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .offset(x: dragOffset)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if didDragHorizontally {
                        return
                    }
                    onTap()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) < abs(dy) {
                        return
                    }
                    if abs(dx) < 8 {
                        return
                    }
                    if dx >= 0 {
                        return
                    }
                    didDragHorizontally = true
                    dragOffset = max(dx, -actionWidth * 1.2)
                    let threshold = actionWidth * 0.9
                    progress = min(1, abs(dragOffset) / max(1, threshold))
                }
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) < abs(dy) || abs(dx) < 8 || dx >= 0 {
                        reset()
                        scheduleDragReset()
                        return
                    }
                    if abs(dragOffset) >= actionWidth * 0.75 {
                        onToggleReview()
                    }
                    reset()
                    scheduleDragReset()
                }
        )
    }

    private func reset() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            dragOffset = 0
            progress = 0
        }
    }

    private func scheduleDragReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            didDragHorizontally = false
        }
    }

}

private struct ReviewBackgroundView: View {
    let progress: CGFloat
    let isReviewWord: Bool

    var body: some View {
        let baseColor = isReviewWord ? Color.secondary : Color.orange
        let fillOpacity = 0.18 + (0.3 * progress)
        let iconScale = 0.9 + (0.35 * progress)
        let iconOpacity = 0.6 + (0.4 * progress)

        VStack(spacing: 4) {
            Image(systemName: "book.fill")
                .font(.system(size: 16, weight: .semibold))
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
            Text("복습")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(baseColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(baseColor.opacity(fillOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }
}
