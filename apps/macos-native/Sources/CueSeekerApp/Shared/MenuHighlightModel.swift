import AppKit
import SwiftUI

/// Manages separate `Select` (`selectedPosition` / `highlightedPosition`) and
/// `Hover` (`hoveredPosition`) states for an open menu surface, following
/// `docs/human/requirements/20261021-UI-Separate Hover And Select States And
/// Unify Pointer Rules.md`.
///
/// - `Select` (`selectedPosition`) is initialized when the menu opens and is
///   moved exclusively by keyboard arrow keys or controller D-pad / left stick.
///   Moving `Select` increments `keyboardMoveCount` so a scrolling menu can
///   scroll the newly `Select`ed row into view.
/// - `Hover` (`hoveredPosition`) reflects the selectable row under the visible
///   pointer whenever scroll debounce (`300ms`) is not active.
/// - `Hover` and `Select` never stack visually: when a row is both `Select`ed
///   and `Hover`ed, `isSelected(_:)` is true and `isHovered(_:)` is false so
///   only the `Select` visual style is displayed.
@MainActor
final class MenuHighlightModel: ObservableObject {
    private final class WeakBox {
        weak var value: MenuHighlightModel?
        init(_ value: MenuHighlightModel) {
            self.value = value
        }
    }

    private static var instances: [WeakBox] = []

    static func broadcastScrollSettled() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.noteScrollSettled()
        }
    }

    static func broadcastCursorHiddenChanged(_ isHidden: Bool) {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.noteCursorHiddenChanged(isHidden)
        }
    }

    static func broadcastWindowDidResignFocus() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.noteWindowDidResignFocus()
        }
    }

    @Published private(set) var selectedPosition: Int?
    @Published private(set) var hoveredPosition: Int?

    /// Synonym for `selectedPosition` used by keyboard navigation, Enter
    /// activation, and `ScrollViewReader` auto-scrolling.
    var highlightedPosition: Int? {
        selectedPosition
    }

    /// Bumped by every keyboard / controller move so a scrolling menu can bring
    /// the newly `Select`ed item into view.
    @Published private(set) var keyboardMoveCount = 0

    private(set) var selectablePositions: [Int] = []
    private(set) var isScrolling = false
    private var rawHoveredPosition: Int?
    nonisolated(unsafe) private var pointerMonitor: Any?

    init() {
        Self.instances.removeAll { $0.value == nil }
        Self.instances.append(WeakBox(self))
    }

    var isOpen: Bool {
        pointerMonitor != nil
    }

    func isSelected(_ position: Int) -> Bool {
        selectedPosition == position
    }

    func isHovered(_ position: Int) -> Bool {
        hoveredPosition == position && selectedPosition != position
    }

    /// Opens the surface with `defaultPosition` selected, or the first
    /// selectable position when it is absent or not selectable.
    func open(selectablePositions: [Int], defaultPosition: Int? = nil) {
        self.selectablePositions = selectablePositions
        isScrolling = false
        rawHoveredPosition = nil
        hoveredPosition = nil
        selectedPosition = defaultPosition
            .flatMap { selectablePositions.contains($0) ? $0 : nil }
            ?? selectablePositions.first
        startObservingPointerMovement()
    }

    func close() {
        stopObservingPointerMovement()
        selectablePositions = []
        selectedPosition = nil
        hoveredPosition = nil
        rawHoveredPosition = nil
        isScrolling = false
    }

    /// Moves `Select` (`selectedPosition`) and reports whether the surface
    /// consumed the key. Stops at the first and last selectable position
    /// instead of wrapping.
    @discardableResult
    func moveHighlight(by offset: Int) -> Bool {
        guard !selectablePositions.isEmpty else {
            return false
        }
        let current = selectedPosition
            .flatMap { selectablePositions.firstIndex(of: $0) } ?? 0
        let target = min(
            max(0, current + offset),
            selectablePositions.count - 1
        )
        selectedPosition = selectablePositions[target]
        keyboardMoveCount += 1
        return true
    }

    func noteScrolled() {
        isScrolling = true
    }

    func noteScrollSettled() {
        guard isScrolling else {
            return
        }
        isScrolling = false
        syncHoveredPosition()
    }

    func noteHover(_ isHovered: Bool, at position: Int) {
        if isHovered {
            rawHoveredPosition = selectablePositions.contains(position) ? position : nil
        } else if rawHoveredPosition == position {
            rawHoveredPosition = nil
        }
        guard !isScrolling else {
            return
        }
        syncHoveredPosition()
    }

    func notePointerMoved() {
        if isScrolling {
            isScrolling = false
        }
        syncHoveredPosition()
    }

    func noteWindowDidResignFocus() {
        rawHoveredPosition = nil
        isScrolling = false
        if hoveredPosition != nil {
            hoveredPosition = nil
        }
    }

    private func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isHidden {
            if hoveredPosition != nil {
                hoveredPosition = nil
            }
        } else if !isScrolling {
            syncHoveredPosition()
        }
    }

    private func syncHoveredPosition() {
        let next: Int?
        if AppCursorVisibility.isCursorHidden {
            next = nil
        } else if let rawHoveredPosition, selectablePositions.contains(rawHoveredPosition) {
            next = rawHoveredPosition
        } else {
            next = nil
        }
        if hoveredPosition != next {
            hoveredPosition = next
        }
    }

    private func startObservingPointerMovement() {
        guard pointerMonitor == nil else {
            return
        }
        pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .mouseMoved, .leftMouseDragged, .rightMouseDragged,
                .scrollWheel,
            ]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                guard NSApp.isActive, event.window?.isKeyWindow == true else {
                    return
                }
                if event.type == .scrollWheel {
                    self?.noteScrolled()
                } else {
                    self?.notePointerMoved()
                }
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
