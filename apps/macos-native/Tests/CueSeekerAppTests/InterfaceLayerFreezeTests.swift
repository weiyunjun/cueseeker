import CoreGraphics
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func openLayerFreezesThePageBelowItButNotItself() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.commandPanel, true)

    let frozen = layers.frozenLayers

    #expect(frozen.contains(.workbenchPage))
    #expect(frozen.contains(.playbackPage))
    // The panel is the reason the page below it is frozen. Reading the page's
    // answer inside the panel froze the panel's own cards the moment it opened.
    #expect(!frozen.contains(.commandPanel))
}

@MainActor
@Test
func aSurfaceAnswersForTheLayerItIsOn() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.commandPanel, true)
    let frozen = layers.frozenLayers

    let onThePage = InterfaceLayerContext(
        layer: .workbenchPage,
        frozenLayers: frozen
    )
    let inThePanel = InterfaceLayerContext(
        layer: .commandPanel,
        frozenLayers: frozen
    )

    #expect(onThePage.isFrozen)
    #expect(!inThePanel.isFrozen)
}

@MainActor
@Test
func aMenuFreezesTheLayerThatOwnsIt() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.commandPanel, true)
    let token = layers.registerOpenMenu(ownedBy: .commandPanel)

    let inThePanel = InterfaceLayerContext(
        layer: .commandPanel,
        frozenLayers: layers.frozenLayers
    )

    #expect(inThePanel.isFrozen)
    _ = token
}

@MainActor
@Test
func nothingIsFrozenWhileOnlyTheWorkbenchPageIsOpen() {
    let layers = InterfaceLayerRegistry()

    #expect(layers.frozenLayers.isEmpty)
    #expect(!InterfaceLayerContext(frozenLayers: layers.frozenLayers).isFrozen)
}

@MainActor
@Test
func openLayerCoversThePageBelowItButNotItself() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.commandPanel, true)

    let covered = layers.coveredLayers

    #expect(covered.contains(.workbenchPage))
    // Its own cards keep their right-click menu: the panel is the reason the
    // page below it is covered, not something covering the panel.
    #expect(!covered.contains(.commandPanel))
}

@MainActor
@Test
func aSurfaceAnswersCoverageForTheLayerItIsOn() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.playbackOverlay, true)
    let covered = layers.coveredLayers

    let onThePage = InterfaceLayerContext(
        layer: .workbenchPage,
        coveredLayers: covered
    )
    let inTheOverlay = InterfaceLayerContext(
        layer: .playbackOverlay,
        coveredLayers: covered
    )

    #expect(onThePage.isCovered)
    #expect(!inTheOverlay.isCovered)
}

@MainActor
@Test
func aDialogCoversTheLayerItOpensOver() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)
    layers.setOpen(.commandPanel, true)
    layers.setOpen(.dialog, true)

    let inThePanel = InterfaceLayerContext(
        layer: .commandPanel,
        coveredLayers: layers.coveredLayers
    )

    #expect(inThePanel.isCovered)
}

@MainActor
@Test
func stackedDialogFreezesAndCoversLowerDialogWithoutFreezingItself() {
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.dialog, true)
    #expect(layers.hasOpenDialog)
    #expect(InterfaceLayer.dialog.isDialog)
    #expect(InterfaceLayer.stackedDialog.isDialog)
    #expect(!layers.isFrozen(.dialog))
    #expect(!layers.isCovered(.dialog))

    layers.setOpen(.stackedDialog, true)
    #expect(layers.hasOpenDialog)
    #expect(layers.isCovered(.dialog))
    #expect(layers.isFrozen(.dialog))
    #expect(!layers.isCovered(.stackedDialog))
    #expect(!layers.isFrozen(.stackedDialog))

    layers.setOpen(.stackedDialog, false)
    #expect(layers.hasOpenDialog)
    #expect(!layers.isCovered(.dialog))
    #expect(!layers.isFrozen(.dialog))

    layers.setOpen(.dialog, false)
    #expect(!layers.hasOpenDialog)
}

@MainActor
@Test
func closingDialogMenuWhileStackedDialogIsOpenPreservesHoverSuppression() {
    PointerHoverScrollState.shared.resetForTesting()
    defer { PointerHoverScrollState.shared.resetForTesting() }

    let layers = InterfaceLayerRegistry()
    layers.setOpen(.dialog, true)

    var menuToken: InterfaceLayerRegistry.OpenMenuToken? =
        layers.registerOpenMenu(ownedBy: .dialog)
    #expect(PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)

    // Opening a stacked dialog from the dialog menu freezes `.dialog`;
    // closing the old menu afterward must keep hover suppressed for the new dialog.
    layers.setOpen(.stackedDialog, true)
    menuToken = nil
    _ = menuToken
    #expect(layers.isFrozen(.dialog))
    #expect(PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)

    // Closing the stacked dialog returns to `.dialog` and clears suppression.
    layers.setOpen(.stackedDialog, false)
    #expect(!PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)

    // Closing a dialog menu without a stacked dialog above it immediately clears suppression.
    menuToken = layers.registerOpenMenu(ownedBy: .dialog)
    #expect(PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)
    menuToken = nil
    _ = menuToken
    #expect(!PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)
}

@MainActor
@Test
func windowOcclusionRegionRespectsSublayerAndLayerIsolation() {
    let layers = InterfaceLayerRegistry()
    let region = WindowOcclusionRegion(
        hostLayer: .workbenchPage,
        minimumUnoccludedSublayer: .overlaySidebar,
        windowRect: CGRect(x: 0, y: 0, width: 240, height: 800)
    )
    layers.setWindowOcclusionRegion(region, forKey: "overlaySidebar")
    #expect(layers.hasWindowOcclusionRegions)

    let insidePoint = CGPoint(x: 120, y: 400)
    #expect(layers.isPointOccluded(insidePoint, on: .workbenchPage, sublayer: .content))
    #expect(!layers.isPointOccluded(insidePoint, on: .workbenchPage, sublayer: .overlaySidebar))
    #expect(!layers.isPointOccluded(insidePoint, on: .playbackOverlay, sublayer: .content))
    #expect(!layers.isPointOccluded(insidePoint, on: .dialog, sublayer: .content))

    #expect(layers.isPointOccluded(CGPoint(x: 239.5, y: 400), on: .workbenchPage))
    #expect(!layers.isPointOccluded(CGPoint(x: 240, y: 400), on: .workbenchPage))

    layers.setWindowOcclusionRegion(
        WindowOcclusionRegion(hostLayer: .workbenchPage, minimumUnoccludedSublayer: .overlaySidebar, windowRect: .zero),
        forKey: "overlaySidebar"
    )
    #expect(!layers.hasWindowOcclusionRegions)
    #expect(!layers.isPointOccluded(insidePoint, on: .workbenchPage))
}

@MainActor
@Test
func unoccludedWindowRectClipsStraddlingControls() {
    let layers = InterfaceLayerRegistry()
    layers.setWindowOcclusionRegion(
        WindowOcclusionRegion(
            hostLayer: .workbenchPage,
            minimumUnoccludedSublayer: .overlaySidebar,
            windowRect: CGRect(x: 0, y: 0, width: 240, height: 800)
        ),
        forKey: "overlaySidebar"
    )

    let whollyCovered = CGRect(x: 40, y: 100, width: 180, height: 30)
    #expect(layers.unoccludedWindowRect(whollyCovered, on: .workbenchPage, sublayer: .content) == nil)
    #expect(layers.unoccludedWindowRect(whollyCovered, on: .workbenchPage, sublayer: .overlaySidebar) == whollyCovered)

    let straddlingRight = CGRect(x: 180, y: 100, width: 200, height: 30)
    #expect(
        layers.unoccludedWindowRect(straddlingRight, on: .workbenchPage, sublayer: .content)
            == CGRect(x: 240, y: 100, width: 140, height: 30)
    )

    let outside = CGRect(x: 240, y: 100, width: 200, height: 30)
    #expect(layers.unoccludedWindowRect(outside, on: .workbenchPage, sublayer: .content) == outside)

    layers.setWindowOcclusionRegion(
        WindowOcclusionRegion(
            hostLayer: .workbenchPage,
            minimumUnoccludedSublayer: .overlaySidebar,
            windowRect: CGRect(x: 0, y: 0, width: 240, height: 300)
        ),
        forKey: "overlaySidebar"
    )
    let straddlingTop = CGRect(x: 20, y: 200, width: 100, height: 200)
    #expect(
        layers.unoccludedWindowRect(straddlingTop, on: .workbenchPage, sublayer: .content)
            == CGRect(x: 20, y: 300, width: 100, height: 100)
    )
}
