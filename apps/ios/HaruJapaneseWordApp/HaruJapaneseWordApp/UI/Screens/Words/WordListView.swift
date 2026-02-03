import SwiftUI

struct WordListView: View {
    @StateObject private var viewModel: WordListViewModel
    private let repository: DictionaryRepository

    init(repository: DictionaryRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: WordListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("레벨", selection: $viewModel.selectedLevel) {
                    ForEach(JLPTLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
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
                    List(viewModel.words) { word in
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
        .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "검색")
        .onChange(of: viewModel.query) { _ in
            viewModel.search()
        }
        .task {
            viewModel.load()
        }
    }
}

#Preview {
    WordListView(repository: StubDictionaryRepository())
}
