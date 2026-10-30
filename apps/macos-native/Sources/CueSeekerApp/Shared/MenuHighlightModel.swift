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

    static func broadcastMouseDown() {
        instances.removeAll { $0.value == nil }
        for box in instances {
            _ = box.value?.clearAccessibility()
        }
    }

    @Published private(set) var selectedPosition: Int?
    @Published private(set) var hoveredPosition: Int?
    @Published private(set) var accessibilityPosition: Int?

    var highlightedPosition: Int? {
        selectedPosition
    }

    var activeTriggerPosition: Int? {
        selectedPosition ?? accessibilityPosition
    }

    var revealPosition: Int? {
        accessibilityPosition ?? selectedPosition
    }

    var isAccessibilityActive: Bool {
        accessibilityPosition != nil
    }

    /// Bumped by every keyboard / controller move so a scrolling menu can bring
    /// the newly highlighted item into view.
    @Published private(set) var keyboardMoveCount = 0

    private(set) var selectablePositions: [Int] = []
    private(set) var allPositions: [Int] = []
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
        selectedPosition == position
    }

    func isHovered(_ position: Int) -> Bool {
        hoveredPosition == position && selectedPosition != position
    }

    func isAccessibilityFocused(_ position: Int) -> Bool {
        accessibilityPosition == position
    }

    /// Opens the surface with no item highlighted by default (`selectedPosition == nil`,
    /// `hoveredPosition == nil`, `accessibilityPosition == nil`).
    /// The `defaultPosition` parameter is retained for call-site compatibility and ignored.
    func open(
        selectablePositions: [Int],
        allPositions: [Int]? = nil,
        defaultPosition: Int? = nil
    ) {
        _ = defaultPosition
        self.selectablePositions = selectablePositions
        self.allPositions = allPositions ?? selectablePositions
        isOpen = true
        isScrolling = false
        isSuppressedByKeyboard = false
        pinnedPosition = nil
        rawHoveredPosition = nil
        selectedPosition = nil
        hoveredPosition = nil
        accessibilityPosition = nil
    }

    func close() {
        isOpen = false
        selectablePositions = []
        allPositions = []
        selectedPosition = nil
        hoveredPosition = nil
        accessibilityPosition = nil
        pinnedPosition = nil
        rawHoveredPosition = nil
        isScrolling = false
        isSuppressedByKeyboard = false
    }

    /// Moves `selectedPosition` by `offset` and reports whether the surface
    /// consumed the key. When `selectedPosition` is `nil`, moving up
    /// (`offset < 0`) selects the last selectable item and moving down
    /// (`offset > 0`) selects the first selectable item. When an item is
    /// already selected, movement stops at the first and last selectable
    /// positions instead of wrapping. If accessibility is currently active,
    /// `accessibilityPosition` follows the new `selectedPosition`.
    @discardableResult
    func moveHighlight(by offset: Int) -> Bool {
        guard !selectablePositions.isEmpty else {
            return false
        }
        guard offset != 0 else {
            return true
        }
        let targetIndex: Int
        if let current = selectedPosition
            .flatMap({ selectablePositions.firstIndex(of: $0) }) {
            targetIndex = min(
                max(0, current + offset),
                selectablePositions.count - 1
            )
        } else if let accPos = accessibilityPosition {
            if offset > 0 {
                targetIndex = selectablePositions.firstIndex(where: { $0 > accPos })
                    ?? (selectablePositions.count - 1)
            } else {
                targetIndex = selectablePositions.lastIndex(where: { $0 < accPos })
                    ?? 0
            }
        } else {
            targetIndex = offset < 0 ? (selectablePositions.count - 1) : 0
        }
        let nextPosition = selectablePositions[targetIndex]
        selectedPosition = nextPosition
        if accessibilityPosition != nil {
            accessibilityPosition = nextPosition
        }
        keyboardMoveCount += 1
        return true
    }

    /// Moves accessibility focus (`accessibilityPosition`) forward (`Tab` / `R1`)
    /// or backward (`Shift + Tab` / `L1`) across `allPositions` (which includes
    /// disabled menu items and skips dividers), wrapping around at both ends.
    /// Enabled items also receive `selectedPosition`; disabled items clear
    /// `selectedPosition` so they only show the outer focus ring.
    @discardableResult
    func moveAccessibility(forward: Bool) -> Bool {
        let positions = allPositions.isEmpty ? selectablePositions : allPositions
        guard !positions.isEmpty else {
            return false
        }
        let targetIndex: Int
        if let current = accessibilityPosition,
           let currentIndex = positions.firstIndex(of: current) {
            if forward {
                targetIndex = (currentIndex + 1) % positions.count
            } else {
                targetIndex = (currentIndex - 1 + positions.count) % positions.count
            }
        } else {
            targetIndex = forward ? 0 : (positions.count - 1)
        }
        let nextPosition = positions[targetIndex]
        accessibilityPosition = nextPosition
        if selectablePositions.contains(nextPosition) {
            selectedPosition = nextPosition
        } else {
            selectedPosition = nil
        }
        keyboardMoveCount += 1
        return true
    }

    /// Exits accessibility mode on this menu surface, keeping `selectedPosition`
    /// unchanged. Returns `true` if accessibility was active and cleared.
    @discardableResult
    func clearAccessibility() -> Bool {
        guard accessibilityPosition != nil else {
            return false
        }
        accessibilityPosition = nil
        return true
    }

    /// Standard keyboard/controller handler for a single-level menu.
    func handleStandardMenuKey(
        keyCode: UInt16,
        onActivate: () -> Void,
        onDismiss: () -> Void
    ) -> Bool {
        switch keyCode {
        case MenuGate.tabKeyCode:
            _ = moveAccessibility(forward: true)
            return true
        case MenuGate.shiftTabKeyCode:
            _ = moveAccessibility(forward: false)
            return true
        case 53:
            if clearAccessibility() {
                return true
            }
            onDismiss()
            return true
        case 126:
            _ = moveHighlight(by: -1)
            return true
        case 125:
            _ = moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76, 49:
            onActivate()
            return true
        default:
            return false
        }
    }

    func selectPosition(_ position: Int) {
        guard selectablePositions.contains(position) else {
            return
        }
        if selectedPosition != position {
            selectedPosition = position
        }
    }

    /// Pins the pointer-hovered item on the parent menu while a submenu triggered
    /// by `position` is open from pointer hover.
    func setPinnedPosition(_ position: Int?) {
        let validated = position.flatMap { selectablePositions.contains($0) ? $0 : nil }
        guard pinnedPosition != validated else {
            return
        }
        pinnedPosition = validated
        syncHoveredPosition()
    }

    /// Unpins the parent trigger when its submenu is closed by keyboard,
    /// preserving the trigger item's `Select` highlight.
    func unpinKeepingHighlight() {
        let pinned = pinnedPosition
        pinnedPosition = nil
        accessibilityPosition = nil
        if let pinned {
            selectedPosition = pinned
        }
        syncHoveredPosition()
    }

    func noteSelectionMovedByKeyboardOrController() {
        // Hover and Select in popup menus are independent; keyboard/controller
        // movement does not clear or suppress menu pointer hover.
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

    func updatePointerHover(position: Int?) {
        rawHoveredPosition = position.flatMap {
            selectablePositions.contains($0) ? $0 : nil
        }
        guard !isScrolling, !isSuppressedByKeyboard else {
            return
        }
        syncHoveredPosition()
    }

    func syncHoverAfterScrollSettled(positionUnderPointer: Int?) {
        rawHoveredPosition = positionUnderPointer.flatMap {
            selectablePositions.contains($0) ? $0 : nil
        }
        isScrolling = false
        guard !isSuppressedByKeyboard else {
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
        if pinnedPosition == nil, hoveredPosition != nil {
            hoveredPosition = nil
        }
    }

    private func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isHidden {
            if pinnedPosition == nil, hoveredPosition != nil {
                hoveredPosition = nil
            }
        } else if !isScrolling, !isSuppressedByKeyboard {
            syncHoveredPosition()
        }
    }

    private func syncHoveredPosition() {
        if let pinnedPosition {
            if hoveredPosition != pinnedPosition {
                hoveredPosition = pinnedPosition
            }
            return
        }
        if isSuppressedByKeyboard {
            if hoveredPosition != nil {
                hoveredPosition = nil
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
        if hoveredPosition != next {
            hoveredPosition = next
        }
    }
}
