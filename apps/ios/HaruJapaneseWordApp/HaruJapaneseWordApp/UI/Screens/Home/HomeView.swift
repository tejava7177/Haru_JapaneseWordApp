import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let repository: DictionaryRepository
    private let settingsStore: AppSettingsStore

    init(repository: DictionaryRepository, settingsStore: AppSettingsStore) {
        self.repository = repository
        self.settingsStore = settingsStore
        _viewModel = StateObject(wrappedValue: HomeViewModel(repository: repository, settingsStore: settingsStore))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("오늘의 추천")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if viewModel.cards.isEmpty == false {
                        TabView(selection: $viewModel.selectedIndex) {
                            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, word in
                                cardView(for: word)
                                    .tag(index)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .frame(height: 290)
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .indexViewStyle(.page(backgroundDisplayMode: .always))

                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("오늘의 추천을 준비 중입니다.")
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
            .navigationDestination(for: Int.self) { wordId in
                WordDetailView(wordId: wordId, repository: repository)
            }
        }
        .task {
            viewModel.loadDeck()
        }
        .alert("준비 중", isPresented: $viewModel.isShowingAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    @ViewBuilder
    private func cardView(for word: WordSummary) -> some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink(value: word.id) {
                VStack(alignment: .leading, spacing: 12) {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 36)
                .contentShape(Rectangle())
                .padding(18)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.sendPokePlaceholder(wordId: word.id)
            } label: {
                Label("콕 전송하기", systemImage: "paperplane.fill")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .padding(18)
        }
    }
}

#Preview {
    HomeView(repository: StubDictionaryRepository(), settingsStore: AppSettingsStore())
}
