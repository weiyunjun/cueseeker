import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackPlaylistReelAdapterUsesResidentDatasetImmediately() throws {
    _ = NSApplication.shared
    let source = playbackPlaylistReelSource(totalCount: 40)
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false
    )

    #expect(adapter.snapshot.datasetID.base is String)
    #expect(adapter.snapshot.datasetID == AnyHashable(source.boundary.datasetID.uuidString))
    #expect(adapter.snapshot.loadedOrdinalRange == (0..<40))
    #expect(adapter.snapshot.isComplete)
    #expect(adapter.itemID(at: 20) == AnyHashable(PlaybackPlaylistItemIdentity.search(1_020)))
    let item = try #require(adapter.item(at: 20))
    #expect(adapter.cueResult(at: 20)?.metadata?.displayTitle == item.displayTitle)
    #expect(adapter.cueResult(at: 20)?.metadata?.timeRange == item.timeRange)
    #expect(adapter.cueResult(at: 20)?.additionalCueTexts == ["context-20"])
}

@MainActor
@Test
func playbackCueResultReelRapidScrollbarDragUsesResidentDataset() async throws {
    _ = NSApplication.shared
    let totalCount = 50_000
    let source = playbackPlaylistReelSource(
        kind: .excerpt,
        totalCount: totalCount
    )
    let dataset = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: dataset,
        showsCueGroup: true
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.onCommitVirtualReelSelection = dataset.commitSelection
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .began,
        positionFraction: 0
    ))
    for step in 1...1_000 {
        view.handleScrollbarDrag(TableScrollbarDragEvent(
            axis: .vertical,
            phase: .changed,
            positionFraction: 0.75 * CGFloat(step) / 1_000
        ))
    }
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    await Task.yield()

    #expect(dataset.snapshot.loadedItemCount == totalCount)
    #expect(dataset.selectedOrdinal == 37_499)
    #expect(adapter.measurementCacheCountForTesting <= 64)
    #expect(adapter.measuredOrdinalsForTesting.count <= 64)
    #expect(view.placementsForTesting.count < 50)

    let selectedOrdinal = try #require(dataset.selectedOrdinal)
    let nextOrdinal = selectedOrdinal + 1
    let selectedBefore = try #require(
        view.placementsForTesting.first { $0.ordinal == selectedOrdinal }
    )
    let nextBefore = try #require(
        view.placementsForTesting.first { $0.ordinal == nextOrdinal }
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: nextOrdinal,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    let selectedAfter = try #require(
        view.placementsForTesting.first { $0.ordinal == selectedOrdinal }
    )
    let nextAfter = try #require(
        view.placementsForTesting.first { $0.ordinal == nextOrdinal }
    )
    #expect(view.displayedSelectedOrdinalForTesting == nextOrdinal)
    #expect(adapter.measuredOrdinalsForTesting.contains(selectedOrdinal))
    #expect(adapter.measuredOrdinalsForTesting.contains(nextOrdinal))
    #expect(selectedBefore.extent == selectedAfter.extent)
    #expect(nextBefore.extent == nextAfter.extent)
    #expect(
        abs(
            (nextBefore.rect.midY - selectedBefore.rect.midY)
                - (nextAfter.rect.midY - selectedAfter.rect.midY)
        ) < 0.000_001
    )
    #expect(
        adapter.cueResult(at: selectedOrdinal)?.additionalCueTexts
            == ["context-\(selectedOrdinal)"]
    )
    #expect(
        adapter.cueResult(at: nextOrdinal)?.additionalCueTexts
            == ["context-\(nextOrdinal)"]
    )

    let keyboardTarget = nextOrdinal + 1
    let keyboardDatasetID = try #require(
        adapter.snapshot.datasetID.base as? String
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: nextOrdinal,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: keyboardTarget,
            contentDatasetID: keyboardDatasetID,
            contentGeneration: adapter.snapshot.generation
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: true
    )
    await Task.yield()
    await Task.yield()
    #expect(dataset.selectedOrdinal == keyboardTarget)
    #expect(view.displayedSelectedOrdinalForTesting == keyboardTarget)
    #expect(
        adapter.cueResult(at: keyboardTarget)?.additionalCueTexts
            == ["context-\(keyboardTarget)"]
    )

    view.invalidate()
    dataset.invalidate()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistReelAdapterCueGroupRevisionAndMeasurementsStayBounded() throws {
    _ = NSApplication.shared
    let source = playbackPlaylistReelSource(totalCount: 3)
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false,
        measurementCacheCapacity: 2
    )

    let primaryOnlyExtent = try #require(adapter.extent(
        at: 0,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    let selectedPrimaryOnlyExtent = try #require(adapter.extent(
        at: 0,
        isSelected: true,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    #expect(adapter.measurementCacheCountForTesting == 1)
    #expect(selectedPrimaryOnlyExtent == primaryOnlyExtent)
    _ = adapter.extent(
        at: 1,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    )
    _ = adapter.extent(
        at: 2,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    )

    #expect(adapter.measurementCacheCountForTesting == 2)
    #expect(adapter.measuredOrdinalsForTesting == [1, 2])

    let beforeCueGroup = adapter.snapshot
    #expect(adapter.setShowsCueGroup(true))
    let withCueGroup = adapter.snapshot

    #expect(withCueGroup.datasetID == beforeCueGroup.datasetID)
    #expect(withCueGroup.generation == beforeCueGroup.generation)
    #expect(withCueGroup.revision == beforeCueGroup.revision + 1)
    #expect(adapter.measurementCacheCountForTesting == 0)
    #expect(adapter.measuredOrdinalsForTesting.isEmpty)
    #expect(!adapter.setShowsCueGroup(true))

    let cueGroupExtent = try #require(adapter.extent(
        at: 0,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    #expect(cueGroupExtent.naturalHeight > primaryOnlyExtent.naturalHeight)
}

@MainActor
@Test
func playbackCueResultReelNonTextDragEntryFromMetadataAndMarginsCoexistsWithStaticText() throws {
    _ = NSApplication.shared
    WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
    defer { WorkbenchStaticTextSelectionCoordinator.shared.clearSelection() }

    let source = playbackPlaylistReelSource(kind: .search, totalCount: 3)
    let sessionWindow = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: sessionWindow,
        showsCueGroup: true
    )

    let window = CueSeekerMainWindow(
        contentRect: CGRect(x: 0, y: 0, width: 640, height: 700),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    let container = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 700))
    window.contentView = container
    defer { window.contentView = nil }

    let reelView = PlaybackSubtitleFocusReelContainerView(
        frame: CGRect(x: 0, y: 44, width: 640, height: 656)
    )
    var presentedTexts: [String] = []
    var copiedTexts: [String] = []
    reelView.onCopySelectedText = { copiedTexts.append($0) }
    container.addSubview(reelView)

    let footerStatusView = WorkbenchSelectableTextNSView(
        frame: CGRect(x: 24, y: 8, width: 220, height: 24)
    )
    footerStatusView.configure(
        text: "12 / 120 cues",
        font: .systemFont(ofSize: 13, weight: .regular),
        textColor: .secondaryLabelColor,
        alignment: .left,
        lineLimit: 1,
        truncatesTail: true,
        isSelectable: true,
        preferredPointerShape: .iBeam,
        showsUnderline: false,
        onTap: nil,
        interfaceLayerContext: InterfaceLayerContext()
    )
    container.addSubview(footerStatusView)
    footerStatusView.prepareLayoutForFlow()

    reelView.update(
        contentAdapter: adapter,
        selectedOrdinal: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    container.layoutSubtreeIfNeeded()

    let documentView = reelView.documentViewForTesting
    let originalPresent = documentView.onPresentSelectedTextActions
    documentView.onPresentSelectedTextActions = { text, ordinal, pointInCue in
        presentedTexts.append(text)
        originalPresent(text, ordinal, pointInCue)
    }
    let placements = reelView.placementsForTesting
    let firstPlacement = try #require(placements.first)
    let lineRects = documentView.selectableTextRectsForTesting(at: firstPlacement.ordinal)
    let primaryRect = try #require(lineRects.first)
    let lastRect = try #require(lineRects.last)

    // 1. Start in metadata/bottom area below selectable text rects -> drag up-left into cue group line.
    let metadataStart = CGPoint(x: lastRect.maxX - 4, y: firstPlacement.rect.maxY - 6)
    #expect(!lineRects.contains { $0.contains(metadataStart) })
    let insideLastLine = CGPoint(x: lastRect.minX + 18, y: lastRect.midY)

    documentView.mouseDown(with: NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: documentView.convert(metadataStart, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    documentView.mouseDragged(with: NSEvent.mouseEvent(
        with: .leftMouseDragged,
        location: documentView.convert(insideLastLine, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    documentView.mouseUp(with: NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: documentView.convert(insideLastLine, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    #expect(presentedTexts.count == 1)
    #expect(presentedTexts[0].hasSuffix("-0"))
    #expect(reelView.selectedTextMenuFrameForTesting != nil)

    // 2. Select footer status text -> Cue Reel selection and action menu dismiss; then reel drag clears static text.
    footerStatusView.prepareLayoutForFlow()
    let footerStart = footerStatusView.convert(CGPoint(x: 2, y: footerStatusView.bounds.midY), to: nil)
    let footerEnd = footerStatusView.convert(
        CGPoint(x: max(12, min(110, footerStatusView.bounds.width - 2)), y: footerStatusView.bounds.midY),
        to: nil
    )
    footerStatusView.mouseDown(with: NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: footerStart,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    )!)
    footerStatusView.mouseDragged(with: NSEvent.mouseEvent(
        with: .leftMouseDragged,
        location: footerEnd,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    )!)
    footerStatusView.mouseUp(with: NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: footerEnd,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 0
    )!)
    #expect(footerStatusView.hasSelection)
    #expect(!documentView.hasTextSelectionForTesting)
    #expect(reelView.selectedTextMenuFrameForTesting == nil)

    let aboveFirst = CGPoint(x: primaryRect.minX + 8, y: max(1, firstPlacement.rect.minY - 8))
    let intoPrimary = CGPoint(x: primaryRect.maxX - 4, y: primaryRect.midY)
    documentView.mouseDown(with: NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: documentView.convert(aboveFirst, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    documentView.mouseDragged(with: NSEvent.mouseEvent(
        with: .leftMouseDragged,
        location: documentView.convert(intoPrimary, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    documentView.mouseUp(with: NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: documentView.convert(intoPrimary, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!)
    #expect(!footerStatusView.hasSelection)
    #expect(WorkbenchStaticTextSelectionCoordinator.shared.selectedText == nil)
    #expect(presentedTexts.count == 2)
    #expect(presentedTexts[1].hasPrefix("primary"))

    reelView.invalidate()
    sessionWindow.invalidate()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistReelAdapterInvalidationPreservesItsSessionWindow() throws {
    let source = playbackPlaylistReelSource(totalCount: 2)
    let originalBoundary = source.boundary
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: true
    )

    adapter.invalidate()

    #expect(adapter.snapshot.totalCount == 2)
    #expect(adapter.item(at: 0) == nil)
    #expect(window.item(at: 0)?.identity == .search(1_000))
    #expect(window.selectedOrdinal == 0)
    #expect(source.hasItems)
    #expect(source.boundary == originalBoundary)

    window.invalidate()
    let replacementWindow = try #require(source.makeSessionWindowStore())
    #expect(replacementWindow.snapshot.totalCount == 2)
    replacementWindow.invalidate()
}

@MainActor
@Test
func playbackCueResultReelAdapterReusesPreparedGeometryAcrossColorFadeFrames() throws {
    _ = NSApplication.shared
    let source = playbackPlaylistReelSource(totalCount: 10)
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: window,
        showsCueGroup: true
    )
    let rect = CGRect(x: 0, y: 0, width: 800, height: 120)
    let rep = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 800,
            pixelsHigh: 120,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    )
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    for step in 0..<10 {
        let progress = CGFloat(step) / 9
        adapter.drawItem(
            at: 3,
            isSelected: true,
            selectionProgress: progress,
            isEnabled: true,
            selectedTextRange: nil,
            in: rect
        )
    }

    #expect(adapter.geometryPreparationCountForTesting(at: 3) == 1)
    adapter.invalidate()
    window.invalidate()
    source.invalidate()
}

@MainActor
private func playbackPlaylistReelSource(
    kind: PlaybackPlaylistSourceKind = .search,
    totalCount: Int
) -> PlaybackPlaylistSource {
    PlaybackPlaylistSource(kind: kind, totalCount: totalCount) { ordinal in
        guard ordinal >= 0, ordinal < totalCount else {
            return nil
        }
        let id = Int64(1_000 + ordinal)
        let primary = "primary-\(ordinal)"
        return PlaybackPlaylistItem(
            searchResult: SubtitleSearchResult(
                entryID: id,
                cueGroupID: id + 100,
                cueEventIndex: ordinal,
                cueDisplayOrder: 1,
                primaryGroupIndex: 1,
                subtitlePath: "/subtitle/\(id).ass",
                subtitleFormat: .ass,
                videoPath: "/video/\(id).mkv",
                videoName: "\(id).mkv",
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 500,
                content: primary,
                cueLines: ["context-\(ordinal)", primary],
                cueGroupLines: ["context-\(ordinal)", primary],
                searchRank: ordinal
            ),
            ordinal: ordinal
        )
    }
}
