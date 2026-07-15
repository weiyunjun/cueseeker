import AppKit
import SwiftUI

/// Observes and restores the native clip-view offset under a SwiftUI
/// ScrollView. Item anchors remain a fallback for content changes; this bridge
/// preserves the exact pixel position across Playback module replacement.
@MainActor
struct PlaybackMediaScrollPositionBridge: NSViewRepresentable {
    let restorationOffsetY: CGFloat
    let onOffsetChanged: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            restorationOffsetY: restorationOffsetY,
            onOffsetChanged: onOffsetChanged
        )
    }

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.onHierarchyChanged = { [weak coordinator = context.coordinator] view in
            coordinator?.attach(toEnclosingScrollViewOf: view)
        }
        return view
    }

    func updateNSView(_ nsView: AttachmentView, context: Context) {
        context.coordinator.update(
            restorationOffsetY: restorationOffsetY,
            onOffsetChanged: onOffsetChanged
        )
        context.coordinator.attach(toEnclosingScrollViewOf: nsView)
    }

    static func dismantleNSView(_ nsView: AttachmentView, coordinator: Coordinator) {
        nsView.onHierarchyChanged = nil
        coordinator.invalidate()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var scrollView: NSScrollView?
        private var restorationOffsetY: CGFloat
        private var onOffsetChanged: (CGFloat) -> Void
        private var attachmentTask: Task<Void, Never>?
        private var restorationTask: Task<Void, Never>?
        private var didRestore = false

        init(
            restorationOffsetY: CGFloat,
            onOffsetChanged: @escaping (CGFloat) -> Void
        ) {
            self.restorationOffsetY = max(0, restorationOffsetY)
            self.onOffsetChanged = onOffsetChanged
        }

        func update(
            restorationOffsetY: CGFloat,
            onOffsetChanged: @escaping (CGFloat) -> Void
        ) {
            self.restorationOffsetY = max(0, restorationOffsetY)
            self.onOffsetChanged = onOffsetChanged
        }

        func attach(toEnclosingScrollViewOf view: NSView) {
            attachmentTask?.cancel()
            guard attachIfAvailable(toEnclosingScrollViewOf: view) else {
                attachmentTask = Task { @MainActor [weak self, weak view] in
                    while !Task.isCancelled {
                        guard let self, let view, !Task.isCancelled else {
                            return
                        }
                        if attachIfAvailable(toEnclosingScrollViewOf: view) {
                            attachmentTask = nil
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                }
                return
            }
        }

        private func attachIfAvailable(
            toEnclosingScrollViewOf view: NSView
        ) -> Bool {
            guard let resolvedScrollView = Self.enclosingScrollView(of: view) else {
                return false
            }
            guard scrollView !== resolvedScrollView else {
                scheduleRestorationIfNeeded()
                return true
            }

            restorationTask?.cancel()
            restorationTask = nil
            didRestore = false
            stopObserving()
            scrollView = resolvedScrollView
            resolvedScrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(clipViewBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: resolvedScrollView.contentView
            )
            scheduleRestorationIfNeeded()
            return true
        }

        func invalidate() {
            attachmentTask?.cancel()
            attachmentTask = nil
            restorationTask?.cancel()
            restorationTask = nil
            stopObserving()
            onOffsetChanged = { _ in }
        }

        @objc
        private func clipViewBoundsDidChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  clipView === scrollView?.contentView
            else {
                return
            }
            onOffsetChanged(max(0, clipView.bounds.origin.y))
        }

        private func scheduleRestorationIfNeeded() {
            guard !didRestore,
                  restorationTask == nil,
                  let scrollView
            else {
                return
            }
            let targetOffsetY = restorationOffsetY
            restorationTask = Task { @MainActor [weak self, weak scrollView] in
                await Task.yield()
                for attempt in 0..<100 {
                    guard let self,
                          let scrollView,
                          !Task.isCancelled,
                          self.scrollView === scrollView
                    else {
                        return
                    }
                    let clipView = scrollView.contentView
                    var targetBounds = clipView.bounds
                    targetBounds.origin.y = targetOffsetY
                    let constrainedBounds = clipView.constrainBoundsRect(targetBounds)
                    let targetIsAvailable = targetOffsetY < 0.5
                        || abs(constrainedBounds.origin.y - targetOffsetY) < 0.5
                    if targetIsAvailable || attempt == 99 {
                        clipView.scroll(to: constrainedBounds.origin)
                        scrollView.reflectScrolledClipView(clipView)
                        didRestore = true
                        onOffsetChanged(max(0, clipView.bounds.origin.y))
                        restorationTask = nil
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
        }

        private func stopObserving() {
            if let scrollView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView
                )
            }
            scrollView = nil
        }

        private static func enclosingScrollView(of view: NSView) -> NSScrollView? {
            if let enclosingScrollView = view.enclosingScrollView {
                return enclosingScrollView
            }
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? NSScrollView {
                    return scrollView
                }
                ancestor = current.superview
            }
            return nil
        }
    }

    @MainActor
    final class AttachmentView: NSView {
        var onHierarchyChanged: ((NSView) -> Void)?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            onHierarchyChanged?(self)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onHierarchyChanged?(self)
        }
    }
}
