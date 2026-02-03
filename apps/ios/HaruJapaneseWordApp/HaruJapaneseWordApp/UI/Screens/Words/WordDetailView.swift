import SwiftUI

struct WordDetailView: View {
    @StateObject private var viewModel: WordDetailViewModel

    init(wordId: Int, repository: DictionaryRepository) {
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(wordId: wordId, repository: repository))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 32)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)
            } else if let detail = viewModel.detail {
                VStack(alignment: .leading, spacing: 12) {
                    Text(detail.expression)
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text(detail.reading)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(detail.meaningsJoined)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .navigationTitle("단어 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
        }
    }
}

#Preview {
    WordDetailView(wordId: 1, repository: StubDictionaryRepository())
}
