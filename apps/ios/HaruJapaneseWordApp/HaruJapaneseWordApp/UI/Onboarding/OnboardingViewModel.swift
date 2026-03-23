import Foundation
import Combine

final class OnboardingViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0

    let pages: [OnboardingPage]

    init(isBuddyEnabled: Bool) {
        var pages: [OnboardingPage] = [
            OnboardingPage(
                id: 0,
                title: "하루",
                description: [
                    "매일 10개의 일본어 단어를",
                    "가볍게 학습해보세요"
                ],
                supportingText: nil,
                mockKind: .dailyWords
            ),
            OnboardingPage(
                id: 1,
                title: "오늘의 추천 단어",
                description: [
                    "카드를 넘기며",
                    "새로운 단어를 학습할 수 있어요"
                ],
                supportingText: "체크하면 당분간 숨길 수 있어요",
                mockKind: .recommendationCard
            ),
            OnboardingPage(
                id: 2,
                title: "단어 탐색",
                description: [
                    "JLPT 레벨별 단어를",
                    "검색하고 복습할 수 있어요"
                ],
                supportingText: nil,
                mockKind: .search
            ),
            OnboardingPage(
                id: 3,
                title: "내 단어장",
                description: [
                    "직접 단어를 추가하고",
                    "나만의 단어장을 만들 수 있어요"
                ],
                supportingText: nil,
                mockKind: .notebook
            )
        ]

        if isBuddyEnabled {
            pages.append(
                OnboardingPage(
                    id: 4,
                    title: "Buddy",
                    description: [
                        "로그인하면 Buddy 기능으로",
                        "함께 단어를 주고받을 수 있어요"
                    ],
                    supportingText: "Buddy 기능은 로그인 상태일 때만 표시돼요",
                    mockKind: .buddy
                )
            )
        }

        self.pages = pages
    }

    var isLastPage: Bool {
        selectedIndex >= pages.count - 1
    }

    func moveToNextPage() {
        guard isLastPage == false else { return }
        selectedIndex += 1
    }
}
