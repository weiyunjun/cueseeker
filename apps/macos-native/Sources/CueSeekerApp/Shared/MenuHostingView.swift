import AppKit
import SwiftUI

/// The view a menu's content is hosted in.
///
/// A menu owns the wheel while the pointer is on it. Content that can scroll —
/// a long destination list — sees the event first and scrolls with it; once
/// that content reaches its end the event arrives here and stops, instead of
/// travelling on to the page underneath the menu.
final class MenuHostingView: CueSeekerHostingView<AnyView> {
    var onIntrinsicContentSizeInvalidated: (() -> Void)?
    var probeLabel: String = "MenuHostingView"

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        MenuJitterProbe.log(
            "HostingView",
            "\(probeLabel) invalidateIntrinsicContentSize frame=\(MenuJitterProbe.fmt(frame)) bounds=\(MenuJitterProbe.fmt(bounds)) isHidden=\(isHidden)"
        )
        onIntrinsicContentSizeInvalidated?()
    }

    override func layout() {
        let beforeFrame = frame
        let beforeBounds = bounds
        super.layout()
        let subviewSummary = subviews.enumerated().map { idx, view in
            "s\(idx)[cls=\(type(of: view)) f=\(MenuJitterProbe.fmt(view.frame)) b=\(MenuJitterProbe.fmt(view.bounds))]"
        }.joined(separator: " ")
        MenuJitterProbe.logIfChanged(
            key: "HostingView.layout.\(probeLabel)",
            category: "HostingView",
            value: "beforeF=\(MenuJitterProbe.fmt(beforeFrame)) afterF=\(MenuJitterProbe.fmt(frame)) beforeB=\(MenuJitterProbe.fmt(beforeBounds)) afterB=\(MenuJitterProbe.fmt(bounds)) subviews=\(subviewSummary)"
        )
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        let old = frame.origin
        super.setFrameOrigin(newOrigin)
        if old != frame.origin {
            MenuJitterProbe.log(
                "HostingView",
                "\(probeLabel) setFrameOrigin \(MenuJitterProbe.fmt(old)) -> \(MenuJitterProbe.fmt(frame.origin)) frame=\(MenuJitterProbe.fmt(frame))"
            )
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let old = frame.size
        super.setFrameSize(newSize)
        if old != frame.size {
            MenuJitterProbe.log(
                "HostingView",
                "\(probeLabel) setFrameSize \(MenuJitterProbe.fmt(old)) -> \(MenuJitterProbe.fmt(frame.size)) frame=\(MenuJitterProbe.fmt(frame))"
            )
        }
    }

    override func scrollWheel(with event: NSEvent) {}
}
