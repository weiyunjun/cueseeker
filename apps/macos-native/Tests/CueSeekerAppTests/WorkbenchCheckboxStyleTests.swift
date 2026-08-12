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
    let size = SubtitleTableMetrics.checkboxSize
    let color = WorkbenchCheckboxStyle.controlColor(
        for: .indeterminate,
        isEnabled: true
    )
    let image = try #require(WorkbenchCheckboxStyle.appKitImage(
        for: .indeterminate,
        isEnabled: true,
        size: size
    ))
    let expectedConfiguration = NSImage.SymbolConfiguration(
        pointSize: size,
        weight: .regular
    )
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
    .applying(.preferringMonochrome())

    #expect(image.symbolConfiguration.isEqual(expectedConfiguration))
}

@MainActor
@Test
func appKitCheckboxSymbolsUseVariantPointSizeAndStayCentered() throws {
    for size in [
        SubtitleTableMetrics.checkboxSize,
        PlaybackCollageSelectionMetrics.checkboxSize,
    ] {
        let image = try #require(WorkbenchCheckboxStyle.appKitImage(
            for: .checked,
            isEnabled: true,
            size: size
        ))
        let controlRect = CGRect(x: 20, y: 30, width: size, height: size)
        let drawingRect = WorkbenchCheckboxStyle.appKitDrawingRect(
            imageSize: image.size,
            centeredIn: controlRect
        )

        #expect(drawingRect.size == image.size)
        #expect(drawingRect.midX == controlRect.midX)
        #expect(drawingRect.midY == controlRect.midY)
    }
}
