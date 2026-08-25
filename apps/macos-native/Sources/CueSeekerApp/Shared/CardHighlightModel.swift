import AppKit
import SwiftUI

/// The one highlighted card of one interface, following
/// `docs/human/requirements/20260826-UI-Card Highlight Single Authority And
/// Menu Input Rules.md`.
///
/// Hover and selection are the same thing for a card, so a card keeps no
/// highlight of its own: it reports the pointer here and paints what this
/// answers. That is the only arrangement in which "at most one card is lit"
/// can be guaranteed rather than hoped for.
///
/// A grid is scrolled, reflowed and revealed underneath a pointer that never
/// moved, and SwiftUI reports every one of those as hover. Adopting them would
/// light whatever slid under the cursor, so hover is adopted only after a real
/// pointer movement. The card under the pointer is remembered meanwhile, and
/// the next real movement applies it without waiting for the pointer to cross
/// into another card — otherwise a highlight moved by the keyboard could only
/// be taken back by leaving the card and coming back.
@MainActor
final class CardHighlightModel: ObservableObject {
    @Published private(set) var currentID: String?

    /// Playback interfaces keep one card lit at all times, so a pointer that
    /// leaves the cards leaves the highlight where it was. Workbench
    /// interfaces let it go and light nothing.
    private let keepsCurrentWhenPointerLeaves: Bool

    /// Where an adopted pointer target goes for an interface that already
    /// navigates with a selection of its own: it moves that selection, and
    /// reports the result back through `setCurrent`. Interfaces without one
    /// leave this nil and this model is the selection.
    var adopt: ((String?) -> Void)?

    private var isFrozen = false
    private var adoptsHover = false
    private var hoveredID: String?
    nonisolated(unsafe) private var pointerMonitor: Any?

    init(keepsCurrentWhenPointerLeaves: Bool) {
        self.keepsCurrentWhenPointerLeaves = keepsCurrentWhenPointerLeaves
        startObservingPointer()
    }

    deinit {
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
        }
    }

    /// The interface reports where its own selection now is. A target the
    /// pointer is not already on came from the keyboard or from the
    /// interface's default, so the pointer must move for real before it may
    /// pull the highlight back.
    func setCurrent(_ id: String?) {
        if id != hoveredID {
            adoptsHover = false
        }
        guard currentID != id else {
            return
        }
        currentID = id
    }

    /// One interface's view is reused for several interfaces — Library's folder
    /// list and its detail, Recent's overview and its two sections. Switching
    /// between them is entering a new interface, which starts with nothing lit
    /// and with the pointer having to move for real before anything lights.
    func reset() {
        currentID = nil
        hoveredID = nil
        adoptsHover = false
    }

    /// A covered interface, or one with a menu open, keeps the picture it had.
    /// Reports are dropped rather than queued, so nothing the pointer did while
    /// frozen can be applied after the freeze lifts.
    func setFrozen(_ isFrozen: Bool) {
        guard self.isFrozen != isFrozen else {
            return
        }
        self.isFrozen = isFrozen
        adoptsHover = false
        hoveredID = nil
    }

    /// From a card's hover callback.
    func noteHover(_ isHovered: Bool, id: String) {
        guard !isFrozen else {
            return
        }
        if isHovered {
            hoveredID = id
        } else if hoveredID == id {
            hoveredID = nil
        }
        adoptHoverIfAllowed()
    }

    /// From a right-click, or from a left-click that is not being spent on
    /// closing a menu. The pointer is on the card by definition, so this needs
    /// no movement first, and a freeze does not stop it: right-clicking a
    /// second card closes the first card's menu and opens its own on the same
    /// press, and the highlight has to travel with it.
    func notePress(id: String) {
        hoveredID = id
        adoptsHover = true
        apply(id)
    }

    private func adoptHoverIfAllowed() {
        guard adoptsHover else {
            return
        }
        guard let hoveredID else {
            if !keepsCurrentWhenPointerLeaves, currentID != nil {
                apply(nil)
            }
            return
        }
        guard currentID != hoveredID else {
            return
        }
        apply(hoveredID)
    }

    private func apply(_ id: String?) {
        if let adopt {
            adopt(id)
        } else {
            currentID = id
        }
    }

    private func startObservingPointer() {
        guard pointerMonitor == nil else {
            return
        }
        // The main window accepts mouse-moved events, so a local monitor sees
        // real pointer motion over every surface that can host a card. A wheel
        // is not motion: it slides cards under a pointer that stayed put, so it
        // closes the gate instead of opening it.
        pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .mouseMoved,
                .leftMouseDragged,
                .rightMouseDragged,
                .scrollWheel
            ]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                if event.type == .scrollWheel {
                    self.noteScrolled()
                } else {
                    self.notePointerMoved()
                }
            }
            return event
        }
    }

    /// A real pointer movement opens the gate and applies whatever card the
    /// pointer is already on, so a highlight moved by the keyboard is given
    /// back to the pointer without it having to leave the card and return.
    func notePointerMoved() {
        guard !isFrozen else {
            return
        }
        adoptsHover = true
        adoptHoverIfAllowed()
    }

    /// A wheel is not a movement: it slides cards under a pointer that stayed
    /// put, so it closes the gate rather than opening it.
    func noteScrolled() {
        adoptsHover = false
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
                model.setFrozen(layerContext.isFrozen)
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                model.setFrozen(isFrozen)
            }
    }
}
