import AppKit
import SwiftUI

/// The single highlighted item of one open menu surface.
///
/// A context menu opens under the pointer, so adopting hover right away would
/// fight the keyboard: the row already beneath the cursor would pull the
/// highlight straight back, and the same happens after every keyboard move that
/// lands away from a stationary pointer. Hover is therefore only adopted once
/// the pointer has really moved, and a keyboard move closes that gate again and
/// hides the cursor until it does.
///
/// The menu that owns this model supplies the positions that can take the
/// highlight, so dividers and disabled items are simply absent and keyboard
/// navigation skips them without needing to know what a divider is.
@MainActor
final class MenuHighlightModel: ObservableObject {
    @Published private(set) var highlightedPosition: Int?

    private(set) var selectablePositions: [Int] = []
    private(set) var adoptsHover = false
    private var hoveredPosition: Int?
    nonisolated(unsafe) private var pointerMonitor: Any?

    var isOpen: Bool {
        pointerMonitor != nil
    }

    /// Opens the surface with `defaultPosition` highlighted, or the first
    /// selectable position when it is absent or not selectable.
    func open(selectablePositions: [Int], defaultPosition: Int? = nil) {
        self.selectablePositions = selectablePositions
        adoptsHover = false
        hoveredPosition = nil
        highlightedPosition = defaultPosition
            .flatMap { selectablePositions.contains($0) ? $0 : nil }
            ?? selectablePositions.first
        startObservingPointerMovement()
    }

    func close() {
        stopObservingPointerMovement()
        selectablePositions = []
        highlightedPosition = nil
        hoveredPosition = nil
        adoptsHover = false
        AppCursorVisibility.setHidden(false, owner: .menu)
    }

    /// Moves the highlight and reports whether the surface consumed the key.
    /// The highlight stops at the first and last selectable position instead of
    /// wrapping, matching the Command Panel's existing arrow-key behaviour.
    @discardableResult
    func moveHighlight(by offset: Int) -> Bool {
        guard !selectablePositions.isEmpty else {
            return false
        }
        adoptsHover = false
        AppCursorVisibility.setHidden(true, owner: .menu)
        let current = highlightedPosition
            .flatMap { selectablePositions.firstIndex(of: $0) } ?? 0
        let target = min(
            max(0, current + offset),
            selectablePositions.count - 1
        )
        highlightedPosition = selectablePositions[target]
        return true
    }

    /// Records where the pointer is. The hovered position is remembered even
    /// while the gate is closed, so the highlight can follow the pointer as
    /// soon as it moves again without waiting for it to cross into a new row.
    func noteHover(_ isHovered: Bool, at position: Int) {
        if isHovered {
            hoveredPosition = position
        } else if hoveredPosition == position {
            hoveredPosition = nil
        }
        adoptHoverIfAllowed()
    }

    func notePointerMoved() {
        AppCursorVisibility.setHidden(false, owner: .menu)
        adoptsHover = true
        adoptHoverIfAllowed()
    }

    private func adoptHoverIfAllowed() {
        guard adoptsHover,
              let hoveredPosition,
              selectablePositions.contains(hoveredPosition)
        else {
            return
        }
        highlightedPosition = hoveredPosition
    }

    private func startObservingPointerMovement() {
        guard pointerMonitor == nil else {
            return
        }
        // The main window accepts mouse-moved events, so a local monitor sees
        // real pointer motion over every surface that can host a menu.
        pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.notePointerMoved()
            }
            return event
        }
    }

    private func stopObservingPointerMovement() {
        guard let pointerMonitor else {
            return
        }
        NSEvent.removeMonitor(pointerMonitor)
        self.pointerMonitor = nil
    }

    deinit {
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
        }
    }
}
