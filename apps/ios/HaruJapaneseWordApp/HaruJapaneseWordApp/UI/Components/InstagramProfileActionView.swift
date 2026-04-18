import SwiftUI
import UIKit

enum InstagramProfileHelper {
    static func normalizedUsername(from rawValue: String?) -> String? {
        guard var candidate = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              candidate.isEmpty == false else {
            return nil
        }

        candidate = candidate.removingPercentEncoding ?? candidate

        if let url = URL(string: candidate),
           let host = url.host?.lowercased(),
           host.contains("instagram.com") {
            let pathComponents = url.pathComponents
                .filter { $0 != "/" && $0.isEmpty == false }

            if let firstComponent = pathComponents.first {
                candidate = firstComponent
            } else {
                return nil
            }
        } else {
            let lowercaseCandidate = candidate.lowercased()
            if let range = lowercaseCandidate.range(of: "instagram.com/") {
                candidate = String(candidate[range.upperBound...])
            }
        }

        if let firstSegment = candidate.split(whereSeparator: { "/?#".contains($0) }).first {
            candidate = String(firstSegment)
        }

        while candidate.hasPrefix("@") {
            candidate.removeFirst()
        }

        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? nil : candidate
    }

    static func displayHandle(from rawValue: String?) -> String? {
        guard let username = normalizedUsername(from: rawValue) else {
            return nil
        }

        return "@\(username)"
    }

    static func appURL(for username: String) -> URL? {
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        return URL(string: "instagram://user?username=\(encodedUsername)")
    }

    static func webURL(for username: String) -> URL? {
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        return URL(string: "https://instagram.com/\(encodedUsername)")
    }
}

struct InstagramProfileActionView<Label: View>: View {
    let rawValue: String
    let onCopySuccess: ((String) -> Void)?
    @ViewBuilder let label: (String) -> Label

    @Environment(\.openURL) private var openURL
    @State private var isDialogPresented: Bool = false

    init(
        rawValue: String,
        onCopySuccess: ((String) -> Void)? = nil,
        @ViewBuilder label: @escaping (String) -> Label
    ) {
        self.rawValue = rawValue
        self.onCopySuccess = onCopySuccess
        self.label = label
    }

    private var username: String? {
        InstagramProfileHelper.normalizedUsername(from: rawValue)
    }

    var body: some View {
        if let username {
            Button {
                isDialogPresented = true
            } label: {
                label("@\(username)")
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .confirmationDialog("@\(username)", isPresented: $isDialogPresented, titleVisibility: .visible) {
                Button("인스타그램 열기") {
                    openInstagramProfile(username: username)
                }

                Button("ID 복사") {
                    UIPasteboard.general.string = username
                    onCopySuccess?("인스타 ID를 복사했어요")
                }

                Button("취소", role: .cancel) { }
            }
            .accessibilityHint("탭해서 인스타그램 열기 또는 ID 복사를 선택할 수 있어요.")
        }
    }

    private func openInstagramProfile(username: String) {
        guard let appURL = InstagramProfileHelper.appURL(for: username) else {
            openInstagramWebProfile(username: username)
            return
        }

        openURL(appURL) { accepted in
            if accepted == false {
                openInstagramWebProfile(username: username)
            }
        }
    }

    private func openInstagramWebProfile(username: String) {
        guard let webURL = InstagramProfileHelper.webURL(for: username) else {
            return
        }

        openURL(webURL)
    }
}
