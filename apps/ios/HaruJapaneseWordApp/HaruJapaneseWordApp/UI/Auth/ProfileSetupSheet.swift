import SwiftUI

struct ProfileSetupSheet: View {
    @Binding var nickname: String
    @Binding var jlptLevel: String
    let onComplete: (String, String) -> Void

    private let levels = JLPTLevel.allCases

    var body: some View {
        NavigationStack {
            Form {
                Section("프로필") {
                    TextField("닉네임", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("JLPT 레벨") {
                    Picker("레벨", selection: $jlptLevel) {
                        ForEach(levels) { level in
                            Text(level.title).tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("프로필 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        onComplete(trimmed, jlptLevel)
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
