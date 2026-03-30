import SwiftUI

struct InviteSectionView: View {
    @Binding var isExpanded: Bool
    let myInviteCode: String
    @Binding var inviteCodeInput: String
    let onShowInviteCode: () -> Void
    let onCopyInviteCode: () -> Void
    let onJoin: (String) -> Void
    let isBusy: Bool
    let errorMessage: String?
    @State private var hasAttemptedSubmit: Bool = false
    @State private var shouldRenderContent: Bool = false
    @State private var isClosingCollapsed: Bool = false
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.985

    private let expandDuration: Double = 0.22
    private let fadeOutDuration: Double = 0.14
    private let collapseDuration: Double = 0.18

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            contentArea
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
        )
        .onChange(of: inviteCodeInput) { _, _ in
            hasAttemptedSubmit = false
        }
        .onAppear {
            if isExpanded {
                shouldRenderContent = true
                contentOpacity = 1
                contentScale = 1
                isClosingCollapsed = false
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            updateExpansionState(expanded)
        }
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .overlay(Color(uiColor: .separator).opacity(0.18))
                .opacity(shouldRenderContent ? 1 : 0)
                .padding(.top, shouldRenderContent ? 12 : 0)

            contentWrapper
        }
        .animation(.easeInOut(duration: expandDuration), value: shouldRenderContent)
        .animation(.easeInOut(duration: fadeOutDuration), value: contentOpacity)
        .animation(.easeInOut(duration: fadeOutDuration), value: contentScale)
        .animation(.easeInOut(duration: collapseDuration), value: isClosingCollapsed)
    }

    private var contentWrapper: some View {
        Group {
            if shouldRenderContent {
                inviteContent
                    .padding(.top, isClosingCollapsed ? 0 : 12)
                    .opacity(contentOpacity)
                    .scaleEffect(contentScale, anchor: .top)
            }
        }
        .frame(height: isClosingCollapsed ? 0 : nil, alignment: .top)
        .clipped()
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(isExpanded == false)
    }

    private var inviteContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            myInviteCodeBlock
            inviteCodeJoinBlock
        }
    }

    private var headerRow: some View {
        Button {
            if isExpanded == false, myInviteCode.isEmpty {
                onShowInviteCode()
            }

            isExpanded.toggle()
        } label: {
            HStack(spacing: 10) {
                Text("초대코드")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: expandDuration), value: isExpanded)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var myInviteCodeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("내 초대코드")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Group {
                    if myInviteCode.isEmpty {
                        Text("불러오는 중")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(myInviteCode)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(.primary)
                    }
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

                Button {
                    onCopyInviteCode()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(
                    Circle()
                        .fill(Color(uiColor: .systemBackground).opacity(0.9))
                )
                .disabled(isBusy || myInviteCode.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
        }
    }

    private var inviteCodeJoinBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("초대 코드 입력")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("초대 코드 입력", text: $inviteCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .submitLabel(.go)
                .onSubmit {
                    handleJoin()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                )
                .disabled(isBusy)

            Button("연결") {
                handleJoin()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black)
            )
            .foregroundStyle(Color.white)
            .disabled(isBusy)

            if let visibleErrorMessage {
                Text(visibleErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var visibleErrorMessage: String? {
        let trimmedInput = inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard hasAttemptedSubmit else { return nil }

        if trimmedInput.isEmpty {
            return "초대 코드를 입력해 주세요."
        }

        guard let errorMessage, errorMessage.isEmpty == false else { return nil }
        return errorMessage
    }

    private func handleJoin() {
        hasAttemptedSubmit = true

        let trimmedInput = inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInput.isEmpty == false else { return }

        onJoin(inviteCodeInput)
    }

    private func updateExpansionState(_ expanded: Bool) {
        if expanded {
            shouldRenderContent = true
            isClosingCollapsed = false
            contentScale = 0.985
            contentOpacity = 0

            DispatchQueue.main.async {
                guard isExpanded else { return }
                contentOpacity = 1
                contentScale = 1
            }
        } else {
            contentOpacity = 0
            contentScale = 0.985

            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                guard isExpanded == false else { return }

                isClosingCollapsed = true

                DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration) {
                    guard isExpanded == false else { return }
                    shouldRenderContent = false
                    isClosingCollapsed = false
                }
            }
        }
    }
}
