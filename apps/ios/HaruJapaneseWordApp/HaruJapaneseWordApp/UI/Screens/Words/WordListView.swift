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
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    Spacer()
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
                } else if viewModel.enabledLevels.isEmpty {
                    Text("선택된 레벨이 없어요.")
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
                    .refreshable {
                        await viewModel.shuffleByPull()
                    }
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
                Form {
                    Section {
                        Toggle("전체", isOn: Binding(
                            get: { viewModel.isAllEnabled },
                            set: { viewModel.toggleAllLevels($0) }
                        ))
                    }

                    Section("범위 선택") {
                        VStack(alignment: .leading, spacing: 12) {
                            if viewModel.availableLevels.isEmpty {
                                Text("사용 가능한 레벨이 없습니다.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availableLevels, id: \.self) { level in
                                        LevelToggleButton(
                                            title: level.title,
                                            isOn: viewModel.enabledLevels.contains(level)
                                        ) {
                                            viewModel.toggleLevel(level)
                                        }
                                    }
                                }
                            }
                        }
                        .disabled(viewModel.isAllEnabled)
                    }
                }
                .navigationTitle("레벨 필터")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") {
                            isRangeSheetPresented = false
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isShuffling {
                ShuffleHUD()
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
    }
}

private struct LevelToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isOn ? .white : .primary)
                .background(isOn ? Color.black : Color.black.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ShuffleHUD: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shuffle")
                .rotationEffect(isAnimating ? .degrees(360) : .degrees(0))
                .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            Text("단어를 셔플합니다.")
                .font(.footnote)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

#Preview {
    WordListView(repository: StubDictionaryRepository())
}
