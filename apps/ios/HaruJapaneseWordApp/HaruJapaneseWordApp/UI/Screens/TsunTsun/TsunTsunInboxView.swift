import SwiftUI

struct TsunTsunInboxView: View {
    @StateObject private var viewModel: TsunTsunInboxViewModel
    private let settingsStore: AppSettingsStore
    private let service: BuddyAPIServiceProtocol

    init(
        settingsStore: AppSettingsStore,
        service: BuddyAPIServiceProtocol = BuddyAPIService()
    ) {
        self.settingsStore = settingsStore
        self.service = service
        _viewModel = StateObject(
            wrappedValue: TsunTsunInboxViewModel(settingsStore: settingsStore, service: service)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                errorStateView(message: errorMessage)
            } else if viewModel.items.isEmpty {
                emptyStateView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        headerView

                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                TsunTsunAnswerView(item: item, settingsStore: settingsStore, service: service) { answeredId in
                                    viewModel.removeAnsweredItem(tsuntsunId: answeredId)
                                }
                            } label: {
                                TsunTsunInboxRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("받은 츤츤")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("답변이 필요한 츤츤만 모아봤어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.unansweredCountText)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyStateView() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("받은 츤츤이 없어요")
                .font(.headline)
            Text("새로 받은 츤츤이 생기면 여기에서 바로 답할 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Text("받은 츤츤을 불러오지 못했어요")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TsunTsunInboxRow: View {
    let item: TsunTsunInboxItemResponse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.8))
                .frame(width: 10, height: 10)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.senderName.isEmpty ? "버디" : item.senderName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 12)
                    Text(item.targetDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(item.expression)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if item.reading.isEmpty == false {
                        Text(item.reading)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("이 단어의 뜻을 알고 있나요?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("답하기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    let settingsStore = AppSettingsStore()
    settingsStore.signInForMateDevSlot(.A)
    return NavigationStack {
        // Mock preview data until the real inbox API is always available in development.
        TsunTsunInboxView(settingsStore: settingsStore, service: TsunTsunInboxPreviewStub())
    }
}

private struct TsunTsunInboxPreviewStub: BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        DailyWordsTodayResponse(userId: 1, targetDate: "2026-03-12", level: "N5", items: [])
    }

    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse {
        TsunTsunTodayResponse(userId: 1, buddyId: 2, targetDate: "2026-03-12", sentCount: 0, receivedCount: 2, items: [])
    }

    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse? {
        SendTsunTsunResponse(success: true, message: "ok")
    }

    func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse {
        TsunTsunInboxResponse(
            userId: 2,
            unansweredCount: 2,
            items: [
                TsunTsunInboxItemResponse(
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
                TsunTsunInboxItemResponse(
                    tsuntsunId: 10,
                    senderId: 3,
                    senderName: "사토",
                    wordId: 121,
                    expression: "準備",
                    reading: "じゅんび",
                    targetDate: "2026-03-11",
                    choices: [
                        TsunTsunChoiceResponse(meaningId: 400, text: "준비"),
                        TsunTsunChoiceResponse(meaningId: 500, text: "약속"),
                        TsunTsunChoiceResponse(meaningId: 600, text: "체험"),
                        TsunTsunChoiceResponse(meaningId: -1, text: "모르겠어요")
                    ]
                )
            ]
        )
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
            remainingUnansweredCount: 1
        )
    }
}
