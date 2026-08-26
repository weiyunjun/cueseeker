import SwiftUI

struct HoverBackgroundModifier: ViewModifier {
    let hoverColor: Color
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? hoverColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onPointerHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverBackground(color: Color = Color.black.opacity(0.08), cornerRadius: CGFloat = 6) -> some View {
        self.modifier(HoverBackgroundModifier(hoverColor: color, cornerRadius: cornerRadius))
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color.black.opacity(0.15) :
                (isHovered ? Color.black.opacity(0.08) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onPointerHover { hovering in
                isHovered = hovering
            }
    }
}

/// The project's button style: it draws the label and nothing else. SwiftUI's
/// own `.plain` dims the label while the mouse is held down, and the design
/// system has no pressed state for any button, so every button uses this one
/// instead and keeps the appearance it already had until it is released.
struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
