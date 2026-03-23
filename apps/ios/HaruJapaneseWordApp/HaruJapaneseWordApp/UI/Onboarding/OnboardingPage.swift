import SwiftUI

struct OnboardingPage: Identifiable, Equatable {
    enum MockKind: Equatable {
        case recommendationCard
        case search
        case notebook
        case buddy
    }

    let id: Int
    let title: String
    let description: [String]
    let supportingText: String?
    let mockKind: MockKind
}
