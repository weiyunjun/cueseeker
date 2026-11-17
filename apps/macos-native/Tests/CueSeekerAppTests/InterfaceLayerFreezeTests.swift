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
