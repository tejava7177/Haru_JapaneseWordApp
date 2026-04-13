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
        .background(Color.appBackground)
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
            Text(viewModel.item.senderName.isEmpty ? "버디가 날린 꽃잎" : "\(viewModel.item.senderName)이 날린 꽃잎")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.item.expression)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                if viewModel.quizType == .meaning, viewModel.item.reading.isEmpty == false {
                    Text(viewModel.item.reading)
                        .font(.title3)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Text(viewModel.typeHintText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chipActive)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.brandSoft)
                )

            Text(viewModel.promptText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)

            if viewModel.item.targetDate.isEmpty == false {
                Text(viewModel.item.targetDate)
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle(cornerRadius: 18, shadowRadius: 8, shadowY: 2)
    }

    private var choicesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("보기")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)

            ForEach(viewModel.item.choices) { choice in
                Button {
                    viewModel.selectedChoiceId = choice.choiceId
                    print("[TsunTsun] choice selected choiceId=\(choice.choiceId)")
                } label: {
                    HStack(spacing: 12) {
                        choiceIndicator(for: choice)

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
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 6)
            }

            if viewModel.hasSubmitted {
                resultSummaryView
                    .padding(.top, 8)
            }
        }
    }

    private var resultSummaryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let feedbackText = viewModel.feedbackText {
                Text(feedbackText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            if let selectedChoiceText = viewModel.selectedChoiceText {
                Text("선택한 답: \(selectedChoiceText)")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }

            if let correctChoiceText = viewModel.correctChoiceText {
                Text("정답: \(correctChoiceText)")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .foregroundStyle(Color.ctaPrimaryText)
                .background(Color.ctaPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Button {
                    viewModel.submitAnswer()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(Color.ctaPrimaryText)
                        }
                        Text("답변 제출")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.canSubmit ? Color.ctaPrimaryText : Color.textSecondary)
                .background(viewModel.canSubmit ? Color.ctaPrimary : Color.ctaDisabled)
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
        canNavigateToBuddyDetail ? "\(senderDisplayName)에게 꽃잎 날리러 가기" : "도착한 꽃잎으로 돌아가기"
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
            return viewModel.selectedChoiceId == choice.choiceId ? .selected : .idle
        }

        let choiceId = choice.choiceId
        let submittedId = viewModel.submittedChoiceId
        let correctId = viewModel.effectiveCorrectChoiceId

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

    @ViewBuilder
    private func choiceIndicator(for choice: TsunTsunChoiceResponse) -> some View {
        Image(systemName: iconName(for: choice))
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(iconColor(for: choice))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(indicatorBackgroundColor(for: choice))
            )
            .overlay(
                Circle()
                    .stroke(indicatorBorderColor(for: choice), lineWidth: 1)
            )
    }

    private func backgroundColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return .surfacePrimary
        case .selected:
            return Color.brandSoft
        case .correct:
            return Color.successSoft
        case .incorrect:
            return Color.dangerSoft
        case .unknown:
            return Color.brandSoft.opacity(0.9)
        case .dimmed:
            return Color.surfaceSecondary
        }
    }

    private func borderColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return Color.divider
        case .selected:
            return Color.chipActive.opacity(0.7)
        case .correct:
            return Color.success.opacity(0.8)
        case .incorrect:
            return Color.danger.opacity(0.75)
        case .unknown:
            return Color.chipActive.opacity(0.6)
        case .dimmed:
            return Color.divider
        }
    }

    private func textColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .dimmed:
            return Color.textSecondary
        default:
            return Color.textPrimary
        }
    }

    private func iconColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return .iconSecondary
        case .selected:
            return .chipActive
        case .correct:
            return .success
        case .incorrect:
            return .danger
        case .unknown:
            return .chipActive
        case .dimmed:
            return .textTertiary
        }
    }

    private func indicatorBackgroundColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .idle:
            return .surfaceSecondary
        case .selected:
            return .brandSoft
        case .correct:
            return .successSoft
        case .incorrect:
            return .dangerSoft
        case .unknown:
            return .brandSoft
        case .dimmed:
            return .surfaceSecondary
        }
    }

    private func indicatorBorderColor(for choice: TsunTsunChoiceResponse) -> Color {
        switch visualState(for: choice) {
        case .selected:
            return .chipActive.opacity(0.75)
        case .correct:
            return .success.opacity(0.8)
        case .incorrect:
            return .danger.opacity(0.75)
        case .unknown:
            return .chipActive.opacity(0.6)
        case .idle, .dimmed:
            return .divider
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
                    type: .meaning,
                    expression: "紹介",
                    reading: "しょうかい",
                    targetDate: "2026-03-12",
                    choices: [
                        TsunTsunChoiceResponse(choiceId: 100, text: "소개"),
                        TsunTsunChoiceResponse(choiceId: 200, text: "발표"),
                        TsunTsunChoiceResponse(choiceId: 300, text: "변화"),
                        TsunTsunChoiceResponse(choiceId: -1, text: "모르겠어요")
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
    func fetchBuddies(userId: String) async throws -> [BuddySummaryResponse] {
        [
            BuddySummaryResponse(
                id: 13,
                userId: 1,
                buddyUserId: 2,
                buddyNickname: "buddy2",
                status: "ACTIVE",
                tikiTakaCount: 1
            )
        ]
    }

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

    func answerTsunTsun(tsuntsunId: Int, choiceId: Int) async throws -> AnswerTsunTsunResponse {
        AnswerTsunTsunResponse(
            tsuntsunId: tsuntsunId,
            success: true,
            message: choiceId == 100 ? "정답이에요." : "정답을 확인해 보세요.",
            isCorrect: choiceId == 100,
            correctChoiceId: 100,
            correctText: "소개",
            selectedChoiceId: choiceId,
            selectedText: nil,
            remainingUnansweredCount: 0
        )
    }
}
