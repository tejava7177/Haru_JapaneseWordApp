import Foundation
import Combine

@MainActor
final class TsunTsunAnswerViewModel: ObservableObject {
    @Published var selectedChoiceId: Int?
    @Published private(set) var submittedChoiceId: Int?
    @Published private(set) var correctChoiceId: Int?
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
        print("[TsunTsun] quiz type received type=\(item.type.rawValue) tsuntsunId=\(item.tsuntsunId)")
    }

    var canSubmit: Bool {
        selectedChoiceId != nil && isSubmitting == false && hasSubmitted == false
    }

    var hasAnsweredSuccessfully: Bool {
        hasSubmitted
    }

    var hasSubmitted: Bool {
        submittedChoiceId != nil
    }

    var effectiveCorrectChoiceId: Int? {
        correctChoiceId ?? item.choices.first(where: { $0.choiceId == submittedChoiceId })?.choiceId
    }

    var selectedChoiceText: String? {
        let choiceId = submittedChoiceId ?? selectedChoiceId
        guard let choiceId else { return nil }
        return item.choices.first(where: { $0.choiceId == choiceId })?.text
    }

    var correctChoiceText: String? {
        guard let effectiveCorrectChoiceId else { return nil }
        return item.choices.first(where: { $0.choiceId == effectiveCorrectChoiceId })?.text
    }

    var quizType: TsunTsunInboxItemResponse.QuizType {
        item.type
    }

    var typeHintText: String {
        switch quizType {
        case .meaning:
            return "뜻 문제"
        case .reading:
            return "읽기 문제"
        }
    }

    var promptText: String {
        switch quizType {
        case .meaning:
            return "다음 중 알맞은 뜻은?"
        case .reading:
            return "다음 중 올바른 읽기는?"
        }
    }

    var feedbackText: String? {
        guard hasSubmitted else { return nil }

        if let submissionMessage, submissionMessage.isEmpty == false {
            return submissionMessage
        }

        if submittedChoiceId == -1 {
            return "정답을 확인하고 다음 꽃잎을 날려보세요."
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
        guard let selectedChoiceId, canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await service.answerTsunTsun(
                    tsuntsunId: item.tsuntsunId,
                    choiceId: selectedChoiceId
                )
                applySubmission(from: response, selectedChoiceId: selectedChoiceId)
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
        selectedChoiceId: Int
    ) {
        submittedChoiceId = response.selectedChoiceId ?? selectedChoiceId
        correctChoiceId = response.correctChoiceId
        isCorrect = response.isCorrect
        submissionMessage = response.message
        print(
            "[TsunTsun] answer result selectedChoiceId=\(submittedChoiceId.map(String.init) ?? "nil") " +
            "correctChoiceId=\(correctChoiceId.map(String.init) ?? "nil")"
        )
    }
}
