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
