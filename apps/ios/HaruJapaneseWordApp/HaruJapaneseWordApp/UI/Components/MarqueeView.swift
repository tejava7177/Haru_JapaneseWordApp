import SwiftUI

struct MarqueeView: View {
    let text: String
    let speed: Double
    let pause: Double

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animationToken = UUID()
    @State private var pendingWorkItem: DispatchWorkItem?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                if shouldScroll(containerWidth: width) {
                    Text(text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset)
                        .onAppear { restartScroll(containerWidth: width) }
                        .onChange(of: textWidth) { _ in restartScroll(containerWidth: width) }
                        .onChange(of: width) { _ in restartScroll(containerWidth: width) }
                } else {
                    Text(text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onAppear { offset = 0 }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onAppear { containerWidth = width }
            .onChange(of: width) { newValue in containerWidth = newValue }
            .background(measurementView)
        }
        .frame(height: 22)
        .onDisappear { cancelPending() }
    }

    private var measurementView: some View {
        Text(text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: MarqueeTextWidthKey.self, value: proxy.size.width)
                }
            )
            .hidden()
            .onPreferenceChange(MarqueeTextWidthKey.self) { value in
                textWidth = value
            }
    }

    private func shouldScroll(containerWidth: CGFloat) -> Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    private func restartScroll(containerWidth: CGFloat) {
        guard shouldScroll(containerWidth: containerWidth) else {
            animationToken = UUID()
            cancelPending()
            offset = 0
            return
        }

        let token = UUID()
        animationToken = token
        offset = containerWidth

        let distance = textWidth + containerWidth
        let duration = distance / max(speed, 1)

        cancelPending()
        let currentToken = token
        let startItem = DispatchWorkItem {
            guard self.animationToken == currentToken else { return }
            withAnimation(.linear(duration: duration)) {
                offset = -textWidth
            }
            let loopItem = DispatchWorkItem {
                guard self.animationToken == currentToken else { return }
                restartScroll(containerWidth: containerWidth)
            }
            pendingWorkItem = loopItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + pause, execute: loopItem)
        }
        pendingWorkItem = startItem
        DispatchQueue.main.asyncAfter(deadline: .now() + pause, execute: startItem)
    }

    private func cancelPending() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
