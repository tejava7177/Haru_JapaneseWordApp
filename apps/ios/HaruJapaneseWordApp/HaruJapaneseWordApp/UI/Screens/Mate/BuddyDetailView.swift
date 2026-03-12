import SwiftUI

struct BuddyDetailView: View {
    @StateObject private var viewModel: BuddyDetailViewModel

    init(viewModel: BuddyDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                errorStateView(message: errorMessage)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerView

                        if let nonFatalMessage = viewModel.nonFatalMessage {
                            Text(nonFatalMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                )
                        }

                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.items) { item in
                                BuddyWordRow(
                                    item: item,
                                    onTap: {
                                        viewModel.selectItem(item)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle(viewModel.buddyName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            if viewModel.items.isEmpty {
                viewModel.load()
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .alert(viewModel.userAlert?.title ?? "안내", isPresented: userAlertBinding) {
            Button("확인") {
                viewModel.userAlert = nil
            }
        } message: {
            Text(viewModel.userAlert?.message ?? "")
        }
        .alert("안내", isPresented: errorAlertBinding) {
            Button("확인") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let message = viewModel.sendSuccessMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    )
                    .padding(.top, 12)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(clampedProgressCount)/\(resolvedProgressGoal)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 12)

                    if viewModel.targetDateText.isEmpty == false {
                        Text(viewModel.targetDateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TsunTsunProgressGauge(
                    currentCount: clampedProgressCount,
                    goal: resolvedProgressGoal
                )

                if viewModel.receivedCount > 0 {
                    Text("받은 츤츤 \(viewModel.receivedCount)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )

            if isPerfectCompletion {
                HStack(spacing: 8) {
                    Text("🎉")
                    Text("오늘의 츤츤 완료!")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.4), value: clampedProgressCount)
        .animation(.easeInOut(duration: 0.4), value: isPerfectCompletion)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.sendTsunTsun()
            } label: {
                HStack {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("つんつん 보내기")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(viewModel.canSendSelectedItem ? Color.black : Color(uiColor: .systemGray3))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(viewModel.canSendSelectedItem == false)

            if let pendingAnswerMessage = viewModel.pendingAnswerMessage {
                Text(pendingAnswerMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Text("Buddy 상세를 불러오지 못했어요")
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension BuddyDetailView {
    var resolvedProgressGoal: Int {
        max(viewModel.progressGoal, 1)
    }

    var clampedProgressCount: Int {
        min(max(viewModel.progressCount, 0), resolvedProgressGoal)
    }

    var isPerfectCompletion: Bool {
        viewModel.pairCompletedToday && clampedProgressCount == resolvedProgressGoal
    }
}

private struct TsunTsunProgressGauge: View {
    let currentCount: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<goal, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < currentCount ? Color.black : Color(uiColor: .systemGray5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)
                    .scaleEffect(y: index < currentCount ? 1 : 0.88)
                    .animation(.easeInOut(duration: 0.4), value: currentCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오늘 츤츤 진행도")
        .accessibilityValue("\(currentCount)/\(goal)")
    }
}

private struct BuddyWordRow: View {
    let item: BuddyWordItemUIModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.expression)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(item.level.title)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(levelBadgeColor)
                            .clipShape(Capsule(style: .continuous))
                    }

                    Text(item.reading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if item.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(item.isSelected ? Color.blue.opacity(0.75) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(item.isSelectable == false)
        .opacity(item.isSelectable ? 1 : 0.92)
    }

    private var accentColor: Color {
        switch (item.direction, item.status) {
        case (.sent, .answered):
            return .mint
        case (.sent, .sent):
            return .blue
        case (.received, _):
            return .orange
        default:
            return item.isSelected ? .blue : Color(uiColor: .systemGray4)
        }
    }

    private var backgroundColor: Color {
        switch (item.direction, item.status) {
        case (.sent, .answered):
            return Color.mint.opacity(0.14)
        case (.sent, .sent):
            return Color.blue.opacity(0.12)
        case (.received, _):
            return Color.orange.opacity(0.12)
        default:
            return item.isSelected ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemBackground)
        }
    }

    private var levelBadgeColor: Color {
        switch item.level {
        case .n1:
            return .blue.opacity(0.12)
        case .n2:
            return .teal.opacity(0.14)
        case .n3:
            return .green.opacity(0.14)
        case .n4:
            return .orange.opacity(0.16)
        case .n5:
            return Color(uiColor: .systemGray5)
        }
    }
}

private extension BuddyDetailView {
    var userAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.userAlert != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.userAlert = nil
                }
            }
        )
    }

    var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.items.isEmpty == false && viewModel.nonFatalMessage == nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        BuddyDetailView(
            viewModel: BuddyDetailViewModel(
                buddyId: "2",
                buddyName: "Buddy",
                settingsStore: AppSettingsStore(),
                service: BuddyAPIServicePreviewStub()
            )
        )
    }
}

private struct BuddyAPIServicePreviewStub: BuddyAPIServiceProtocol {
    func fetchDailyWords(userId: String) async throws -> DailyWordsTodayResponse {
        DailyWordsTodayResponse(
            userId: Int(userId),
            targetDate: "2026-03-12",
            level: "N4",
            items: [
                DailyWordsTodayItemResponse(dailyWordItemId: 41, wordId: 390, expression: "オートバイ", reading: "オートバイ", level: "N4", orderIndex: 1),
                DailyWordsTodayItemResponse(dailyWordItemId: 42, wordId: 217, expression: "やさしい", reading: "やさしい", level: "N4", orderIndex: 2),
                DailyWordsTodayItemResponse(dailyWordItemId: 43, wordId: 121, expression: "雲", reading: "くも", level: "N4", orderIndex: 3)
            ]
        )
    }

    func fetchTsunTsunToday(userId: String, buddyId: String) async throws -> TsunTsunTodayResponse {
        TsunTsunTodayResponse(
            userId: Int(userId),
            buddyId: Int(buddyId),
            targetDate: "2026-03-12",
            sentCount: 2,
            receivedCount: 0,
            progressCount: 1,
            progressGoal: 10,
            pairCompletedToday: false,
            items: [
                TsunTsunTodayItemResponse(dailyWordItemId: 41, wordId: 390, direction: .sent, status: .answered),
                TsunTsunTodayItemResponse(dailyWordItemId: 42, wordId: 217, direction: .sent, status: .sent)
            ]
        )
    }

    func sendTsunTsun(senderId: String, receiverId: String, dailyWordItemId: Int) async throws -> SendTsunTsunResponse? {
        SendTsunTsunResponse(success: true, message: "ok")
    }

    func fetchTsunTsunInbox(userId: String) async throws -> TsunTsunInboxResponse {
        TsunTsunInboxResponse(userId: 1, unansweredCount: 0, items: [])
    }

    func answerTsunTsun(tsuntsunId: Int, meaningId: Int) async throws -> AnswerTsunTsunResponse {
        AnswerTsunTsunResponse(
            tsuntsunId: tsuntsunId,
            success: true,
            message: "ok",
            isCorrect: true,
            correctMeaningId: meaningId,
            correctText: nil,
            selectedMeaningId: meaningId,
            selectedText: nil,
            remainingUnansweredCount: 0
        )
    }
}
