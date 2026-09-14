import SwiftUI
import AppKit

extension NSColor {
    static func hex(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        return NSColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: alpha
        )
    }

    static func dynamic(lightHex: String, lightAlpha: CGFloat = 1.0, darkHex: String, darkAlpha: CGFloat = 1.0) -> NSColor {
        return NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return .hex(darkHex, alpha: darkAlpha)
            } else {
                return .hex(lightHex, alpha: lightAlpha)
            }
        }
    }

    static func controlAccent(lightAlpha: CGFloat, darkAlpha: CGFloat) -> NSColor {
        return NSColor(name: nil) { appearance in
            let alpha = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkAlpha : lightAlpha
            return NSColor.controlAccentColor.withAlphaComponent(alpha)
        }
    }
}

enum WorkbenchRedesignColors {
    // AppKit Custom Drawing Layer Dynamic Tokens
    enum NS {
        // Text
        static let textPrimary = NSColor.dynamic(lightHex: "#1F1F1F", darkHex: "#F7F7F7")
        static let textSecondary = NSColor.dynamic(lightHex: "#494949", darkHex: "#B9B9B9")
        static let textMuted = NSColor.dynamic(lightHex: "#717171", darkHex: "#878787")
        static let textPlaceholder = NSColor.dynamic(lightHex: "#9A9A9A", darkHex: "#606060")
        static let textDisabled = NSColor.dynamic(lightHex: "#9A9A9A", darkHex: "#606060")

        // Icon
        static let iconOnDark = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#FFFFFF")

        // Background
        static let bgSurface = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        static let bgHover = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#27272A")
        static let bgDisabled = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#202024")
        static let bgPopover = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#1C1C1F")
        static let appSidebarBg = NSColor.dynamic(lightHex: "#F6F7F9", darkHex: "#202024")
        static let appSidebarItemSelectedBg = NSColor.controlAccentColor
        static let appSidebarItemSelectedContent = iconOnDark
        static let appTopbarBg = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        // Shortcut action buttons and their keycaps. Named after the surface
        // they sit on rather than the interface that uses them: the Command
        // Panel and the workbench Selection Action Overlay are both popover
        // surfaces and share one set. Each surface carries its own so the
        // keycap always reads one step deeper than the background under it.
        static let overlaySurfaceShortcutButtonHoverBg = NSColor.dynamic(lightHex: "#EDEEF2", darkHex: "#2C2C30")
        static let overlaySurfaceKeycapBg = NSColor.dynamic(lightHex: "#E1E4E9", darkHex: "#35353A")
        static let overlaySurfaceKeycapHoverBg = NSColor.dynamic(lightHex: "#D2D6DE", darkHex: "#414147")
        static let popoverSurfaceShortcutButtonHoverBg = NSColor.dynamic(lightHex: "#F7F8FA", darkHex: "#252529")
        static let popoverSurfaceKeycapBg = NSColor.dynamic(lightHex: "#EDEFF2", darkHex: "#2E2E33")
        static let popoverSurfaceKeycapHoverBg = NSColor.dynamic(lightHex: "#E0E3E8", darkHex: "#3A3A40")

        // Border
        static let borderControl = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let borderControlHover = NSColor.dynamic(lightHex: "#D1D5DB", darkHex: "#52525B")
        static let borderMuted = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let borderDivider = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let borderDisabled = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let borderCheckbox = NSColor.dynamic(lightHex: "#D0D5DD", darkHex: "#52525B")

        // Active Blue
        static let accent = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#7AA2FF")
        static let textActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#8AB4FF")
        static let iconActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#8AB4FF")
        static let borderActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#7AA2FF")
        static let bgActive = NSColor.dynamic(lightHex: "#EBF5FF", darkHex: "#14275A")
        static let bgActiveHover = NSColor.dynamic(lightHex: "#E1EBFF", darkHex: "#1B3470")

        // Primary Button
        static let primaryButtonBg = NSColor.controlAccentColor
        static let primaryButtonBgHover = NSColor.controlAccentColor
        static let primaryButtonText = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#FFFFFF")

        // Focus
        static let borderFocus = NSColor.controlAccentColor
        static let focusRing = NSColor.controlAccent(lightAlpha: 0.22, darkAlpha: 0.30)

        // Table Row
        static let rowHover = NSColor.dynamic(lightHex: "#F9FAFB", darkHex: "#202024")
        static let rowSelected = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#27272A")

        // Checkbox
        static let bgCheckboxUnchecked = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        static let bgCheckboxChecked = NSColor.dynamic(lightHex: "#667085", darkHex: "#A1A1AA")
        static let checkboxIcon = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")

        // Segmented Control
        static let segmentedControlSelectedBg = NSColor.controlAccentColor
        static let segmentedControlSelectedContent = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#FFFFFF")

        // Danger
        static let dangerText = NSColor.dynamic(lightHex: "#B42318", darkHex: "#FCA5A5")
        static let dangerBgHover = NSColor.dynamic(lightHex: "#FEF3F2", darkHex: "#3A1717")

        // Success
        static let successText = NSColor.dynamic(lightHex: "#047857", darkHex: "#6EE7B7")

        // Warning
        static let warningText = NSColor.dynamic(lightHex: "#B45309", darkHex: "#FCD34D")

        // Settings Group
        static let settingsGroupBg = NSColor.dynamic(lightHex: "#F6F7F9", darkHex: "#202024")

        // Scrollbar
        static let scrollbarThumbDefault = NSColor.dynamic(lightHex: "#CBD5E1", darkHex: "#52525B")
        static let scrollbarThumbInteractive = NSColor.dynamic(lightHex: "#94A3B8", darkHex: "#71717A")
        static let scrollbarTrack = NSColor.clear

        // Chip
        static let chipLanguageBg = NSColor.dynamic(lightHex: "#DBEAFE", darkHex: "#172A4A")
        static let chipLanguageText = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#93C5FD")

        // Watch Status
        static let watchStatusUnwatchedBg = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#27272A")
        static let watchStatusUnwatchedText = NSColor.dynamic(lightHex: "#667085", darkHex: "#A1A1AA")
        static let watchStatusWatchingBg = NSColor.dynamic(lightHex: "#DBEAFE", darkHex: "#172A4A")
        static let watchStatusWatchingText = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#93C5FD")
        static let watchStatusFinishedBg = NSColor.dynamic(lightHex: "#D1FAE5", darkHex: "#123A2A")
        static let watchStatusFinishedText = NSColor.dynamic(lightHex: "#047857", darkHex: "#6EE7B7")

        // Library Media
        static let libraryProgressFill = NSColor.controlAccentColor
        static let libraryProgressTrack = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let libraryTimeBadgeBg = NSColor.dynamic(lightHex: "#0F172A", lightAlpha: 0.72, darkHex: "#000000", darkAlpha: 0.58)
        static let libraryTimeBadgeText = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
        static let libraryCoverPlaceholderBg = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let libraryCoverCropAccent = NSColor.controlAccentColor
        static let libraryCoverCropMask = NSColor.shadowColor.withAlphaComponent(0.55)
        static let libraryCoverEditOverlay = libraryCoverCropMask
        static let libraryCoverEditOverlayContent = iconOnDark
        static let libraryMediaCardHoverBg = NSColor.controlAccent(lightAlpha: 0.08, darkAlpha: 0.12)

        // Spinner
        static let spinnerTrack = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let spinnerIndicator = NSColor.dynamic(lightHex: "#717171", darkHex: "#878787")

        // Cover Summary
        static let coverSummaryScrim = NSColor.black
        static let coverSummaryText = NSColor.white

        // Task
        static let taskCountBadgeBg = NSColor.controlAccentColor
        static let taskCountBadgeText = iconOnDark

        // Shadow Color
        // One colour for both themes. On a dark page a shadow this light
        // changes the pixels under it by about a tenth of what it changes on a
        // white one, so dark separates the popover from the page with the
        // container border instead. If dark ever needs more lift, the popover
        // background goes up a step; the shadow does not get heavier.
        static let shadowPopover = NSColor.hex("#0F172A", alpha: 0.10)

        // Dialog
        // What the system sheet drew around a dialog, measured from it on
        // macOS 15.5: the veil over what the dialog covers, the shadow, the
        // hairline just outside the edge and the highlight just inside it.
        // --color-dialog-scrim
        static let dialogScrim = NSColor.dynamic(
            lightHex: "#AAAAAA",
            lightAlpha: 0.60,
            darkHex: "#161819",
            darkAlpha: 0.60
        )
        static let dialogShadow = NSColor.dynamic(
            lightHex: "#000000",
            lightAlpha: 0.25,
            darkHex: "#000000",
            darkAlpha: 0.43
        )
        static let dialogOutline = NSColor.dynamic(
            lightHex: "#000000",
            lightAlpha: 0.19,
            darkHex: "#000000",
            darkAlpha: 0.94
        )
        static let dialogEdgeHighlight = NSColor.dynamic(
            lightHex: "#FFFFFF",
            lightAlpha: 0,
            darkHex: "#FFFFFF",
            darkAlpha: 0.20
        )
    }

    // SwiftUI Wrapper Tokens
    // Text
    static let textPrimary = Color(nsColor: NS.textPrimary)
    static let textSecondary = Color(nsColor: NS.textSecondary)
    static let textMuted = Color(nsColor: NS.textMuted)
    static let textPlaceholder = Color(nsColor: NS.textPlaceholder)
    static let textDisabled = Color(nsColor: NS.textDisabled)

    // Icon
    static let iconOnDark = Color(nsColor: NS.iconOnDark)

    // Background
    static let bgSurface = Color(nsColor: NS.bgSurface)
    static let bgHover = Color(nsColor: NS.bgHover)
    static let bgDisabled = Color(nsColor: NS.bgDisabled)
    static let bgPopover = Color(nsColor: NS.bgPopover)
    static let appSidebarBg = Color(nsColor: NS.appSidebarBg)
    static let appSidebarItemSelectedBg = Color(nsColor: NS.appSidebarItemSelectedBg)
    static let appSidebarItemSelectedContent = Color(nsColor: NS.appSidebarItemSelectedContent)
    static let appTopbarBg = Color(nsColor: NS.appTopbarBg)
    static let overlaySurfaceShortcutButtonHoverBg = Color(nsColor: NS.overlaySurfaceShortcutButtonHoverBg)
    static let overlaySurfaceKeycapBg = Color(nsColor: NS.overlaySurfaceKeycapBg)
    static let overlaySurfaceKeycapHoverBg = Color(nsColor: NS.overlaySurfaceKeycapHoverBg)
    static let popoverSurfaceShortcutButtonHoverBg = Color(nsColor: NS.popoverSurfaceShortcutButtonHoverBg)
    static let popoverSurfaceKeycapBg = Color(nsColor: NS.popoverSurfaceKeycapBg)
    static let popoverSurfaceKeycapHoverBg = Color(nsColor: NS.popoverSurfaceKeycapHoverBg)

    // Cover Summary
    static let coverSummaryScrim = Color(nsColor: NS.coverSummaryScrim)
    static let coverSummaryText = Color(nsColor: NS.coverSummaryText)

    // Border
    static let borderControl = Color(nsColor: NS.borderControl)
    static let borderControlHover = Color(nsColor: NS.borderControlHover)
    static let borderMuted = Color(nsColor: NS.borderMuted)
    static let borderDivider = Color(nsColor: NS.borderDivider)
    static let borderDisabled = Color(nsColor: NS.borderDisabled)
    static let borderCheckbox = Color(nsColor: NS.borderCheckbox)

    // Active Blue
    static let accent = Color(nsColor: NS.accent)
    static let textActive = Color(nsColor: NS.textActive)
    static let iconActive = Color(nsColor: NS.iconActive)
    static let borderActive = Color(nsColor: NS.borderActive)
    static let bgActive = Color(nsColor: NS.bgActive)
    static let bgActiveHover = Color(nsColor: NS.bgActiveHover)

    // Primary Button
    static let primaryButtonBg = Color.accentColor
    static let primaryButtonBgHover = Color.accentColor
    static let primaryButtonText = Color(nsColor: NS.primaryButtonText)

    // Focus
    static let borderFocus = Color.accentColor
    static let focusRing = Color(nsColor: NS.focusRing)

    // Table Row
    static let rowHover = Color(nsColor: NS.rowHover)
    static let rowSelected = Color(nsColor: NS.rowSelected)

    // Checkbox
    static let bgCheckboxUnchecked = Color(nsColor: NS.bgCheckboxUnchecked)
    static let bgCheckboxChecked = Color(nsColor: NS.bgCheckboxChecked)
    static let checkboxIcon = Color(nsColor: NS.checkboxIcon)

    // Segmented Control
    static let segmentedControlSelectedBg = Color(nsColor: NS.segmentedControlSelectedBg)
    static let segmentedControlSelectedContent = Color(nsColor: NS.segmentedControlSelectedContent)

    // Danger
    static let dangerText = Color(nsColor: NS.dangerText)
    static let dangerBgHover = Color(nsColor: NS.dangerBgHover)

    // Success
    static let successText = Color(nsColor: NS.successText)

    // Warning
    static let warningText = Color(nsColor: NS.warningText)

    // Settings Group
    static let settingsGroupBg = Color(nsColor: NS.settingsGroupBg)

    // Scrollbar
    static let scrollbarThumbDefault = Color(nsColor: NS.scrollbarThumbDefault)
    static let scrollbarThumbInteractive = Color(nsColor: NS.scrollbarThumbInteractive)
    static let scrollbarTrack = Color.clear

    // Chip
    static let chipLanguageBg = Color(nsColor: NS.chipLanguageBg)
    static let chipLanguageText = Color(nsColor: NS.chipLanguageText)

    // Watch Status
    static let watchStatusUnwatchedBg = Color(nsColor: NS.watchStatusUnwatchedBg)
    static let watchStatusUnwatchedText = Color(nsColor: NS.watchStatusUnwatchedText)
    static let watchStatusWatchingBg = Color(nsColor: NS.watchStatusWatchingBg)
    static let watchStatusWatchingText = Color(nsColor: NS.watchStatusWatchingText)
    static let watchStatusFinishedBg = Color(nsColor: NS.watchStatusFinishedBg)
    static let watchStatusFinishedText = Color(nsColor: NS.watchStatusFinishedText)

    // Library Media
    static let libraryProgressFill = Color.accentColor
    static let libraryProgressTrack = Color(nsColor: NS.libraryProgressTrack)
    static let libraryTimeBadgeBg = Color(nsColor: NS.libraryTimeBadgeBg)
    static let libraryTimeBadgeText = Color(nsColor: NS.libraryTimeBadgeText)
    static let libraryCoverPlaceholderBg = Color(nsColor: NS.libraryCoverPlaceholderBg)
    static let libraryCoverCropAccent = Color(nsColor: NS.libraryCoverCropAccent)
    static let libraryCoverCropMask = Color(nsColor: NS.libraryCoverCropMask)
    static let libraryCoverEditOverlay = Color(nsColor: NS.libraryCoverEditOverlay)
    static let libraryCoverEditOverlayContent = Color(nsColor: NS.libraryCoverEditOverlayContent)
    static let libraryMediaCardHoverBg = Color(nsColor: NS.libraryMediaCardHoverBg)

    // Filter Chip
    // --color-filter-chip-selected-content: macOS accent color
    static let filterChipSelectedContent = Color.accentColor
    // --color-filter-chip-selected-bg: Same as --color-library-media-card-hover-bg
    static let filterChipSelectedBg = libraryMediaCardHoverBg

    // Spinner
    // --color-spinner-track
    static let spinnerTrack = Color(nsColor: NS.spinnerTrack)
    // --color-spinner-indicator
    static let spinnerIndicator = Color(nsColor: NS.spinnerIndicator)

    // Task
    static let taskCountBadgeBg = Color(nsColor: NS.taskCountBadgeBg)
    static let taskCountBadgeText = Color(nsColor: NS.taskCountBadgeText)

    // Dialog
    static let dialogScrim = Color(nsColor: NS.dialogScrim)
    static let dialogOutline = Color(nsColor: NS.dialogOutline)
    static let dialogEdgeHighlight = Color(nsColor: NS.dialogEdgeHighlight)

    // Shadow Dialog
    // --shadow-dialog: 0 18px 40px, one layer in both themes; only its
    // strength differs, as the system sheet's did.
    static let shadowDialog = WorkbenchRedesignShadow(layers: [
        WorkbenchRedesignShadowLayer(
            color: Color(nsColor: NS.dialogShadow),
            radius: 20,
            x: 0,
            y: 18,
            spread: 0
        ),
    ])

    // Shadow Popover
    // Two layers, both shrunk before they are blurred: the main layer lifts
    // the surface, the contact layer bites its edge so the outline stays
    // legible. The shrink is what keeps either layer from reaching past the
    // container's top edge, where a floating surface should cast nothing.
    static let shadowPopover = WorkbenchRedesignShadow(layers: [
        WorkbenchRedesignShadowLayer(
            color: Color(nsColor: NS.shadowPopover),
            radius: 7.5,
            x: 0,
            y: 10,
            spread: -3
        ),
        WorkbenchRedesignShadowLayer(
            color: Color(nsColor: NS.shadowPopover),
            radius: 3,
            x: 0,
            y: 4,
            spread: -4
        ),
    ])
}

/// One blurred copy of the container's shape. `radius` is half the blur the
/// design system records, because a CSS blur radius spans twice the standard
/// deviation that this one takes.
struct WorkbenchRedesignShadowLayer {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    /// Negative shrinks the casting shape before it is blurred, so the layer
    /// leaves the container only where its own offset pushes it out.
    let spread: CGFloat
}

struct WorkbenchRedesignShadow {
    let layers: [WorkbenchRedesignShadowLayer]
}

extension View {
    /// Draws the token's layers behind the caller's own filled shape. SwiftUI
    /// has no spread, so every layer is cast by a copy of that shape shrunk by
    /// the layer's own spread. The copies are opaque and strictly smaller than
    /// the caller's shape, which must be opaque too so that it covers them.
    func shadowToken(
        _ shadow: WorkbenchRedesignShadow,
        cornerRadius: CGFloat
    ) -> some View {
        background(
            ZStack {
                ForEach(Array(shadow.layers.enumerated()), id: \.offset) { _, layer in
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .inset(by: -layer.spread)
                        .fill(Color.black)
                        .shadow(
                            color: layer.color,
                            radius: layer.radius,
                            x: layer.x,
                            y: layer.y
                        )
                }
            }
        )
    }
}
