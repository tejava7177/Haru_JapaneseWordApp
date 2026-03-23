import SwiftUI

struct CreateNotebookView: View {
    @ObservedObject var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var descriptionText: String = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("새 단어장 정보를 입력해 주세요.")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("이름")
                        .font(.subheadline.weight(.semibold))

                    TextField("예: N3 문법 표현", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("설명")
                        .font(.subheadline.weight(.semibold))
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))

                        if trimmedDescription.isEmpty {
                            Text("예: 자주 헷갈리는 표현을 정리한 단어장이에요")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                        }

                        TextEditor(text: $descriptionText)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(minHeight: 120)
                            .background(Color.clear)
                    }
                }

                Button("생성") {
                    store.addNotebook(
                        title: trimmedTitle,
                        descriptionText: trimmedDescription.isEmpty ? nil : trimmedDescription
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedTitle.isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("단어장 생성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreateNotebookView(store: NotebookStore(userDefaults: UserDefaults(suiteName: "CreateNotebookView.preview")!))
}
