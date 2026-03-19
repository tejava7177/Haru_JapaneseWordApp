import SwiftUI

struct CreateNotebookView: View {
    @ObservedObject var store: NotebookStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("새 단어장 이름을 입력해 주세요.")
                    .font(.headline)

                TextField("예: N3 문법 표현", text: $title)
                    .textFieldStyle(.roundedBorder)

                Button("생성") {
                    store.addNotebook(title: trimmedTitle)
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
