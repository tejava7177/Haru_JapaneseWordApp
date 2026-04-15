import SwiftUI

struct WordDetailExplorerView: View {
    let items: [WordListItem]
    private let repository: DictionaryRepository
    @ObservedObject private var notebookStore: NotebookStore
    @ObservedObject private var settingsStore: AppSettingsStore

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(
        items: [WordListItem],
        initialIndex: Int,
        repository: DictionaryRepository,
        notebookStore: NotebookStore,
        settingsStore: AppSettingsStore? = nil
    ) {
        self.items = items
        self.repository = repository
        self._notebookStore = ObservedObject(wrappedValue: notebookStore)
        self._settingsStore = ObservedObject(wrappedValue: settingsStore ?? AppSettingsStore())
        let boundedIndex = min(max(initialIndex, 0), max(items.count - 1, 0))
        _currentIndex = State(initialValue: boundedIndex)
    }

    private var currentItem: WordListItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var body: some View {
        Group {
            if let currentItem {
                content(for: currentItem)
                    .id(currentItem.id)
                    .simultaneousGesture(navigationGesture)
            } else {
                ContentUnavailableView("단어를 찾을 수 없어요", systemImage: "text.book.closed")
            }
        }
        .onAppear {
            print("[WordDetailExplorer] currentIndex changed index=\(currentIndex)")
            logCurrentWord()
        }
        .onChange(of: currentIndex) { _, newValue in
            print("[WordDetailExplorer] currentIndex changed index=\(newValue)")
            logCurrentWord()
        }
    }

    @ViewBuilder
    private func content(for item: WordListItem) -> some View {
        switch item.source {
        case let .jlpt(_, wordId):
            WordDetailView(
                wordId: wordId,
                repository: repository,
                notebookStore: notebookStore,
                settingsStore: settingsStore
            )
        case let .notebook(notebookId, itemId):
            NotebookWordDetailView(
                store: notebookStore,
                notebookId: notebookId,
                itemId: itemId,
                repository: repository
            )
        }
    }

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if vertical > 140, abs(vertical) > abs(horizontal) * 1.25 {
                    print("[WordDetailExplorer] detail swipe dismiss")
                    dismiss()
                    return
                }

                guard abs(horizontal) > 90, abs(horizontal) > abs(vertical) * 1.2 else { return }

                if horizontal < 0 {
                    moveNext()
                } else {
                    movePrevious()
                }
            }
    }

    private func moveNext() {
        guard currentIndex < items.count - 1 else { return }
        print("[WordDetailExplorer] detail swipe next")
        withAnimation(.easeInOut(duration: 0.18)) {
            currentIndex += 1
        }
    }

    private func movePrevious() {
        guard currentIndex > 0 else { return }
        print("[WordDetailExplorer] detail swipe previous")
        withAnimation(.easeInOut(duration: 0.18)) {
            currentIndex -= 1
        }
    }

    private func logCurrentWord() {
        guard let currentItem else { return }
        print("[WordDetailExplorer] currentWord changed id=\(currentItem.id)")
    }
}
