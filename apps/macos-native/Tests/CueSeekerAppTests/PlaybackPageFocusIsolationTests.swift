import AppKit
import CueSeekerCore
import CueSeekerPlayback
import Testing
@testable import CueSeekerApp

@MainActor
@Suite
struct PlaybackPageFocusIsolationTests {

    @Test
    func windowMakeFirstResponderRefusesCoveredViewAndAcceptsUncoveredView() {
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = container

        // Background text field (e.g. Workbench search field)
        let backgroundField = NSTextField(frame: NSRect(x: 100, y: 100, width: 200, height: 30))
        container.addSubview(backgroundField)

        // Before being covered, background field is uncovered and can become first responder
        #expect(window.isUncovered(backgroundField))
        #expect(window.makeFirstResponder(backgroundField))
        #expect(window.firstResponder === backgroundField || window.firstResponder is NSTextView)

        // Overlay view covering the background field (e.g. Playback page)
        let overlayView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.addSubview(overlayView)
        window.isWorkbenchCovered = { true }

        // Foreground text field in the overlay (e.g. Command Panel search field)
        let foregroundField = NSTextField(frame: NSRect(x: 100, y: 300, width: 200, height: 30))
        overlayView.addSubview(foregroundField)

        // Clear focus
        _ = window.makeFirstResponder(nil)

        // Background field is now covered by overlayView
        #expect(!window.isUncovered(backgroundField))
        // Window makeFirstResponder must refuse covered view
        #expect(!window.makeFirstResponder(backgroundField))
        #expect(window.firstResponder === window || window.firstResponder == nil)

        // Foreground field is uncovered and must be accepted
        #expect(window.isUncovered(foregroundField))
        #expect(window.makeFirstResponder(foregroundField))
        #expect(window.firstResponder === foregroundField || window.firstResponder is NSTextView)
    }

    @Test
    func workbenchViewsAlwaysAcceptedWhenWorkbenchNotCovered() {
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = container
        window.isWorkbenchCovered = { false }

        // Large scrolled document view (e.g. SubtitleVirtualTableDocumentView with 50+ rows)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 3000))
        scrollView.documentView = documentView
        container.addSubview(scrollView)

        // When workbench is not covered, makeFirstResponder must never be blocked by coverage logic
        #expect(window.makeFirstResponder(documentView))
        #expect(window.firstResponder === documentView)
    }

    @Test
    func windowKeyViewSelectionSkipsCoveredViews() {
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = container

        // Two background fields
        let background1 = NSTextField(frame: NSRect(x: 50, y: 50, width: 100, height: 30))
        let background2 = NSTextField(frame: NSRect(x: 200, y: 50, width: 100, height: 30))
        container.addSubview(background1)
        container.addSubview(background2)

        // Set up key view loop
        background1.nextKeyView = background2
        background2.nextKeyView = background1

        // Overlay covering everything
        let overlay = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.addSubview(overlay)
        window.isWorkbenchCovered = { true }

        _ = window.makeFirstResponder(nil)

        // Tab cycling when all candidates are covered must not focus any covered view
        window.selectKeyView(following: background1)
        #expect(window.firstResponder === window || window.firstResponder == nil)

        window.selectKeyView(preceding: background2)
        #expect(window.firstResponder === window || window.firstResponder == nil)

        // Add an uncovered field on top of the overlay
        let topField = NSTextField(frame: NSRect(x: 100, y: 300, width: 200, height: 30))
        overlay.addSubview(topField)

        background2.nextKeyView = topField
        topField.nextKeyView = background1

        // Tab cycling from background2 should skip covered background1 and focus topField
        window.selectKeyView(following: background2)
        #expect(window.firstResponder === topField || window.firstResponder is NSTextView)
    }

    @Test
    func coveredTextInputDoesNotSuppressPlaybackShortcuts() {
        let window = CueSeekerMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = container

        let backgroundField = NSTextField(frame: NSRect(x: 100, y: 100, width: 200, height: 30))
        container.addSubview(backgroundField)

        // When uncovered, isEditableTextInputFocused would be true if focused
        _ = window.makeFirstResponder(backgroundField)
        window.makeKeyAndOrderFront(nil)

        // Cover the field with overlay
        let overlay = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.addSubview(overlay)
        window.isWorkbenchCovered = { true }

        // Even if backgroundField was left as firstResponder, isEditableTextInputFocused must return false
        #expect(!window.isUncovered(backgroundField))
        #expect(!AppCoordinator.isEditableTextInputFocused())
    }

    @Test
    func openingPlaybackPageCoversWorkbenchPage() {
        let layers = InterfaceLayerRegistry()
        #expect(!layers.isOpen(.playbackPage))
        #expect(!layers.isCovered(.workbenchPage))

        layers.setOpen(.playbackPage, true)
        #expect(layers.isOpen(.playbackPage))
        #expect(layers.isCovered(.workbenchPage))

        layers.setOpen(.playbackPage, false)
        #expect(!layers.isOpen(.playbackPage))
        #expect(!layers.isCovered(.workbenchPage))
    }

    @Test
    func playbackKeyDownDropsOrphanedCoveredFirstResponder() async throws {
        try await withTestApp { app in
            let window = CueSeekerMainWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
            window.contentView = container

            let backgroundField = NSTextField(frame: NSRect(x: 100, y: 100, width: 200, height: 30))
            container.addSubview(backgroundField)
            _ = window.makeFirstResponder(backgroundField)
            window.makeKeyAndOrderFront(nil)

            let overlay = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
            container.addSubview(overlay)
            window.isWorkbenchCovered = { true }

            app.playback.isPlaybackSurfaceExpanded = true

            // When a shortcut key is pressed, orphaned covered focus should be dropped
            _ = app.handlePlaybackKeyDown(keyCode: 49, modifierFlagsRawValue: 0)

            #expect(window.firstResponder === window || window.firstResponder == nil)
        }
    }

    private func withTestApp(_ body: (AppCoordinator) async throws -> Void) async throws {
        let suiteName = "PlaybackPageFocusIsolationTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaybackPageFocusIsolationTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = fixtureRoot.appendingPathComponent("focus.sqlite")
        defer {
            userDefaults.removePersistentDomainAndPlist(forName: suiteName)
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
        app.search.selectResult(SubtitleSearchResult(
            entryID: 1,
            subtitlePath: "/Media/Normal-Playback.srt",
            subtitleFormat: .srt,
            videoPath: "/Media/Normal-Playback.mkv",
            videoName: "Normal Playback",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: "normal playback cue",
            cueLines: ["normal playback cue"]
        ))
        app.playback.playbackViewModel = PlaybackViewModel(player: PlaybackPlayer())
        app.playback.playbackStatus = .paused
        try await body(app)
    }
}
