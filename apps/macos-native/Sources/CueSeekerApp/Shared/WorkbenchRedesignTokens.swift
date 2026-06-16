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
}

enum WorkbenchRedesignColors {
    // AppKit Custom Drawing Layer Dynamic Tokens
    enum NS {
        // Text
        static let textPrimary = NSColor.dynamic(lightHex: "#0F172A", darkHex: "#F4F4F5")
        static let textMuted = NSColor.dynamic(lightHex: "#667085", darkHex: "#A1A1AA")
        static let textPlaceholder = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
        static let textDisabled = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
        static let textReadonly = NSColor.dynamic(lightHex: "#808080", darkHex: "#A1A1AA")

        // Icon
        static let iconDefault = NSColor.dynamic(lightHex: "#667085", darkHex: "#A1A1AA")
        static let iconMuted = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
        static let iconDisabled = NSColor.dynamic(lightHex: "#98A2B3", darkHex: "#71717A")
        static let iconOnDark = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#FFFFFF")

        // Background
        static let bgSurface = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        static let bgHover = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#27272A")
        static let bgDisabled = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#202024")
        static let bgReadonly = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        static let bgPopover = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#1C1C1F")

        // Border
        static let borderControl = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let borderControlHover = NSColor.dynamic(lightHex: "#D1D5DB", darkHex: "#52525B")
        static let borderMuted = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let borderDivider = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let borderDisabled = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#303036")
        static let borderReadonly = NSColor.dynamic(lightHex: "#E5E7EB", darkHex: "#3F3F46")
        static let borderCheckbox = NSColor.dynamic(lightHex: "#D0D5DD", darkHex: "#52525B")

        // Active Blue
        static let accent = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#7AA2FF")
        static let textActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#8AB4FF")
        static let iconActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#8AB4FF")
        static let borderActive = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#7AA2FF")
        static let bgActive = NSColor.dynamic(lightHex: "#EBF5FF", darkHex: "#14275A")
        static let bgActiveHover = NSColor.dynamic(lightHex: "#E1EBFF", darkHex: "#1B3470")
        static let bgActiveClearHover = NSColor.dynamic(lightHex: "#D8E8FD", darkHex: "#243F7F")
        static let borderFocus = NSColor.dynamic(lightHex: "#3B82F6", darkHex: "#60A5FA")
        static let focusRing = NSColor.dynamic(lightHex: "#3B82F6", lightAlpha: 0.22, darkHex: "#60A5FA", darkAlpha: 0.30)

        // Table Row
        static let rowHover = NSColor.dynamic(lightHex: "#F9FAFB", darkHex: "#202024")
        static let rowSelected = NSColor.dynamic(lightHex: "#F3F4F6", darkHex: "#27272A")

        // Checkbox
        static let bgCheckboxUnchecked = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")
        static let bgCheckboxChecked = NSColor.dynamic(lightHex: "#111827", darkHex: "#F4F4F5")
        static let checkboxIcon = NSColor.dynamic(lightHex: "#FFFFFF", darkHex: "#18181B")

        // Danger
        static let dangerText = NSColor.dynamic(lightHex: "#B42318", darkHex: "#FCA5A5")
        static let dangerBgHover = NSColor.dynamic(lightHex: "#FEF3F2", darkHex: "#3A1717")

        // Scrollbar
        static let scrollbarThumbDefault = NSColor.dynamic(lightHex: "#CBD5E1", darkHex: "#52525B")
        static let scrollbarThumbInteractive = NSColor.dynamic(lightHex: "#94A3B8", darkHex: "#71717A")
        static let scrollbarTrack = NSColor.clear

        // Chip
        static let chipSpeakerBg = NSColor.dynamic(lightHex: "#DDD6FE", darkHex: "#31294C")
        static let chipSpeakerText = NSColor.dynamic(lightHex: "#5B21B6", darkHex: "#D8B4FE")
        static let chipLanguageBg = NSColor.dynamic(lightHex: "#DBEAFE", darkHex: "#172A4A")
        static let chipLanguageText = NSColor.dynamic(lightHex: "#0040FF", darkHex: "#93C5FD")

        // Shadow Color
        static let shadowPopover = NSColor.dynamic(lightHex: "#0F172A", lightAlpha: 0.12, darkHex: "#000000", darkAlpha: 0.36)
    }

    // SwiftUI Wrapper Tokens
    // Text
    static let textPrimary = Color(nsColor: NS.textPrimary)
    static let textMuted = Color(nsColor: NS.textMuted)
    static let textPlaceholder = Color(nsColor: NS.textPlaceholder)
    static let textDisabled = Color(nsColor: NS.textDisabled)
    static let textReadonly = Color(nsColor: NS.textReadonly)

    // Icon
    static let iconDefault = Color(nsColor: NS.iconDefault)
    static let iconMuted = Color(nsColor: NS.iconMuted)
    static let iconDisabled = Color(nsColor: NS.iconDisabled)
    static let iconOnDark = Color(nsColor: NS.iconOnDark)

    // Background
    static let bgSurface = Color(nsColor: NS.bgSurface)
    static let bgHover = Color(nsColor: NS.bgHover)
    static let bgDisabled = Color(nsColor: NS.bgDisabled)
    static let bgReadonly = Color(nsColor: NS.bgReadonly)
    static let bgPopover = Color(nsColor: NS.bgPopover)

    // Border
    static let borderControl = Color(nsColor: NS.borderControl)
    static let borderControlHover = Color(nsColor: NS.borderControlHover)
    static let borderMuted = Color(nsColor: NS.borderMuted)
    static let borderDivider = Color(nsColor: NS.borderDivider)
    static let borderDisabled = Color(nsColor: NS.borderDisabled)
    static let borderReadonly = Color(nsColor: NS.borderReadonly)
    static let borderCheckbox = Color(nsColor: NS.borderCheckbox)

    // Active Blue
    static let accent = Color(nsColor: NS.accent)
    static let textActive = Color(nsColor: NS.textActive)
    static let iconActive = Color(nsColor: NS.iconActive)
    static let borderActive = Color(nsColor: NS.borderActive)
    static let bgActive = Color(nsColor: NS.bgActive)
    static let bgActiveHover = Color(nsColor: NS.bgActiveHover)
    static let bgActiveClearHover = Color(nsColor: NS.bgActiveClearHover)
    static let borderFocus = Color(nsColor: NS.borderFocus)
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
    static let chipSpeakerBg = Color(nsColor: NS.chipSpeakerBg)
    static let chipSpeakerText = Color(nsColor: NS.chipSpeakerText)
    static let chipLanguageBg = Color(nsColor: NS.chipLanguageBg)
    static let chipLanguageText = Color(nsColor: NS.chipLanguageText)

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
