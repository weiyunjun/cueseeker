import AppKit
import SwiftUI

/// The view a menu's content is hosted in.
///
/// A menu owns the wheel while the pointer is on it. Content that can scroll —
/// a long destination list — sees the event first and scrolls with it; once
/// that content reaches its end the event arrives here and stops, instead of
/// travelling on to the page underneath the menu.
final class MenuHostingView: NSHostingView<AnyView> {
    var onIntrinsicContentSizeInvalidated: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onIntrinsicContentSizeInvalidated?()
    }

    override func scrollWheel(with event: NSEvent) {}
}
