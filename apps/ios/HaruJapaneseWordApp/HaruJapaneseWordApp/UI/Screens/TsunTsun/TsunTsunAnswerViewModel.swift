import Foundation
import Combine

@MainActor
final class TsunTsunAnswerViewModel: ObservableObject {
    @Published var selectedMeaningId: Int?
    @Published private(set) var submittedMeaningId: Int?
    @Published private(set) var correctMeaningId: Int?
    @Published private(set) var isCorrect: Bool?
    @Published private(set) var submissionMessage: String?
    @Published private(set) var isSubmitting: Bool = false
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
        selectedMeaningId != nil && isSubmitting == false && hasSubmitted == false
    }

    var hasAnsweredSuccessfully: Bool {
        hasSubmitted
    }

    var hasSubmitted: Bool {
        submittedMeaningId != nil
    }

    var effectiveCorrectMeaningId: Int? {
        correctMeaningId ?? item.choices.first(where: { $0.meaningId == submittedMeaningId })?.meaningId
    }

    var selectedChoiceText: String? {
        let meaningId = submittedMeaningId ?? selectedMeaningId
        guard let meaningId else { return nil }
        return item.choices.first(where: { $0.meaningId == meaningId })?.text
    }

    var correctChoiceText: String? {
        guard let effectiveCorrectMeaningId else { return nil }
        return item.choices.first(where: { $0.meaningId == effectiveCorrectMeaningId })?.text
    }

    var feedbackText: String? {
        guard hasSubmitted else { return nil }

        if let submissionMessage, submissionMessage.isEmpty == false {
            return submissionMessage
        }

        if submittedMeaningId == -1 {
            return "정답을 확인하고 바로 다음 츤츤을 보내보세요."
        }

        switch isCorrect {
        case true:
            return "정답이에요."
        case false:
            return "정답을 확인했어요."
        case nil:
            return "답변을 보냈어요."
        }
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
                applySubmission(from: response, selectedMeaningId: selectedMeaningId)
                NotificationCenter.default.post(name: .tsunTsunInboxDidChange, object: nil)
                isSubmitting = false
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func applySubmission(
        from response: AnswerTsunTsunResponse,
        selectedMeaningId: Int
    ) {
        submittedMeaningId = response.selectedMeaningId ?? selectedMeaningId
        correctMeaningId = response.correctMeaningId
        isCorrect = response.isCorrect
        submissionMessage = response.message
    }
}
