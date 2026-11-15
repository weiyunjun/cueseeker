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

@Test
func dialogMotionTokensCurvesAndExteriorClipMatchSpec() {
    #expect(WorkbenchDialogMotion.duration == 0.27)
    #expect(WorkbenchDialogMotion.fadeInDuration == 0.12)
    #expect(WorkbenchDialogMotion.fadeOutDuration == 0.22)
    #expect(WorkbenchDialogMotion.reduceMotionDuration == 0.18)
    #expect(WorkbenchDialogMotion.distance == 34)
    #expect(WorkbenchDialogMotion.fadeInDuration < WorkbenchDialogMotion.duration)
    #expect(WorkbenchDialogMotion.fadeOutDuration < WorkbenchDialogMotion.duration)

    for curve in [
        WorkbenchDialogMotion.enterEasing,
        WorkbenchDialogMotion.exitEasing,
        WorkbenchDialogMotion.fadeInEasing,
        WorkbenchDialogMotion.fadeOutEasing,
        WorkbenchDialogMotion.scrimEasing
    ] {
        #expect(curve.value(at: 0) == 0)
        #expect(curve.value(at: 1) == 1)
        let q1 = curve.value(at: 0.25)
        let mid = curve.value(at: 0.5)
        let q3 = curve.value(at: 0.75)
        #expect(q1 > 0 && q1 < mid)
        #expect(mid < q3 && q3 < 1)
    }

    #expect(!WorkbenchDialogMotion.showsScrim(hasOpenDialogs: false, isSystemSheetAttached: false))
    #expect(WorkbenchDialogMotion.showsScrim(hasOpenDialogs: true, isSystemSheetAttached: false))
    #expect(!WorkbenchDialogMotion.showsScrim(hasOpenDialogs: true, isSystemSheetAttached: true))
    #expect(!WorkbenchDialogMotion.showsScrim(hasOpenDialogs: false, isSystemSheetAttached: true))

    let clipPath = WorkbenchExteriorClipShape(
        cornerRadius: 12,
        outset: 1.5,
        cornerStyle: .circular
    ).path(in: CGRect(x: 0, y: 0, width: 200, height: 120)).cgPath
    #expect(!clipPath.contains(CGPoint(x: 100, y: 60), using: .evenOdd))
    #expect(clipPath.contains(CGPoint(x: -0.5, y: 60), using: .evenOdd))

    // Reduce Motion helpers switch scrim and dialog transactions cleanly.
    #expect(WorkbenchDialogMotion.scrimAnimation(reducesMotion: true) == WorkbenchDialogMotion.reduceMotionAnimation)
    #expect(WorkbenchDialogMotion.scrimAnimation(reducesMotion: false) != WorkbenchDialogMotion.reduceMotionAnimation)
    #expect(WorkbenchDialogMotion.dialogTransactionAnimation(reducesMotion: true) == WorkbenchDialogMotion.reduceMotionAnimation)
    #expect(WorkbenchDialogMotion.dialogTransactionAnimation(reducesMotion: false) != WorkbenchDialogMotion.reduceMotionAnimation)
}

@Test
func dialogTransitionFrameComputesSynchronizedOpacityAndOffset() {
    let enterStart = WorkbenchDialogMotion.transitionFrame(
        progress: 0,
        isEntering: true,
        reducesMotion: false
    )
    #expect(enterStart == .init(opacity: 0, offsetY: -WorkbenchDialogMotion.distance))

    let enterMidFade = WorkbenchDialogMotion.transitionFrame(
        progress: (WorkbenchDialogMotion.fadeInDuration * 0.5) / WorkbenchDialogMotion.duration,
        isEntering: true,
        reducesMotion: false
    )
    #expect(abs(enterMidFade.opacity - WorkbenchDialogMotion.fadeInEasing.value(at: 0.5)) < 1e-6)
    #expect(enterMidFade.offsetY > -WorkbenchDialogMotion.distance && enterMidFade.offsetY < 0)

    let enterFadeComplete = WorkbenchDialogMotion.transitionFrame(
        progress: WorkbenchDialogMotion.fadeInDuration / WorkbenchDialogMotion.duration,
        isEntering: true,
        reducesMotion: false
    )
    #expect(enterFadeComplete.opacity == 1)
    #expect(enterFadeComplete.offsetY > -WorkbenchDialogMotion.distance && enterFadeComplete.offsetY < 0)

    let enterEnd = WorkbenchDialogMotion.transitionFrame(
        progress: 1,
        isEntering: true,
        reducesMotion: false
    )
    #expect(enterEnd == .init(opacity: 1, offsetY: 0))

    let exitStart = WorkbenchDialogMotion.transitionFrame(
        progress: 1,
        isEntering: false,
        reducesMotion: false
    )
    #expect(exitStart == .init(opacity: 1, offsetY: 0))

    let exitMidFade = WorkbenchDialogMotion.transitionFrame(
        progress: 1 - (WorkbenchDialogMotion.fadeOutDuration * 0.5) / WorkbenchDialogMotion.duration,
        isEntering: false,
        reducesMotion: false
    )
    #expect(abs(exitMidFade.opacity - (1 - WorkbenchDialogMotion.fadeOutEasing.value(at: 0.5))) < 1e-6)
    #expect(exitMidFade.offsetY > -WorkbenchDialogMotion.distance && exitMidFade.offsetY < 0)

    let exitFadeComplete = WorkbenchDialogMotion.transitionFrame(
        progress: 1 - WorkbenchDialogMotion.fadeOutDuration / WorkbenchDialogMotion.duration,
        isEntering: false,
        reducesMotion: false
    )
    #expect(exitFadeComplete.opacity == 0)
    #expect(exitFadeComplete.offsetY > -WorkbenchDialogMotion.distance && exitFadeComplete.offsetY < 0)

    let exitEnd = WorkbenchDialogMotion.transitionFrame(
        progress: 0,
        isEntering: false,
        reducesMotion: false
    )
    #expect(exitEnd == .init(opacity: 0, offsetY: -WorkbenchDialogMotion.distance))

    for isEntering in [true, false] {
        for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let frame = WorkbenchDialogMotion.transitionFrame(
                progress: progress,
                isEntering: isEntering,
                reducesMotion: true
            )
            #expect(frame == .init(opacity: progress, offsetY: 0))
        }
    }

    #expect(
        WorkbenchDialogMotion.transitionFrame(progress: -0.25, isEntering: true, reducesMotion: false)
            == .init(opacity: 0, offsetY: -WorkbenchDialogMotion.distance)
    )
    #expect(
        WorkbenchDialogMotion.transitionFrame(progress: 1.25, isEntering: false, reducesMotion: false)
            == .init(opacity: 1, offsetY: 0)
    )
}

@MainActor
@Test
func systemSheetCompletionRestoresScrimEarlyAndPreservesDialogLayerState() {
    let layers = InterfaceLayerRegistry()
    let hostingView = NSHostingView(
        rootView: dialogLayer(
            dialogIDs: ["ankiExport"],
            layers: layers,
            isSystemSheetAttached: layers.isSystemSheetAttached
        )
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    hostingView.layoutSubtreeIfNeeded()
    #expect(layers.isOpen(.dialog))
    #expect(layers.isCovered(.workbenchPage))

    layers.setSystemSheetAttached(true)
    hostingView.rootView = dialogLayer(
        dialogIDs: ["ankiExport"],
        layers: layers,
        isSystemSheetAttached: layers.isSystemSheetAttached
    )
    hostingView.layoutSubtreeIfNeeded()
    #expect(layers.isSystemSheetAttached)
    #expect(layers.isOpen(.dialog))

    // Another sheet underneath keeps the custom scrim yields intact.
    SystemSheetPresentation.releaseScrimOnCompletion(for: layers, activeSheetCount: 2)
    #expect(layers.isSystemSheetAttached)

    // Dismissing the active file panel restores custom scrim immediately while
    // keeping the underlying dialog layer open and covering the page.
    SystemSheetPresentation.releaseScrimOnCompletion(for: layers, activeSheetCount: 1)
    #expect(!layers.isSystemSheetAttached)
    #expect(layers.isOpen(.dialog))
    #expect(layers.isCovered(.workbenchPage))

    hostingView.rootView = dialogLayer(
        dialogIDs: ["ankiExport", "confirmation"],
        layers: layers,
        isSystemSheetAttached: layers.isSystemSheetAttached
    )
    hostingView.layoutSubtreeIfNeeded()
    #expect(layers.isOpen(.dialog))
    withExtendedLifetime(hostingView) {}
}

@MainActor
private func dialogLayer(
    dialogIDs: [AnyHashable],
    layers: InterfaceLayerRegistry,
    isSystemSheetAttached: Bool = false
) -> AnyView {
    AnyView(
        WorkbenchDialogLayer(dialogIDs: dialogIDs, topBandHeight: 40) {
            ForEach(Array(dialogIDs.enumerated()), id: \.offset) { index, id in
                Text(String(describing: id))
                    .frame(width: 320, height: 180)
                    .workbenchDialog(
                        level: Double(index + 1),
                        isCovered: index < dialogIDs.count - 1
                    )
            }
        }
        .environment(\.interfaceLayers, layers)
        .environment(\.isSystemSheetAttached, isSystemSheetAttached)
        .frame(width: 800, height: 600)
    )
}
