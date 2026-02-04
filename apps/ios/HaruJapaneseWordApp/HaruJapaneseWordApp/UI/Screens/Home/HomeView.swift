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

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                viewModel.rerollDeck()
                            } label: {
                                Text("덱 새로고침 (남은 \(viewModel.remainingRerolls))")
                                    .font(.callout)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(viewModel.remainingRerolls > 0 ? .primary : .secondary)
                            .disabled(viewModel.remainingRerolls == 0)

                            if viewModel.remainingRerolls == 0 {
                                Text("오늘의 덱 새로고침을 모두 사용했어요.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    viewModel.toggleLearned(wordId: word.id)
                } label: {
                    Image(systemName: viewModel.learnedWordIds.contains(word.id) ? "checkmark.circle.fill" : "circle")
                        .font(.callout)
                        .foregroundStyle(viewModel.learnedWordIds.contains(word.id) ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("학습 체크")
            }

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

            HStack(spacing: 12) {
                NavigationLink {
                    WordDetailView(wordId: word.id, repository: repository)
                } label: {
                    Text("자세히 보기")
                        .font(.callout)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.sendPokePlaceholder(wordId: word.id)
                } label: {
                    Text("콕 전송하기")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    HomeView(repository: StubDictionaryRepository())
}
