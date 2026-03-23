import SwiftUI

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guideSection(
                        title: "하루 10단어로 가볍게 시작해요",
                        items: [
                            "오늘의 추천 단어 10개를 카드로 학습해요.",
                            "카드를 넘기며 자연스럽게 익힐 수 있어요.",
                            "체크하면 해당 단어는 당분간 보이지 않아요."
                        ]
                    )

                    guideSection(
                        title: "단어를 검색하고 복습해요",
                        items: [
                            "JLPT 레벨별 단어를 탐색할 수 있어요.",
                            "필터를 통해 원하는 단어만 볼 수 있어요.",
                            "복습 표시를 하면 다시 추천에 포함돼요."
                        ]
                    )

                    guideSection(
                        title: "나만의 단어장을 만들어보세요",
                        items: [
                            "직접 단어를 추가하고 관리할 수 있어요.",
                            "메모와 예문을 함께 기록할 수 있어요.",
                            "여러 개의 단어장을 만들 수 있어요."
                        ]
                    )

                    guideSection(
                        title: "빠르게 단어를 추가하세요",
                        items: [
                            "단어, 의미, 메모를 자유롭게 입력할 수 있어요.",
                            "저장 후 계속 버튼으로 연속 입력이 가능해요.",
                            "스와이프로 간편하게 삭제할 수 있어요."
                        ]
                    )

                    guideSection(
                        title: "복습 단어는 다시 나타나요",
                        items: [
                            "복습으로 설정한 단어는 추천에 다시 포함돼요.",
                            "학습 흐름 속에서 자연스럽게 반복돼요."
                        ]
                    )

                    guideSection(
                        title: "버디와 함께 학습해요",
                        items: [
                            "다른 사용자와 연결해 단어를 주고받을 수 있어요.",
                            "랜덤 매칭이나 초대코드로 연결할 수 있어요.",
                            "가볍게 티키타카하며 복습할 수 있어요."
                        ]
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("하루 사용법")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func guideSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    GuideView()
}
