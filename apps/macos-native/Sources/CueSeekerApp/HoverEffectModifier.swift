import SwiftUI

struct HoverBackgroundModifier: ViewModifier {
    let hoverColor: Color
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? hoverColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onHover { hovering in
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
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
