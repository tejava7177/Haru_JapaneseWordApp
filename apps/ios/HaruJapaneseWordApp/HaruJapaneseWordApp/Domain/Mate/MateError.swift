import Foundation

enum MateError: Error, Equatable {
    case invalidInviteCode
    case cannotJoinOwnInvite
    case myMateLimitReached
    case ownerMateLimitReached
    case duplicateActiveMate
    case roomCreationFailed
    case roomNotFound
    case unauthorizedRoomAccess

    var userMessage: String {
        switch self {
        case .invalidInviteCode:
            return "유효하지 않은 초대코드예요."
        case .cannotJoinOwnInvite:
            return "내 초대코드는 사용할 수 없어요."
        case .myMateLimitReached:
            return "동행은 최대 3명까지 가능해요."
        case .ownerMateLimitReached:
            return "상대방의 동행 수가 이미 가득 찼어요."
        case .duplicateActiveMate:
            return "이미 연결된 동행이에요."
        case .roomCreationFailed:
            return "동행을 시작하지 못했어요. 다시 시도해 주세요."
        case .roomNotFound:
            return "동행 방을 찾을 수 없어요."
        case .unauthorizedRoomAccess:
            return "해당 동행 방을 종료할 권한이 없어요."
        }
    }
}
