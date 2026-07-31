import AppKit
import CueSeekerCore

enum CueClipboard {
    static func copy(
        _ text: String,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard !text.isEmpty else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    static func copyDeepLink(
        cueText: String,
        cueID: Int64,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard let deepLink = CueDeepLink.markdownLink(
            cueText: cueText,
            cueID: cueID
        ) else {
            return false
        }
        return copy(deepLink, to: pasteboard)
    }
}
