import Foundation
import Combine

@MainActor
final class TsunTsunAnswerViewModel: ObservableObject {
    struct SubmissionResult: Equatable {
        let title: String
        let detail: String
        let correctText: String?
        let selectedText: String?
        let isCorrect: Bool?
    }

    @Published var selectedMeaningId: Int?
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var submissionResult: SubmissionResult?
    @Published var errorMessage: String?

    let item: TsunTsunInboxItemResponse

    private let service: BuddyAPIServiceProtocol

    init(
        item: TsunTsunInboxItemResponse,
        service: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.item = item
        self.service = service
    }

    var canSubmit: Bool {
        selectedMeaningId != nil && isSubmitting == false && submissionResult == nil
    }

    var hasAnsweredSuccessfully: Bool {
        submissionResult != nil
    }

    func submitAnswer() {
        guard let selectedMeaningId, canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await service.answerTsunTsun(
                    tsuntsunId: item.tsuntsunId,
                    meaningId: selectedMeaningId
                )
                submissionResult = makeSubmissionResult(from: response, selectedMeaningId: selectedMeaningId)
                NotificationCenter.default.post(name: .tsunTsunInboxDidChange, object: nil)
                isSubmitting = false
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func makeSubmissionResult(
        from response: AnswerTsunTsunResponse,
        selectedMeaningId: Int
    ) -> SubmissionResult {
        let selectedChoice = item.choices.first(where: { $0.meaningId == selectedMeaningId })
        let correctChoice = item.choices.first(where: { $0.meaningId == response.correctMeaningId })
        let selectedText = response.selectedText ?? selectedChoice?.text
        let correctText = response.correctText ?? correctChoice?.text

        if response.isCorrect == true {
            return SubmissionResult(
                title: "정답이에요",
                detail: response.message ?? "뜻을 정확히 맞혔어요.",
                correctText: correctText,
                selectedText: selectedText,
                isCorrect: true
            )
        }

        if selectedMeaningId == -1 {
            return SubmissionResult(
                title: "모르겠어요로 답했어요",
                detail: response.message ?? "정답을 확인하고 다음 츤츤으로 넘어가세요.",
                correctText: correctText,
                selectedText: selectedText,
                isCorrect: response.isCorrect
            )
        }

        if response.isCorrect == false {
            return SubmissionResult(
                title: "오답이에요",
                detail: response.message ?? "정답을 확인하고 다시 익혀보세요.",
                correctText: correctText,
                selectedText: selectedText,
                isCorrect: false
            )
        }

        return SubmissionResult(
            title: "답변을 보냈어요",
            detail: response.message ?? "목록으로 돌아가면 받은 츤츤이 갱신돼요.",
            correctText: correctText,
            selectedText: selectedText,
            isCorrect: response.isCorrect
        )
    }
}
