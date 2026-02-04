import SwiftUI

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guideSection(
                        title: "하루 1분이면 충분해요",
                        items: [
                            "Home에서 오늘의 추천 카드 3장을 넘겨보세요.",
                            "마음에 드는 단어에 ✓를 눌러 학습 표시를 해요.",
                            "학습한 단어는 7일 동안 추천에서 잠시 쉬어요."
                        ]
                    )

                    guideSection(
                        title: "오늘의 추천은 하루 동안 유지돼요",
                        items: [
                            "오늘의 3장 덱은 하루 동안 고정돼요.",
                            "덱 새로고침은 하루 최대 2회예요.",
                            "덱 레벨을 바꾸면 다음 날부터 적용돼요."
                        ]
                    )

                    guideSection(
                        title: "Words는 사전처럼 사용해요",
                        items: [
                            "레벨별 단어를 모두 살펴볼 수 있어요.",
                            "검색으로 표기나 읽기를 빠르게 찾을 수 있어요.",
                            "자세히 보기에서 뜻을 다시 확인해요."
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
