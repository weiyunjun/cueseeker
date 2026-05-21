import Foundation

extension Notification.Name {
    static let topbarSearchSubmitted = Notification.Name("CueSeekerTopbarSearchSubmitted")
    static let topbarSearchFocusChanged = Notification.Name("CueSeekerTopbarSearchFocusChanged")
    static let topbarSearchFocusClearRequested = Notification.Name("CueSeekerTopbarSearchFocusClearRequested")
    static let topbarDismissMenusRequested = Notification.Name("CueSeekerTopbarDismissMenusRequested")
    static let topbarTitlebarZoomRequested = Notification.Name("CueSeekerTopbarTitlebarZoomRequested")
}

@MainActor
final class TopbarSearchInputState: ObservableObject {
    @Published var draft = ""
    @Published var isFocused = false
    @Published private(set) var forcedTextUpdateID = 0

    func submit() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft != trimmedDraft {
            draft = trimmedDraft
            forcedTextUpdateID += 1
        }
        NotificationCenter.default.post(name: .topbarSearchSubmitted, object: trimmedDraft)
    }

    func clearDraft() {
        guard !draft.isEmpty else {
            return
        }

        draft = ""
        forcedTextUpdateID += 1
    }

    func requestFocus(_ focused: Bool) {
        guard isFocused != focused else {
            return
        }

        isFocused = focused
    }
}
