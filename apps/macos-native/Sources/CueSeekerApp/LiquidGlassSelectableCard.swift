import SwiftUI

/// Liquid Glass UI layer — shared selectable-card component and its control
/// states (rewrite-plan Phase 5, step P5.1).
///
/// This is the single owner of the `ui-selectable-card` visual (doc 11 §4/§5,
/// `LiquidGlassSelectableCard`). It is intentionally additive: surface
/// adoption by Search / Library / Shiori cards happens in P5.2–P5.4. All
/// surfaces are colorScheme-driven; no hardcoded light values (the hazard
/// called out by the overlay-panel work and proposal P5.1).
///
/// Main Search / Library / Shiori pages must NOT pass `isSelected` for
/// retained playback selection (doc 12 §6.4, doc 11 §5/§7 `ui-is-selected`);
/// the selected treatment exists for sidebar/side-panel-style reuse only.

enum LiquidGlassControlState: Equatable {
    case normal
    case hovered
    case pressed
    case selected
    case disabled
}

/// colorScheme-driven semantic tokens for the selectable-card surface
/// (doc 11 §8 `--card-*` / `--card-selected-*` → `selectableCardSurface`).
/// Values follow the accepted v6 token-override layer intent (the authoritative
/// theme-driven skin), expressed with native scheme-adaptive colors rather than
/// copied CSS literals (doc 11 §10, doc 12 §15).
struct LiquidGlassTokens {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// Base card fill — a subtle elevated translucent tile.
    var cardBackground: Color {
        Color.primary.opacity(isDark ? 0.085 : 0.045)
    }

    var cardHoverBackground: Color {
        Color.primary.opacity(isDark ? 0.13 : 0.075)
    }

    /// Selected treatment (sidebar/side-panel reuse only — not main pages).
    var cardSelectedBackground: Color {
        Color.accentColor.opacity(isDark ? 0.22 : 0.16)
    }

    var hairline: Color {
        Color.primary.opacity(isDark ? 0.10 : 0.07)
    }

    var selectedRing: Color { Color.accentColor }

    func background(for state: LiquidGlassControlState) -> Color {
        switch state {
        case .normal, .disabled:
            return cardBackground
        case .hovered, .pressed:
            return cardHoverBackground
        case .selected:
            return cardSelectedBackground
        }
    }

    func border(for state: LiquidGlassControlState) -> Color {
        switch state {
        case .selected:
            return selectedRing
        case .hovered, .pressed:
            return hairline
        case .normal, .disabled:
            return .clear
        }
    }
}

/// Shared Liquid Glass selectable card. A button-shaped surface with
/// hover / pressed / selected / disabled states. Callers supply the inner
/// content (and its padding), mirroring the prototype `.result-card`.
struct LiquidGlassSelectableCard<Content: View>: View {
    var isSelected: Bool = false
    var cornerRadius: CGFloat = 10
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action, label: content)
            .buttonStyle(
                LiquidGlassSelectableCardStyle(
                    isSelected: isSelected,
                    isHovered: isHovered,
                    isEnabled: isEnabled,
                    cornerRadius: cornerRadius,
                    tokens: LiquidGlassTokens(colorScheme: colorScheme)
                )
            )
            .onHover { isHovered = $0 }
    }
}

private struct LiquidGlassSelectableCardStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let tokens: LiquidGlassTokens

    func makeBody(configuration: Configuration) -> some View {
        let state = resolvedState(isPressed: configuration.isPressed)
        return configuration.label
            .background(tokens.background(for: state))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(tokens.border(for: state), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .opacity(state == .disabled ? 0.5 : 1)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: state)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func resolvedState(isPressed: Bool) -> LiquidGlassControlState {
        if !isEnabled { return .disabled }
        if isPressed { return .pressed }
        if isSelected { return .selected }
        if isHovered { return .hovered }
        return .normal
    }
}
