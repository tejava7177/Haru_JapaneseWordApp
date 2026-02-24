import Foundation
import SwiftUI
import Combine

@MainActor
final class MateViewModel: ObservableObject {
    @Published private(set) var state = MateHomeState(room: nil, myLearnedToday: false, mateLearnedToday: false, canPoke: false, shouldShowInactivityPrompt: false, inactivityDays: 0)
    @Published private(set) var isMateEnabled: Bool = false
    @Published private(set) var isSignedIn: Bool = false
    @Published var inputInviteCode: String = ""
    @Published var inputMateNickname: String = ""
    @Published var toastMessage: String = ""
    @Published var isShowingToast: Bool = false
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false

    let mateService: MateService
    private let settingsStore: AppSettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(mateService: MateService, settingsStore: AppSettingsStore) {
        self.mateService = mateService
        self.settingsStore = settingsStore
        self.isMateEnabled = settingsStore.settings.isMateEnabled
        self.isSignedIn = settingsStore.settings.isSignedIn

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.isMateEnabled = settings.isMateEnabled
                self?.isSignedIn = settings.isSignedIn
            }
            .store(in: &cancellables)
    }

    func load() {
        do {
            state = try mateService.loadHomeState()
        } catch {
            alertMessage = "Mate 정보를 불러오지 못했어요."
            isShowingAlert = true
        }
    }

    func enableMate() {
        settingsStore.updateMateEnabled(true)
        showToast("Mate를 켰어요.")
        load()
    }

    func disableMate() {
        settingsStore.updateMateEnabled(false)
        showToast("Mate를 끄면 카드가 숨겨져요.")
    }

    func startWithInvite() {
        let code = inputInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let nickname = inputMateNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.isEmpty == false else {
            showAlert("초대 코드를 입력해 주세요.")
            return
        }
        do {
            _ = try mateService.createRoomFromInvite(code: code, mateNickname: nickname.isEmpty ? "메이트" : nickname)
            inputInviteCode = ""
            inputMateNickname = ""
            showToast("동행이 시작됐어요. 부담 없이 가볍게!")
            load()
        } catch {
            showAlert("동행을 시작하지 못했어요.")
        }
    }

    #if DEBUG
    func startWithMock() {
        do {
            _ = try mateService.createRoomFromMock()
            showToast("테스트 Mate와 연결했어요.")
            load()
        } catch {
            showAlert("테스트 Mate 연결에 실패했어요.")
        }
    }
    #endif

    func endRoom() {
        guard let room = state.room else { return }
        do {
            try mateService.endRoom(room)
            load()
        } catch {
            showAlert("동행을 종료하지 못했어요.")
        }
    }

    func waitForMate() {
        mateService.markInactivityPromptShown()
        load()
    }

    func poke() async {
        let result = await mateService.pokeMate(level: settingsStore.settings.homeDeckLevel)
        showToast(result.message)
        load()
    }

    func inviteCode() -> String {
        mateService.currentInviteCode()
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.2)) {
                self.isShowingToast = false
            }
        }
    }
}
