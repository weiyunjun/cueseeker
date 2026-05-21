import SwiftUI

/// Liquid Glass UI layer — shared selectable-card component, its control
/// states, and the confirmed v6 token palette (rewrite-plan Phase 5; visual
/// alignment P5.2-B).
///
/// Concrete values are the single-sourced "P5.2-B Confirmed Pixel Spec" in
/// `docs/proposals/2026-05-info-page-card-visual-rebuild.md`. The v6
/// `backdrop-filter` glass is realized with explicit scheme-adaptive near-white
/// color + hairline + soft drop shadow (NOT a frosted `Material`; the Material
/// attempt was reverted as a negative result). No hardcoded light-only values:
/// every token is defined for both color schemes.
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

/// colorScheme-driven semantic tokens (doc 11 §8). Values follow the accepted
/// v6 prototype, per the proposal "P5.2-B Confirmed Pixel Spec".
struct LiquidGlassTokens {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    // Info-page background — v6 `--search-page-bg` (#f4f4f6 / #1f2027). Near
    // white, not pure white, so the lighter cards read as elevated.
    var pageBackground: Color {
        isDark ? Color(red: 0.122, green: 0.125, blue: 0.153)
               : Color(red: 0.957, green: 0.957, blue: 0.965)
    }

    // Card fill — v6 `--search-page-card-bg` (white @0.62 / white @0.10).
    var cardFill: Color { Color.white.opacity(isDark ? 0.10 : 0.62) }
    var cardHoverFill: Color { Color.white.opacity(isDark ? 0.15 : 0.82) }
    var cardSelectedFill: Color { Color.accentColor.opacity(isDark ? 0.22 : 0.16) }

    // Library-launched "playing" indicator fill — v6 `--card-selected-bg`
    // (white @0.92 / white @0.18). Distinct from `cardSelectedFill` (the
    // sidebar-reuse accent tint); this is the doc 12 §7.2 playing state used
    // only by the Library episode card (P5.3 Confirmed Pixel Spec).
    var playingIndicatorFill: Color { Color.white.opacity(isDark ? 0.18 : 0.92) }

    // v6 `--text-on-selected-card` (#0a1426 / #f8f6fb).
    var textOnSelectedCard: Color {
        isDark ? Color(red: 0.973, green: 0.965, blue: 0.984)
               : Color(red: 0.039, green: 0.078, blue: 0.149)
    }

    // v6 `0 0 0 0.5px` edge ring.
    var cardHairline: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
    var cardHoverHairline: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    // v6 inset top highlight (`inset 0 0.5px 0 rgba(255,255,255,~0.9)`).
    var cardTopHighlight: Color {
        Color.white.opacity(isDark ? 0.16 : 0.92)
    }

    // v6 soft drop shadow (rest `0 1px 2px`, hover `0 4px 12px -4px`).
    var cardShadow: Color {
        isDark ? Color.black.opacity(0.22)
               : Color(red: 15 / 255, green: 18 / 255, blue: 30 / 255).opacity(0.06)
    }
    var cardHoverShadow: Color {
        isDark ? Color.black.opacity(0.44)
               : Color(red: 15 / 255, green: 18 / 255, blue: 30 / 255).opacity(0.14)
    }

    var selectedRing: Color { Color.accentColor }

    // Text roles — v6 `--search-page-*` (#1a1a1f/#f3f1f6, #4d4e55/#c9c6d2,
    // #7a7c84/#aaa6b6).
    var text: Color {
        isDark ? Color(red: 0.953, green: 0.945, blue: 0.965)
               : Color(red: 0.102, green: 0.102, blue: 0.122)
    }
    var text2: Color {
        isDark ? Color(red: 0.788, green: 0.776, blue: 0.824)
               : Color(red: 0.302, green: 0.306, blue: 0.333)
    }
    var text3: Color {
        isDark ? Color(red: 0.667, green: 0.651, blue: 0.714)
               : Color(red: 0.478, green: 0.486, blue: 0.518)
    }

    // Search highlight — v6 `--search-page-highlight` / `-text`.
    var highlightFill: Color {
        isDark ? Color(red: 1.0, green: 0.839, blue: 0.361).opacity(0.32)
               : Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.42)
    }
    var highlightText: Color {
        isDark ? Color(red: 1.0, green: 0.941, blue: 0.710)
               : Color(red: 0.290, green: 0.200, blue: 0.0)
    }

    // Group bottom separator — v6 `--hairline-soft`.
    var hairlineSoft: Color {
        isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
    }

    // Topbar capsule / tool buttons — v6 `.search-field` / `.tool-button`.
    var topbarFieldFill: Color { Color.white.opacity(isDark ? 0.10 : 0.55) }
    var topbarFieldFocusFill: Color { Color.white.opacity(isDark ? 0.16 : 0.85) }
    var topbarFieldHairline: Color {
        isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)
    }
    var topbarButtonHoverFill: Color { Color.white.opacity(isDark ? 0.12 : 0.55) }
    var topbarButtonSelectedFill: Color { Color.white.opacity(isDark ? 0.18 : 0.70) }
    var topbarBarTopTint: Color { Color.white.opacity(isDark ? 0.06 : 0.35) }
    var topbarBarBottomTint: Color { Color.white.opacity(isDark ? 0.02 : 0.10) }
    var topbarBarBorder: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
    var fieldIcon: Color {
        isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.45)
    }

    func cardFill(for state: LiquidGlassControlState) -> Color {
        switch state {
        case .normal, .disabled: return cardFill
        case .hovered, .pressed: return cardHoverFill
        case .selected: return cardSelectedFill
        }
    }
}

/// Shared Liquid Glass selectable card. A button-shaped v6 glass tile with
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
        let lifted = state == .hovered || state == .pressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return configuration.label
            .background {
                shape
                    .fill(tokens.cardFill(for: state))
                    .overlay {
                        // v6 inset top highlight: a faint bright top edge.
                        shape
                            .stroke(
                                LinearGradient(
                                    colors: [tokens.cardTopHighlight, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                            .mask(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        shape.strokeBorder(
                            state == .selected
                                ? tokens.selectedRing
                                : (lifted ? tokens.cardHoverHairline : tokens.cardHairline),
                            lineWidth: state == .selected ? 1.5 : 0.5
                        )
                    }
                    .shadow(
                        color: lifted ? tokens.cardHoverShadow : tokens.cardShadow,
                        radius: lifted ? 7 : 1.5,
                        x: 0,
                        y: lifted ? 4 : 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .opacity(state == .disabled ? 0.5 : 1)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.14), value: state)
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
