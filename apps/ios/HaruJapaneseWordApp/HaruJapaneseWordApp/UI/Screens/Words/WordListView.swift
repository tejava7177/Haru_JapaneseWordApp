import SwiftUI

struct WordListView: View {
    @StateObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository
    @State private var isRangeSheetPresented: Bool = false

    init(repository: DictionaryRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        isRangeSheetPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("레벨: \(viewModel.selectedRange.displayName)")
                                .font(.callout)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        viewModel.shuffleDisplayedWords()
                    } label: {
                        Text("셔플")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.displayedWords) { word in
                        NavigationLink {
                            WordDetailView(wordId: word.id, repository: repository)
                        } label: {
                            WordRow(word: word)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("단어")
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "검색")
        .onChange(of: viewModel.searchText) { _ in
            viewModel.search()
        }
        .task {
            viewModel.load()
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            NavigationStack {
                List {
                    ForEach(viewModel.availableRanges) { range in
                        Button {
                            viewModel.selectedRange = range
                            isRangeSheetPresented = false
                        } label: {
                            HStack {
                                Text(range.displayName)
                                Spacer()
                                if range == viewModel.selectedRange {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("레벨 범위")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") {
                            isRangeSheetPresented = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    WordListView(repository: StubDictionaryRepository())
}
