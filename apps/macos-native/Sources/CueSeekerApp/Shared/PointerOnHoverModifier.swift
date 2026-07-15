import AppKit
import SwiftUI

struct PointerOnHoverModifier: ViewModifier {
    let isEnabled: Bool

    @State private var isHovering = false
    @State private var hasPushedCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                isHovering = inside
                reconcileCursor()
            }
            .onChange(of: isEnabled) { _ in
                reconcileCursor()
            }
            .onDisappear {
                isHovering = false
                reconcileCursor()
            }
    }

    private func reconcileCursor() {
        let shouldPushCursor = isEnabled && isHovering
        guard shouldPushCursor != hasPushedCursor else {
            return
        }

        if shouldPushCursor {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
        hasPushedCursor = shouldPushCursor
    }
}

extension View {
    func pointerOnHover(isEnabled: Bool) -> some View {
        modifier(PointerOnHoverModifier(isEnabled: isEnabled))
    }
}
