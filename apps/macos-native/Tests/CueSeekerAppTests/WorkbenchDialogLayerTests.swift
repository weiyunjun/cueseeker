import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

/// The dialog layer registers itself from the dialogs it draws: open while
/// its list has a dialog in it, closed once the list is empty. A dialog added
/// to the list is registered with nothing else.
@MainActor
@Test
func dialogLayerIsOpenWhileItsListHasADialogAndClosedOnceItIsEmpty() {
    let layers = InterfaceLayerRegistry()
    let hostingView = NSHostingView(rootView: dialogLayer(dialogIDs: [], layers: layers))
    hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    hostingView.layoutSubtreeIfNeeded()
    #expect(!layers.isOpen(.dialog))

    hostingView.rootView = dialogLayer(dialogIDs: ["rename"], layers: layers)
    hostingView.layoutSubtreeIfNeeded()
    #expect(layers.isOpen(.dialog))
    #expect(layers.isCovered(.workbenchPage))

    // A second dialog stacking on the first keeps the layer open.
    hostingView.rootView = dialogLayer(dialogIDs: ["rename", "confirmation"], layers: layers)
    hostingView.layoutSubtreeIfNeeded()
    #expect(layers.isOpen(.dialog))

    // The kept dialog size goes with the layer, so the window hands the
    // keyboard out again.
    layers.topDialogSize = CGSize(width: 480, height: 320)
    hostingView.rootView = dialogLayer(dialogIDs: [], layers: layers)
    hostingView.layoutSubtreeIfNeeded()
    #expect(!layers.isOpen(.dialog))
    #expect(!layers.isCovered(.workbenchPage))
    #expect(layers.topDialogSize == nil)
    withExtendedLifetime(hostingView) {}
}

@MainActor
private func dialogLayer(
    dialogIDs: [AnyHashable],
    layers: InterfaceLayerRegistry
) -> AnyView {
    AnyView(
        WorkbenchDialogLayer(dialogIDs: dialogIDs, topBandHeight: 0) {
            EmptyView()
        }
        .environment(\.interfaceLayers, layers)
        .frame(width: 800, height: 600)
    )
}
