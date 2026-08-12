import AppKit
import Testing
@testable import CueSeekerApp

@Test
func checkboxVariantsShareSystemSymbolsAndKeepDocumentedSizes() {
    #expect(WorkbenchCheckboxStyle.systemImageName(for: .unchecked) == "circle")
    #expect(WorkbenchCheckboxStyle.systemImageName(for: .checked) == "checkmark.circle.fill")
    #expect(WorkbenchCheckboxStyle.systemImageName(for: .indeterminate) == "minus.circle.fill")

    #expect(WorkbenchControlMetrics.redesignCheckboxSize == 16)
    #expect(SubtitleTableMetrics.checkboxSize == 16)
    #expect(PlaybackCollageSelectionMetrics.checkboxSize == 24)
}

@MainActor
@Test
func indeterminateCheckboxUsesSharedMonochromeSystemSymbol() throws {
    let color = WorkbenchCheckboxStyle.controlColor(
        for: .indeterminate,
        isEnabled: true
    )
    let image = try #require(WorkbenchCheckboxStyle.appKitImage(
        for: .indeterminate,
        isEnabled: true
    ))
    let expectedConfiguration = NSImage.SymbolConfiguration(
        hierarchicalColor: color
    ).applying(.preferringMonochrome())

    #expect(image.symbolConfiguration.isEqual(expectedConfiguration))
}
