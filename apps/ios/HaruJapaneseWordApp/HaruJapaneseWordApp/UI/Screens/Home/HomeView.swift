import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let repository: DictionaryRepository

    init(repository: DictionaryRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: HomeViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("오늘의 한 단어")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let word = viewModel.todayWord {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(word.expression)
                                .font(.largeTitle)
                                .fontWeight(.semibold)

                            if word.reading.isEmpty == false {
                                Text(word.reading)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            if word.meanings.isEmpty == false {
                                Text(word.meanings)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            NavigationLink {
                                WordDetailView(wordId: word.id, repository: repository)
                            } label: {
                                Text("자세히 보기")
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("오늘의 단어를 준비 중입니다.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
            .navigationTitle("하루")
        }
        .task {
            viewModel.loadTodayWord()
        }
    }
}

#Preview {
    HomeView(repository: StubDictionaryRepository())
}
