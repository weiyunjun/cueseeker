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
        static let iconDefault = NSColor.dynamic(lightHex: "#667085", darkHex: "#A1A1AA")
        static let iconMuted = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
        static let iconDisabled = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
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
        /// --color-icon-button-open-bg
        static let iconButtonOpenBg = NSColor.controlAccentColor
        /// --color-icon-button-open-content
        static let iconButtonOpenContent = iconOnDark
        // Playback footer shortcut buttons and their keycaps. Each surface
        // carries its own set so the keycap always reads one step deeper than
        // the background it sits on: the shared keycap colour used to match
        // --color-bg-hover, which is indistinguishable from the Playback
        // Overlay's own background.
        static let playbackOverlayShortcutButtonHoverBg = NSColor.dynamic(lightHex: "#EDEEF2", darkHex: "#2C2C30")
        static let playbackOverlayKeycapBg = NSColor.dynamic(lightHex: "#E1E4E9", darkHex: "#35353A")
        static let playbackOverlayKeycapHoverBg = NSColor.dynamic(lightHex: "#D2D6DE", darkHex: "#414147")
        static let commandPanelShortcutButtonHoverBg = NSColor.dynamic(lightHex: "#F7F8FA", darkHex: "#252529")
        static let commandPanelKeycapBg = NSColor.dynamic(lightHex: "#EDEFF2", darkHex: "#2E2E33")
        static let commandPanelKeycapHoverBg = NSColor.dynamic(lightHex: "#E0E3E8", darkHex: "#3A3A40")

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
        static let bgActiveClearHover = NSColor.dynamic(lightHex: "#D8E8FD", darkHex: "#243F7F")

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

        // Danger
        static let dangerText = NSColor.dynamic(lightHex: "#B42318", darkHex: "#FCA5A5")
        static let dangerBgHover = NSColor.dynamic(lightHex: "#FEF3F2", darkHex: "#3A1717")

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

        // Cover Summary
        static let coverSummaryScrim = NSColor.black
        static let coverSummaryText = NSColor.white

        // Task
        static let taskCountBadgeBg = NSColor.controlAccentColor
        static let taskCountBadgeText = iconOnDark

        // Shadow Color
        static let shadowPopover = NSColor.dynamic(lightHex: "#0F172A", lightAlpha: 0.12, darkHex: "#000000", darkAlpha: 0.36)
    }

    // SwiftUI Wrapper Tokens
    // Text
    static let textPrimary = Color(nsColor: NS.textPrimary)
    static let textSecondary = Color(nsColor: NS.textSecondary)
    static let textMuted = Color(nsColor: NS.textMuted)
    static let textPlaceholder = Color(nsColor: NS.textPlaceholder)
    static let textDisabled = Color(nsColor: NS.textDisabled)

    // Icon
    static let iconDefault = Color(nsColor: NS.iconDefault)
    static let iconMuted = Color(nsColor: NS.iconMuted)
    static let iconDisabled = Color(nsColor: NS.iconDisabled)
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
    static let iconButtonOpenBg = Color(nsColor: NS.iconButtonOpenBg)
    static let iconButtonOpenContent = Color(nsColor: NS.iconButtonOpenContent)
    static let playbackOverlayShortcutButtonHoverBg = Color(nsColor: NS.playbackOverlayShortcutButtonHoverBg)
    static let playbackOverlayKeycapBg = Color(nsColor: NS.playbackOverlayKeycapBg)
    static let playbackOverlayKeycapHoverBg = Color(nsColor: NS.playbackOverlayKeycapHoverBg)
    static let commandPanelShortcutButtonHoverBg = Color(nsColor: NS.commandPanelShortcutButtonHoverBg)
    static let commandPanelKeycapBg = Color(nsColor: NS.commandPanelKeycapBg)
    static let commandPanelKeycapHoverBg = Color(nsColor: NS.commandPanelKeycapHoverBg)

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
    static let bgActiveClearHover = Color(nsColor: NS.bgActiveClearHover)

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

    // Danger
    static let dangerText = Color(nsColor: NS.dangerText)
    static let dangerBgHover = Color(nsColor: NS.dangerBgHover)

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

    // Task
    static let taskCountBadgeBg = Color(nsColor: NS.taskCountBadgeBg)
    static let taskCountBadgeText = Color(nsColor: NS.taskCountBadgeText)

    // Shadow Popover
    static let shadowPopover = WorkbenchRedesignShadow(
        color: Color(nsColor: NS.shadowPopover),
        radius: 24,
        x: 0,
        y: 12
    )
}

struct WorkbenchRedesignShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func shadowToken(_ shadow: WorkbenchRedesignShadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}
