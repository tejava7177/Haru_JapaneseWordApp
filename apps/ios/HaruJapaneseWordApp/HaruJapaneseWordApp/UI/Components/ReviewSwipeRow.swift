import SwiftUI

struct ReviewSwipeRow<Content: View>: View {
    let isReviewWord: Bool
    let onToggleReview: () -> Void
    let onTap: () -> Void
    private let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var didDragHorizontally: Bool = false
    @State private var didCommit: Bool = false
    @State private var commitIcon: String? = nil
    @State private var progress: CGFloat = 0
    private let actionWidth: CGFloat = 92
    private let maxOffsetRatio: CGFloat = 0.95

    init(isReviewWord: Bool, onToggleReview: @escaping () -> Void, onTap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isReviewWord = isReviewWord
        self.onToggleReview = onToggleReview
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        let shouldShowBackground = dragOffset != 0 || didCommit

        ZStack {
            HStack {
                // Reserved for future left actions.
                Spacer()
                ReviewBackgroundView(
                    progress: progress,
                    isReviewWord: isReviewWord,
                    commitIcon: commitIcon
                )
                .frame(width: actionWidth)
                .opacity(shouldShowBackground ? 1 : 0)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .offset(x: dragOffset)
        }
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ReviewSwipeRowWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(ReviewSwipeRowWidthKey.self) { value in
            rowWidth = value
        }
        .highPriorityGesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.width) <= abs(value.translation.height) {
                        return
                    }
                    didDragHorizontally = true
                    let translation = min(0, value.translation.width)
                    let maxOffset = actionWidth * 1.15
                    dragOffset = max(translation, -maxOffset)
                    let threshold = actionWidth * 0.55
                    progress = min(1, abs(dragOffset) / max(1, threshold))
                }
                .onEnded { value in
                    if abs(value.translation.width) <= abs(value.translation.height) {
                        reset()
                        return
                    }
                    let translation = min(0, value.translation.width)
                    let threshold = actionWidth * 0.55
                    if translation <= -threshold {
                        onToggleReview()
                        commitFeedback(isRemoving: isReviewWord)
                    }
                    reset()
                    scheduleDragReset()
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if didDragHorizontally {
                        return
                    }
                    onTap()
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

    private func commitFeedback(isRemoving: Bool) {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        commitIcon = isRemoving ? "book.slash.fill" : "checkmark.circle.fill"
        didCommit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            didCommit = false
            commitIcon = nil
        }
    }
}

private struct ReviewBackgroundView: View {
    let progress: CGFloat
    let isReviewWord: Bool
    let commitIcon: String?

    var body: some View {
        let isArmed = progress >= 1
        let baseColor = isReviewWord ? Color.secondary : Color.orange
        let fillOpacity = 0.18 + (0.3 * progress)
        let iconScale = 0.9 + (0.3 * progress)
        let iconOpacity = 0.6 + (0.4 * progress)

        VStack(spacing: 4) {
            Image(systemName: commitIcon ?? "book.fill")
                .font(.system(size: 16, weight: .semibold))
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
            Text("복습")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(baseColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(baseColor.opacity(fillOpacity))
        .overlay(
            Capsule()
                .stroke(baseColor.opacity(isArmed ? 0.6 : 0.3), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct ReviewSwipeRowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
