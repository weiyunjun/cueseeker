import AppKit
import SwiftUI

/// Manages separate `Select` (`selectedID`) and `Hover` (`hoveredID`) states
/// for a cover card grid, following
/// `docs/human/requirements/20261021-UI-Separate Hover And Select States And
/// Unify Pointer Rules.md`.
///
/// - `Select` (`selectedID`) only exists on Playback cover card grids (Playback
///   Overlay Video Playlist, Command Panel Recent Videos / Recent Excerpt Lists)
///   and is driven exclusively by default initialization and keyboard /
///   controller navigation. Workbench cover card grids leave `selectedID` nil.
/// - `Hover` (`hoveredID`) reflects the card currently under the visible pointer
///   whenever the layer is not frozen and scroll debounce (`300ms`) is not
///   active.
/// - `Hover` and `Select` never stack visually: when a card is both `Select`ed
///   and `Hover`ed, `isSelected(_:)` is true and `isHovered(_:)` is false so
///   only the `Select` visual style is displayed.
@MainActor
final class CardHighlightModel: ObservableObject {
    private final class WeakBox {
        weak var value: CardHighlightModel?
        init(_ value: CardHighlightModel) {
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

    static func broadcastLayerFrozenChanged(
        _ isFrozen: Bool,
         matching predicate: (InterfaceLayer) -> Bool
    ) {
        instances.removeAll { $0.value == nil }
        for box in instances {
            guard let model = box.value, predicate(model.layer) else {
                continue
            }
            model.setFrozen(isFrozen)
        }
    }

    @Published private(set) var selectedID: String?
    @Published private(set) var hoveredID: String?

    var layer: InterfaceLayer = .workbenchPage

    /// Compatibility accessor: returns `selectedID` when the interface maintains
    /// a `Select` state (Playback), or `hoveredID` on Workbench interfaces.
    var currentID: String? {
        keepsCurrentWhenPointerLeaves ? selectedID : hoveredID
    }

    private let keepsCurrentWhenPointerLeaves: Bool

    /// Kept for API compatibility; pointer hover no longer mutates `Select`.
    var adopt: ((String?) -> Void)?

    private(set) var isFrozen = false
    private(set) var isScrolling = false
    private var rawHoveredID: String?
    private var rawHoveredShowsHand = true

    init(keepsCurrentWhenPointerLeaves: Bool = false) {
        self.keepsCurrentWhenPointerLeaves = keepsCurrentWhenPointerLeaves
        Self.instances.removeAll { $0.value == nil }
        Self.instances.append(WeakBox(self))
    }

    /// Whether `id` is in the `Select` state.
    func isSelected(_ id: String) -> Bool {
        selectedID == id
    }

    /// Whether `id` should display the `Hover` visual style. When `id` is both
    /// `Select`ed and `Hover`ed, `Select` takes visual priority and this returns
    /// `false`.
    func isHovered(_ id: String) -> Bool {
        hoveredID == id && selectedID != id
    }

    /// Whether `id` is either `Select`ed or `Hover`ed (used by effects shared
    /// by both states, such as the `1.02`x cover scale).
    func isHighlighted(_ id: String) -> Bool {
        selectedID == id || hoveredID == id
    }

    /// Updates the `Select` state (`selectedID`) from the interface's default
    /// selection or keyboard / controller navigation. Does not clear `Hover`
    /// or reset the pointer shape.
    func setSelected(_ id: String?) {
        guard selectedID != id else {
            return
        }
        selectedID = id
    }

    func setCurrent(_ id: String?) {
        setSelected(id)
    }

    /// Resets both `Select` and `Hover` when switching between sub-interfaces
    /// hosted by the same view.
    func reset() {
        if let rawHoveredID {
            AppPointerShape.noteCardHover(
                false,
                id: rawHoveredID,
                showsHand: rawHoveredShowsHand,
                followsPointer: false
            )
        }
        selectedID = nil
        hoveredID = nil
        rawHoveredID = nil
        isScrolling = false
    }

    /// Freezes or unfreezes `Hover` updates when a menu or covering layer opens
    /// or closes. While frozen, raw hover changes from tracking areas continue
    /// to be recorded so unfreezing immediately reflects the current pointer
    /// position without waiting for another mouse move.
    func setFrozen(_ isFrozen: Bool) {
        guard self.isFrozen != isFrozen else {
            return
        }
        self.isFrozen = isFrozen
        if isFrozen {
            if let rawHoveredID {
                AppPointerShape.noteCardHover(
                    false,
                    id: rawHoveredID,
                    showsHand: rawHoveredShowsHand,
                    followsPointer: false
                )
            }
        } else {
            if let rawHoveredID {
                AppPointerShape.noteCardHover(
                    true,
                    id: rawHoveredID,
                    showsHand: rawHoveredShowsHand,
                    followsPointer: !isScrolling && !AppCursorVisibility.isCursorHidden
                )
            }
            if !isScrolling {
                syncHoveredID()
            }
        }
    }

    /// From a card's hover callback.
    func noteHover(_ isHovered: Bool, id: String, showsHand: Bool = true) {
        if isHovered {
            rawHoveredID = id
            rawHoveredShowsHand = showsHand
        } else if rawHoveredID == id {
            rawHoveredID = nil
        }
        let followsPointer = !isFrozen && !isScrolling && !AppCursorVisibility.isCursorHidden
        if !isFrozen {
            AppPointerShape.noteCardHover(
                isHovered,
                id: id,
                showsHand: showsHand,
                followsPointer: followsPointer
            )
        }
        guard !isFrozen, !isScrolling else {
            return
        }
        syncHoveredID()
    }

    /// From a right-click or left-click on a card. Updates `Hover` immediately
    /// to the pressed card without altering `Select` (`selectedID`).
    func notePress(id: String) {
        rawHoveredID = id
        isScrolling = false
        hoveredID = AppCursorVisibility.isCursorHidden ? nil : id
    }

    func notePointerMoved() {
        guard !isFrozen else {
            return
        }
        if isScrolling {
            isScrolling = false
        }
        syncHoveredID()
    }

    func noteScrolled() {
        isScrolling = true
    }

    func noteScrollSettled() {
        guard isScrolling else {
            return
        }
        isScrolling = false
        guard !isFrozen else {
            return
        }
        if let rawHoveredID {
            AppPointerShape.noteCardHover(
                true,
                id: rawHoveredID,
                showsHand: rawHoveredShowsHand,
                followsPointer: !AppCursorVisibility.isCursorHidden
            )
        }
        syncHoveredID()
    }

    func noteWindowDidResignFocus() {
        if let rawHoveredID {
            AppPointerShape.noteCardHover(
                false,
                id: rawHoveredID,
                showsHand: rawHoveredShowsHand,
                followsPointer: false
            )
        }
        rawHoveredID = nil
        isScrolling = false
        guard !isFrozen else {
            return
        }
        if hoveredID != nil {
            hoveredID = nil
        }
    }

    private func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isHidden {
            if hoveredID != nil {
                hoveredID = nil
            }
        } else if !isFrozen, !isScrolling {
            syncHoveredID()
        }
    }

    private func syncHoveredID() {
        let next = AppCursorVisibility.isCursorHidden ? nil : rawHoveredID
        if hoveredID != next {
            hoveredID = next
        }
    }
}

extension View {
    /// Keeps one interface's highlight model in step with the freeze answer of
    /// the layer that interface is on. Apply it inside `interfaceLayer(_:)` so
    /// it reads the layer the cards are actually on.
    func cardHighlightFreeze(_ model: CardHighlightModel) -> some View {
        modifier(CardHighlightFreezeModifier(model: model))
    }
}

private struct CardHighlightFreezeModifier: ViewModifier {
    let model: CardHighlightModel
    @Environment(\.interfaceLayerContext) private var layerContext

    func body(content: Content) -> some View {
        content
            .onAppear {
                model.layer = layerContext.layer
                model.setFrozen(layerContext.isFrozen)
            }
            .onChange(of: layerContext.layer) { layer in
                model.layer = layer
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                model.setFrozen(isFrozen)
            }
    }
}
