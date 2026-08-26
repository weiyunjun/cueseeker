import AppKit
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func subtitleTableTagStyleUsesRedesignChipPaddingAndFitContentHeight() {
    let style = SubtitleTableTagStyle.resolve(isRedesign: true)
    let attributed = SubtitleTableText.tag(
        WorkbenchTag(key: "zh-hans", colorID: .blue),
        isRedesign: true
    )
    let textSize = attributed.size()
    let foreground = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor

    #expect(style.horizontalInset == 10)
    #expect(style.verticalInset == 4)
    #expect(style.cornerRadius == 6)
    #expect(style.width(for: textSize) == ceil(textSize.width) + 20)
    #expect(style.height(for: textSize) == ceil(textSize.height) + 8)
    #expect(foreground === WorkbenchRedesignColors.NS.textMuted)
}

@MainActor
@Test
func subtitleTableTagStyleUsesDisabledRedesignColors() {
    let style = SubtitleTableTagStyle.resolve(isRedesign: true)
    let tag = WorkbenchTag(key: "zh-hans", colorID: .blue)
    let attributed = SubtitleTableText.tag(tag, isRedesign: true, isEnabled: false)
    let foreground = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor

    #expect(hexString(style.fillColor(for: tag, isRedesign: true, isEnabled: false)) == "#F3F4F6")
    #expect(foreground.map(hexString) == "#98A2B3")
}

@Test
func workbenchTagRedesignColorsMapLanguageTokens() {
    #expect(hexString(WorkbenchTagColorID.blue.redesignFillColor()) == "#DBEAFE")
    #expect(hexString(WorkbenchTagColorID.blue.redesignForegroundColor()) == "#0040FF")
}

@Test
func workbenchTagRedesignColorsMapShioriGrayTokens() {
    #expect(hexString(WorkbenchTagColorID.gray.redesignFillColor()) == "#F3F4F6")
    #expect(hexString(WorkbenchTagColorID.gray.redesignForegroundColor()) == "#535761")
}

private func hexString(_ color: NSColor) -> String {
    var resolved: NSColor?
    NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    guard let srgb = resolved else {
        return ""
    }
    let red = Int((srgb.redComponent * 255).rounded())
    let green = Int((srgb.greenComponent * 255).rounded())
    let blue = Int((srgb.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}
