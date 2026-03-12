import SwiftUI

struct TsunTsunAnswerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TsunTsunAnswerViewModel
    @State private var hasPropagatedAnswer: Bool = false

    private let onAnswered: (Int) -> Void

    init(
        item: TsunTsunInboxItemResponse,
        service: BuddyAPIServiceProtocol = BuddyAPIService(),
        onAnswered: @escaping (Int) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TsunTsunAnswerViewModel(item: item, service: service))
        self.onAnswered = onAnswered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                choicesView

                if let result = viewModel.submissionResult {
                    resultView(result)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("답변하기")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert("안내", isPresented: errorBinding) {
            Button("확인") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear {
            propagateAnsweredIfNeeded()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.item.senderName.isEmpty ? "버디가 보낸 츤츤" : "\(viewModel.item.senderName)이 보낸 츤츤")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.item.expression)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                if viewModel.item.reading.isEmpty == false {
                    Text(viewModel.item.reading)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Text("이 단어의 뜻을 알고 있나요?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if viewModel.item.targetDate.isEmpty == false {
                Text(viewModel.item.targetDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var choicesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("보기")
                .font(.headline)

            ForEach(viewModel.item.choices) { choice in
                Button {
                    viewModel.selectedMeaningId = choice.meaningId
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.selectedMeaningId == choice.meaningId ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(viewModel.selectedMeaningId == choice.meaningId ? .orange : .secondary)

                        Text(choice.text)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(viewModel.selectedMeaningId == choice.meaningId ? Color.orange.opacity(0.12) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.selectedMeaningId == choice.meaningId ? Color.orange.opacity(0.45) : Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.submissionResult != nil)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if viewModel.submissionResult != nil {
                Button("받은 츤츤으로 돌아가기") {
                    propagateAnsweredIfNeeded()
                    dismiss()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Button {
                    viewModel.submitAnswer()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("답변 제출")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(viewModel.canSubmit ? Color.black : Color(uiColor: .systemGray3))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(viewModel.canSubmit == false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func resultView(_ result: TsunTsunAnswerViewModel.SubmissionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.title)
                .font(.headline)
                .foregroundStyle(resultColor(for: result))

            Text(result.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let selectedText = result.selectedText {
                labeledValue(title: "내 답변", value: selectedText)
            }

            if let correctText = result.correctText {
                labeledValue(title: "정답 뜻", value: correctText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(resultColor(for: result).opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func labeledValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private func resultColor(for result: TsunTsunAnswerViewModel.SubmissionResult) -> Color {
        switch result.isCorrect {
        case true:
            return .green
        case false:
            return .orange
        case nil:
            return .blue
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private func propagateAnsweredIfNeeded() {
        guard viewModel.hasAnsweredSuccessfully, hasPropagatedAnswer == false else { return }
        hasPropagatedAnswer = true
        onAnswered(viewModel.item.tsuntsunId)
    }
}

#Preview {
    NavigationStack {
        // Mock preview data until the real answer API response is finalized.
        TsunTsunAnswerView(
            item: TsunTsunInboxItemResponse(
                tsuntsunId: 11,
                senderId: 1,
                senderName: "김민성",
                wordId: 390,
                expression: "紹介",
                reading: "しょうかい",
                targetDate: "2026-03-12",
                choices: [
                    TsunTsunChoiceResponse(meaningId: 100, text: "소개"),
                    TsunTsunChoiceResponse(meaningId: 200, text: "발표"),
                    TsunTsunChoiceResponse(meaningId: 300, text: "변화"),
                    TsunTsunChoiceResponse(meaningId: -1, text: "모르겠어요")
                ]
            ),
            service: TsunTsunAnswerPreviewStub(),
            onAnswered: { _ in }
        )
    }
}

private struct TsunTsunAnswerPreviewStub: BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        DailyWordsTodayResponse(userId: 1, targetDate: "2026-03-12", level: "N5", items: [])
    }

    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse {
        TsunTsunTodayResponse(userId: 1, buddyId: 2, targetDate: "2026-03-12", sentCount: 0, receivedCount: 1, items: [])
    }

    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse? {
        SendTsunTsunResponse(success: true, message: "ok")
    }

    func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse {
        TsunTsunInboxResponse(userId: 2, unansweredCount: 1, items: [])
    }

    func answerTsunTsun(tsuntsunId: Int, meaningId: Int) async throws -> AnswerTsunTsunResponse {
        AnswerTsunTsunResponse(
            tsuntsunId: tsuntsunId,
            success: true,
            message: meaningId == 100 ? "정답이에요." : "정답을 확인해 보세요.",
            isCorrect: meaningId == 100,
            correctMeaningId: 100,
            correctText: "소개",
            selectedMeaningId: meaningId,
            selectedText: nil,
            remainingUnansweredCount: 0
        )
    }
}
