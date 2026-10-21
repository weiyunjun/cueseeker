import AppKit
import SwiftUI

/// The project's button style for non-button-trigger surfaces (rows, cards,
/// tabs, menu items): it draws the label and nothing else. SwiftUI's own
/// `.plain` dims the label while the mouse is held down, so surfaces outside
/// the button pressed whitelist use this style to keep their appearance static.
struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Button style for whitelisted button triggers that expose a pressed state.
/// Suppresses SwiftUI's default label dimming while forwarding `configuration.isPressed`
/// into `@Binding var isPressed`, and clears `@Binding var isHovered` when the pointer
/// is dragged outside the button while the primary mouse button remains held down.
struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    var isHovered: Binding<Bool>?

    init(isPressed: Binding<Bool>, isHovered: Binding<Bool>? = nil) {
        self._isPressed = isPressed
        self.isHovered = isHovered
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
                if newValue {
                    isHovered?.wrappedValue = true
                } else if (NSEvent.pressedMouseButtons & 1) != 0 {
                    isHovered?.wrappedValue = false
                }
            }
            .onDisappear {
                if isPressed {
                    isPressed = false
                }
            }
    }
}
