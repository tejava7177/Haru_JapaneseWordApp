import SwiftUI

struct TsunTsunAnswerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TsunTsunAnswerViewModel
    @State private var hasPropagatedAnswer: Bool = false
    @State private var isShowingBuddyDetail: Bool = false

    private let settingsStore: AppSettingsStore
    private let onAnswered: (Int) -> Void

    init(
        item: TsunTsunInboxItemResponse,
        settingsStore: AppSettingsStore,
        service: BuddyAPIServiceProtocol = BuddyAPIService(),
        onAnswered: @escaping (Int) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TsunTsunAnswerViewModel(item: item, service: service))
        self.settingsStore = settingsStore
        self.onAnswered = onAnswered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                choicesView
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
        .navigationDestination(isPresented: $isShowingBuddyDetail) {
            if let senderId = viewModel.item.senderId {
                BuddyDetailView(
                    viewModel: BuddyDetailViewModel(
                        buddyId: String(senderId),
                        buddyName: senderDisplayName,
                        settingsStore: settingsStore
                    )
                )
            }
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
                        Image(systemName: iconName(for: choice))
                            .foregroundStyle(iconColor(for: choice))

                        Text(choice.text)
                            .font(.body.weight(.medium))
                            .foregroundStyle(textColor(for: choice))

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(backgroundColor(for: choice))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor(for: choice), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.hasSubmitted)
            }

            if let feedbackText = viewModel.feedbackText, viewModel.hasSubmitted == false {
                Text(feedbackText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if viewModel.hasSubmitted {
                Button(primaryActionTitle) {
                    primaryAction()
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

    private var senderDisplayName: String {
        let trimmedName = viewModel.item.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            return trimmedName
        }
        return "버디"
    }

    private var canNavigateToBuddyDetail: Bool {
        viewModel.item.senderId != nil
    }

    private var primaryActionTitle: String {
        canNavigateToBuddyDetail ? "\(senderDisplayName)에게 츤츤 보내러 가기" : "받은 츤츤으로 돌아가기"
    }

    private func primaryAction() {
        propagateAnsweredIfNeeded()

        guard canNavigateToBuddyDetail else {
            dismiss()
            return
        }

        isShowingBuddyDetail = true
    }

    private func visualState(for choice: TsunTsunChoiceResponse) -> ChoiceVisualState {
        if viewModel.hasSubmitted == false {
            return viewModel.selectedMeaningId == choice.meaningId ? .selected : .idle
        }

        let choiceId = choice.meaningId
        let submittedId = viewModel.submittedMeaningId
        let correctId = viewModel.effectiveCorrectMeaningId

        if choiceId == correctId {
            return .correct
        }

        if submittedId == -1, choiceId == -1 {
            return .unknown
        }

        if choiceId == submittedId, submittedId != correctId {
            return .incorrect
        }

        return .dimmed
    }

    private func iconName(for choice: TsunTsunChoiceResponse) -> String {
        switch visualState(for: choice) {
        case .idle:
            return "circle"
        case .selected:
            return "largecircle.fill.circle"
        case .correct:
            return "checkmark.circle.fill"
        case .incorrect:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        case .dimmed:
            return "circle"
        }
    }

    private func backgroundColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return .white
        case .selected:
            return Color.orange.opacity(0.12)
        case .correct:
            return Color.mint.opacity(0.16)
        case .incorrect:
            return Color.red.opacity(0.12)
        case .unknown:
            return Color.orange.opacity(0.10)
        case .dimmed:
            return Color(uiColor: .systemGray6)
        }
    }

    private func borderColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return Color.black.opacity(0.06)
        case .selected:
            return Color.orange.opacity(0.45)
        case .correct:
            return Color.mint.opacity(0.55)
        case .incorrect:
            return Color.red.opacity(0.4)
        case .unknown:
            return Color.orange.opacity(0.35)
        case .dimmed:
            return Color.gray.opacity(0.18)
        }
    }

    private func textColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .dimmed:
            return Color.secondary
        default:
            return Color.primary
        }
    }

    private func iconColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return .secondary
        case .selected:
            return .orange
        case .correct:
            return .mint
        case .incorrect:
            return .red
        case .unknown:
            return .orange
        case .dimmed:
            return .gray
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

private extension TsunTsunAnswerView {
    enum ChoiceVisualState {
        case idle
        case selected
        case correct
        case incorrect
        case unknown
        case dimmed
    }
}

private struct TsunTsunAnswerPreviewContainer: View {
    private let settingsStore: AppSettingsStore = {
        let store = AppSettingsStore()
        store.signInForMateDevSlot(.A)
        return store
    }()

    var body: some View {
        NavigationStack {
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
                settingsStore: settingsStore,
                service: TsunTsunAnswerPreviewStub(),
                onAnswered: { _ in }
            )
        }
    }
}

#Preview {
    TsunTsunAnswerPreviewContainer()
}

private struct TsunTsunAnswerPreviewStub: BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        DailyWordsTodayResponse(userId: 1, targetDate: "2026-03-12", level: "N5", items: [])
    }

    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse {
        TsunTsunTodayResponse(
            userId: 1,
            buddyId: 2,
            targetDate: "2026-03-12",
            sentCount: 0,
            receivedCount: 1,
            progressCount: 0,
            progressGoal: 10,
            pairCompletedToday: false,
            items: []
        )
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
