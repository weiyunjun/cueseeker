import AppKit
import SwiftUI

/// Manages the unified highlight state (`highlightedPosition`) for an open
/// popup menu or submenu surface, following
/// `docs/human/requirements/20261022-UI-Unify Popup Menu Hover And Select And
/// Suppress Hover After Keyboard Or Controller Navigation.md`.
///
/// - Popup menus and submenus open with no item highlighted by default
///   (`highlightedPosition == nil`).
/// - Pointer hover and keyboard / controller directional navigation share the
///   same `highlightedPosition` state and render using the unified `Hover`
///   visual style.
/// - Moving the highlight via keyboard or controller increments
///   `keyboardMoveCount` (so a scrollable menu brings the item into view) and
///   suppresses pointer hover until the mouse actually moves.
@MainActor
final class MenuHighlightModel: ObservableObject {
    private final class WeakBox {
        weak var value: MenuHighlightModel?
        init(_ value: MenuHighlightModel) {
            self.value = value
        }
    }

    private static var instances: [WeakBox] = []

    static func broadcastScrolled() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.noteScrolled()
        }
    }

    static func broadcastSelectionMovedByKeyboardOrController() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.noteSelectionMovedByKeyboardOrController()
        }
    }

    static func broadcastPointerMoved() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            box.value?.notePointerMoved()
        }
    }

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

    @Published private(set) var highlightedPosition: Int?

    var selectedPosition: Int? {
        highlightedPosition
    }

    var hoveredPosition: Int? {
        highlightedPosition
    }

    /// Bumped by every keyboard / controller move so a scrolling menu can bring
    /// the newly highlighted item into view.
    @Published private(set) var keyboardMoveCount = 0

    private(set) var selectablePositions: [Int] = []
    private(set) var isOpen = false
    private(set) var isScrolling = false
    private(set) var isSuppressedByKeyboard = false
    private(set) var pinnedPosition: Int?
    private var rawHoveredPosition: Int?

    init() {
        Self.instances.removeAll { $0.value == nil }
        Self.instances.append(WeakBox(self))
    }

    func isSelected(_ position: Int) -> Bool {
        highlightedPosition == position
    }

    func isHovered(_ position: Int) -> Bool {
        highlightedPosition == position
    }

    /// Opens the surface with no item highlighted by default (`highlightedPosition == nil`).
    /// The `defaultPosition` parameter is retained for call-site compatibility and ignored.
    func open(selectablePositions: [Int], defaultPosition: Int? = nil) {
        _ = defaultPosition
        self.selectablePositions = selectablePositions
        isOpen = true
        isScrolling = false
        isSuppressedByKeyboard = false
        pinnedPosition = nil
        rawHoveredPosition = nil
        highlightedPosition = nil
    }

    func close() {
        isOpen = false
        selectablePositions = []
        highlightedPosition = nil
        pinnedPosition = nil
        rawHoveredPosition = nil
        isScrolling = false
        isSuppressedByKeyboard = false
    }

    /// Moves `highlightedPosition` by `offset` and reports whether the surface
    /// consumed the key. When `highlightedPosition` is `nil`, moving up
    /// (`offset < 0`) highlights the last selectable item and moving down
    /// (`offset > 0`) highlights the first selectable item. When an item is
    /// already highlighted, movement stops at the first and last selectable
    /// positions instead of wrapping.
    @discardableResult
    func moveHighlight(by offset: Int) -> Bool {
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        isSuppressedByKeyboard = true
        guard !selectablePositions.isEmpty else {
            return false
        }
        guard offset != 0 else {
            return true
        }
        let targetIndex: Int
        if let current = highlightedPosition
            .flatMap({ selectablePositions.firstIndex(of: $0) }) {
            targetIndex = min(
                max(0, current + offset),
                selectablePositions.count - 1
            )
        } else {
            targetIndex = offset < 0 ? (selectablePositions.count - 1) : 0
        }
        highlightedPosition = selectablePositions[targetIndex]
        keyboardMoveCount += 1
        return true
    }

    func selectPosition(_ position: Int) {
        guard selectablePositions.contains(position) else {
            return
        }
        if highlightedPosition != position {
            highlightedPosition = position
        }
    }

    /// Pins the highlighted item on the parent menu while a submenu triggered
    /// by `position` is open.
    func setPinnedPosition(_ position: Int?) {
        let validated = position.flatMap { selectablePositions.contains($0) ? $0 : nil }
        guard pinnedPosition != validated else {
            return
        }
        pinnedPosition = validated
        if let validated {
            if highlightedPosition != validated {
                highlightedPosition = validated
            }
        } else if !isScrolling, !isSuppressedByKeyboard {
            syncHoveredPosition()
        }
    }

    /// Unpins the parent trigger when its submenu is closed by keyboard,
    /// preserving the trigger item's highlight until the pointer moves.
    func unpinKeepingHighlight() {
        guard let pinned = pinnedPosition else {
            return
        }
        pinnedPosition = nil
        isSuppressedByKeyboard = true
        if highlightedPosition != pinned {
            highlightedPosition = pinned
        }
    }

    func noteSelectionMovedByKeyboardOrController() {
        isSuppressedByKeyboard = true
    }

    func noteScrolled() {
        isScrolling = true
    }

    func noteScrollSettled() {
        guard isScrolling else {
            return
        }
        isScrolling = false
        guard !isSuppressedByKeyboard else {
            return
        }
        syncHoveredPosition()
    }

    func noteHover(_ isHovered: Bool, at position: Int) {
        if isHovered {
            rawHoveredPosition = selectablePositions.contains(position) ? position : nil
        } else if rawHoveredPosition == position {
            rawHoveredPosition = nil
        }
        guard !isScrolling, !isSuppressedByKeyboard else {
            return
        }
        syncHoveredPosition()
    }

    func notePointerMoved() {
        if isScrolling {
            isScrolling = false
        }
        let wasSuppressedByKeyboard = isSuppressedByKeyboard
        if isSuppressedByKeyboard {
            isSuppressedByKeyboard = false
        }
        if wasSuppressedByKeyboard, rawHoveredPosition == nil {
            return
        }
        syncHoveredPosition()
    }

    func noteWindowDidResignFocus() {
        rawHoveredPosition = nil
        isScrolling = false
        if !isSuppressedByKeyboard, pinnedPosition == nil, highlightedPosition != nil {
            highlightedPosition = nil
        }
    }

    private func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isHidden {
            if !isSuppressedByKeyboard, pinnedPosition == nil, highlightedPosition != nil {
                highlightedPosition = nil
            }
        } else if !isScrolling, !isSuppressedByKeyboard {
            syncHoveredPosition()
        }
    }

    private func syncHoveredPosition() {
        if let pinnedPosition {
            if highlightedPosition != pinnedPosition {
                highlightedPosition = pinnedPosition
            }
            return
        }
        let next: Int?
        if AppCursorVisibility.isCursorHidden {
            next = nil
        } else if let rawHoveredPosition, selectablePositions.contains(rawHoveredPosition) {
            next = rawHoveredPosition
        } else {
            next = nil
        }
        if highlightedPosition != next {
            highlightedPosition = next
        }
    }
}
