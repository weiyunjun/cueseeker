import SwiftUI

/// Hover for a visual effect, reported only while the surface's layer owns
/// input.
///
/// A menu open over a layer, or a higher layer covering it, stops every surface
/// on that layer from answering the pointer — `docs/human/design/UI Application
/// Rules.md` 菜单模态 4 and 更高层界面的屏蔽 2, and
/// `docs/human/requirements/20260826-UI-Card Highlight Single Authority And
/// Menu Input Rules.md` §8.1.
///
/// That question is answered here once instead of being remembered at each of
/// the several dozen places that react to hover. Remembering is what failed:
/// every button and the Scrollbar went on lighting under the pointer while a
/// card menu was open, because a bare `onHover` asks nothing.
///
/// While frozen the surface keeps the picture it had. Reports are held rather
/// than forced off, and the held value is delivered once the freeze lifts, so a
/// pointer that walked away while a menu was up does not leave a control lit
/// behind it.
///
/// Menu content is the exception and must not use this. A menu belongs to the
/// layer it freezes, so it would freeze itself; menu rows report to
/// `MenuHighlightModel`, and cards report to `CardHighlightModel`.
extension View {
    func onPointerHover(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(PointerHoverModifier(action: action))
    }
}

/// The delivery rule, kept out of the view so it can be pinned by tests.
struct PointerHoverGate: Equatable {
    /// What the pointer last did, whether or not the surface was allowed to
    /// answer it.
    private var reportedIsHovered = false
    /// What the surface was last told, which is what it is painting.
    private var deliveredIsHovered = false

    /// Records what the pointer did and returns what the surface should be
    /// told, or nil when it should be told nothing.
    mutating func report(_ isHovered: Bool, isFrozen: Bool) -> Bool? {
        reportedIsHovered = isHovered
        return delivery(isFrozen: isFrozen)
    }

    /// Returns what the surface should be told now that the freeze changed.
    mutating func freezeChanged(isFrozen: Bool) -> Bool? {
        delivery(isFrozen: isFrozen)
    }

    private mutating func delivery(isFrozen: Bool) -> Bool? {
        guard !isFrozen, deliveredIsHovered != reportedIsHovered else {
            return nil
        }
        deliveredIsHovered = reportedIsHovered
        return reportedIsHovered
    }
}

private struct PointerHoverModifier: ViewModifier {
    let action: (Bool) -> Void
    @Environment(\.interfaceLayerContext) private var layerContext
    @State private var gate = PointerHoverGate()

    func body(content: Content) -> some View {
        content
            .onHover { isHovered in
                if let delivered = gate.report(
                    isHovered,
                    isFrozen: layerContext.isFrozen
                ) {
                    action(delivered)
                }
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                if let delivered = gate.freezeChanged(isFrozen: isFrozen) {
                    action(delivered)
                }
            }
    }
}
