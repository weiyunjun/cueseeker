import AppKit
@testable import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WorkbenchAccessibilityStep1Tests {
    private func makeTestCoordinator() -> (AppCoordinator, String, UserDefaults) {
        let suiteName = "WorkbenchAccessibilityStep1Tests-\(UUID().uuidString)"
        let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
        let app = AppCoordinator(userDefaults: userDefaults)
        return (app, suiteName, userDefaults)
    }

    @Test
    func topbarAndSidebarSequenceIncludesDisabledAndSelectedAndSkipsCollapsedSidebar() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.activateWorkbenchPanelMode(.recentWatching)
        app.workbenchLayout.selectRecentSection(.videos)
        app.workbenchLayout.isSidebarVisible = true
        let expandedTargets = app.currentWorkbenchAccessibilityTargets()

        #expect(expandedTargets.starts(with: [
            .topbarSidebarToggle,
            .topbarBackButton,
            .topbarForwardButton,
            .topbarRecentSegment(.videos),
            .topbarRecentSegment(.excerpts),
            .topbarTaskButton,
            .topbarSettingsButton,
            .sidebarItem(.search),
            .sidebarItem(.recentWatching),
            .sidebarItem(.testLibrary),
            .sidebarItem(.file),
            .sidebarItem(.excerpt),
        ]))

        // Activating disabled Forward button or already-selected Recent segment does nothing
        // and keeps accessibility focus on that target.
        app.workbenchAccessibility.setFocus(.topbarForwardButton)
        #expect(!app.activateWorkbenchAccessibilityTarget(.topbarForwardButton))
        #expect(app.workbenchAccessibility.focusedTarget == .topbarForwardButton)

        app.workbenchAccessibility.setFocus(.topbarRecentSegment(.videos))
        #expect(app.activateWorkbenchAccessibilityTarget(.topbarRecentSegment(.videos)))
        #expect(app.workbenchAccessibility.focusedTarget == .topbarRecentSegment(.videos))

        // Activating another Sidebar item switches page and keeps focus on that Sidebar item.
        app.workbenchAccessibility.setFocus(.sidebarItem(.file))
        #expect(app.activateWorkbenchAccessibilityTarget(.sidebarItem(.file)))
        #expect(app.workbenchLayout.currentRoute == .file)
        #expect(app.workbenchAccessibility.focusedTarget == .sidebarItem(.file))

        // Collapsing the sidebar removes sidebar items from the accessibility sequence,
        // while keeping File top buttons and status indicator even when disabled/idle.
        app.workbenchLayout.isSidebarVisible = false
        let collapsedTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(!collapsedTargets.contains(.sidebarItem(.search)))
        #expect(collapsedTargets.starts(with: [
            .topbarSidebarToggle,
            .topbarBackButton,
            .topbarForwardButton,
            .topbarTaskButton,
            .topbarSettingsButton,
            .fileAddFolderButton,
            .fileIndexNowButton,
            .fileStatusIndicatorText,
        ]))
    }

    @Test
    func tabStartsAtFirstShiftTabStartsAtLastAndWrapsAround() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        #expect(!app.workbenchAccessibility.isActive)

        // Pressing R1 / Tab when inactive selects the 1st target.
        #expect(app.handleWorkbenchControllerInput(.button(.rightShoulder, isRepeat: false)))
        let targets = app.currentWorkbenchAccessibilityTargets()
        #expect(app.workbenchAccessibility.focusedTarget == targets.first)

        // Pressing L1 / Shift+Tab wraps from first to last.
        #expect(app.handleWorkbenchControllerInput(.button(.leftShoulder, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == targets.last)

        // Pressing R1 / Tab wraps from last back to first.
        #expect(app.handleWorkbenchControllerInput(.button(.rightShoulder, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == targets.first)

        // Pressing East (Circle) / Esc clears accessibility.
        #expect(app.handleWorkbenchControllerInput(.button(.east, isRepeat: false)))
        #expect(!app.workbenchAccessibility.isActive)

        // Pressing L1 / Shift+Tab when inactive selects the last target.
        #expect(app.handleWorkbenchControllerInput(.button(.leftShoulder, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == targets.last)
    }

    @Test
    func searchToolbarClearButtonDisappearanceAutomaticallyExitsAccessibility() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.activateWorkbenchPanelMode(.search)
        app.updateSearchQuery("hello")

        let targetsWithClear = app.currentWorkbenchAccessibilityTargets()
        #expect(targetsWithClear.contains(.toolbarSearchField))
        #expect(targetsWithClear.contains(.toolbarSearchClearButton))

        app.workbenchAccessibility.setFocus(.toolbarSearchClearButton)
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarSearchClearButton))
        #expect(app.search.searchQuery.isEmpty)
        // Because the inline clear button disappeared after clearing text, accessibility exits.
        #expect(app.workbenchAccessibility.focusedTarget == nil)
    }

    @Test
    func tableNormalAndSelectModeSequencesAndTwoStepEscapePriority() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.activateWorkbenchPanelMode(.search)
        app.workbenchAccessibility.isTableInSelectionMode = false
        app.workbenchAccessibility.tableTargetsOverrideForTesting = {
            [
                .tableHeaderCheckbox,
                .tableRowCheckbox(0),
                .tableRowCueText(0),
                .tableRowActionButton(0),
                .tableRowActionButton(1),
            ]
        }

        let normalTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(normalTargets.suffix(8) == [
            .toolbarSearchField,
            .toolbarFilterButton,
            .toolbarSortButton,
            .tableHeaderCheckbox,
            .tableRowCheckbox(0),
            .tableRowCueText(0),
            .tableRowActionButton(0),
            .tableRowActionButton(1),
        ])

        // Enter Select Mode: toolbar switches to selection action buttons and table rows
        // only expose available row checkboxes.
        var exitedSelectionMode = false
        app.workbenchAccessibility.isTableInSelectionMode = true
        app.workbenchAccessibility.onExitTableSelectionMode = {
            exitedSelectionMode = true
            app.workbenchAccessibility.isTableInSelectionMode = false
        }
        app.workbenchAccessibility.tableTargetsOverrideForTesting = {
            [
                .tableHeaderCheckbox,
                .tableRowCheckbox(0),
            ]
        }

        let selectModeTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(selectModeTargets.suffix(6) == [
            .toolbarExitSelectButton,
            .toolbarSelectionAction(.exportToAnki),
            .toolbarSelectionAction(.copyDeepLinks),
            .toolbarSelectionAction(.copyTable),
            .tableHeaderCheckbox,
            .tableRowCheckbox(0),
        ])

        // While accessibility is active in Select Mode, 1st Esc / Circle only clears
        // accessibility; 2nd Esc / Circle exits Select Mode.
        app.workbenchAccessibility.setFocus(.tableHeaderCheckbox)
        #expect(app.handleWorkbenchControllerInput(.button(.east, isRepeat: false)))
        #expect(!app.workbenchAccessibility.isActive)
        #expect(!exitedSelectionMode)

        #expect(app.handleWorkbenchControllerInput(.button(.east, isRepeat: false)))
        #expect(exitedSelectionMode)
    }

    @Test
    func workbenchCoverCardGridSyncsSelectSuppressesHoverAndClearsSelectOnLeaveOrExit() {
        AppCursorVisibility.resetForTesting()
        PointerHoverScrollState.shared.resetForTesting()
        defer {
            AppCursorVisibility.resetForTesting()
            PointerHoverScrollState.shared.resetForTesting()
        }

        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let workbenchHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: false)
        let playbackHighlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
        playbackHighlight.setSelected("playback-ep1")

        app.activateWorkbenchPanelMode(.testLibrary)
        app.library.completeLibraryStatus = .idle
        app.library.completeLibraryFolderSummaries = [
            CompleteLibraryFolderSummaryPresentation(
                folderPath: "/Media/ShowA",
                folderTitle: "Show A",
                coverPath: nil,
                coverRevision: nil,
                episodeCount: 2,
                indexedAt: "2026-01-01T00:00:00Z"
            ),
            CompleteLibraryFolderSummaryPresentation(
                folderPath: "/Media/ShowB",
                folderTitle: "Show B",
                coverPath: nil,
                coverRevision: nil,
                episodeCount: 3,
                indexedAt: "2026-01-02T00:00:00Z"
            ),
        ]
        app.workbenchAccessibility.cardGridColumnCount = 2

        let displayed = app.library.displayedCompleteLibraryFolderSummaries
        let firstID = displayed[0].id
        let secondID = displayed[1].id

        let targets = app.currentWorkbenchAccessibilityTargets()
        #expect(targets.suffix(6) == [
            .toolbarSearchField,
            .toolbarSortButton,
            .mediaCard(firstID),
            .mediaCardActionButton(firstID),
            .mediaCard(secondID),
            .mediaCardActionButton(secondID),
        ])

        // 1. Before entering the card grid, mouse hovers the 1st card.
        workbenchHighlight.noteHover(true, id: firstID, showsHand: true)
        #expect(workbenchHighlight.selectedID == nil)
        #expect(workbenchHighlight.hoveredID == firstID)
        #expect(workbenchHighlight.isHovered(firstID))
        #expect(workbenchHighlight.isPointerHovered(firstID))
        #expect(AppPointerShape.model.shape == .grab)

        // When focus is on a toolbar button outside the card grid, directional keys do nothing
        // and card Hover is not suppressed because toolbar Sort button is not a Select area.
        app.workbenchAccessibility.setFocus(.toolbarSortButton)
        #expect(!app.handleWorkbenchControllerInput(.direction(.right, source: .directionalPad, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == .toolbarSortButton)
        #expect(workbenchHighlight.selectedID == nil)
        #expect(workbenchHighlight.hoveredID == firstID)

        // 2. Accessibility focus enters the 1st card (.mediaCard(firstID)):
        // Select is set to firstID, existing Hover is immediately cancelled and suppressed,
        // and pointer shape reverts from Grab to Arrow.
        app.workbenchAccessibility.setFocus(.mediaCard(firstID))
        #expect(workbenchHighlight.selectedID == firstID)
        #expect(workbenchHighlight.isSelected(firstID))
        #expect(!workbenchHighlight.isHovered(firstID))
        #expect(!workbenchHighlight.isPointerHovered(firstID))
        #expect(workbenchHighlight.isSuppressedByKeyboard)
        #expect(PointerHoverScrollState.shared.isSuppressedByKeyboardOrController)
        #expect(AppPointerShape.model.shape == .arrow)
        #expect(playbackHighlight.selectedID == "playback-ep1")

        // 3. Physical mouse movement onto the Selected card restores pointer hover
        // without stacking Hover visual style over Select visual style.
        PointerHoverScrollState.shared.notePointerMoved()
        workbenchHighlight.noteHover(true, id: firstID, showsHand: true)
        #expect(workbenchHighlight.isSelected(firstID))
        #expect(!workbenchHighlight.isHovered(firstID))
        #expect(workbenchHighlight.isPointerHovered(firstID))
        #expect(AppPointerShape.model.shape == .grab)

        // 4. Moving focus within the same card to its action button (.mediaCardActionButton(firstID))
        // keeps Select on firstID and immediately cancels/suppresses mouse Hover again.
        app.workbenchAccessibility.setFocus(.mediaCardActionButton(firstID))
        #expect(app.workbenchAccessibility.focusedTarget?.mediaCardID == firstID)
        #expect(workbenchHighlight.selectedID == firstID)
        #expect(!workbenchHighlight.isPointerHovered(firstID))
        #expect(workbenchHighlight.isSuppressedByKeyboard)
        #expect(AppPointerShape.model.shape == .arrow)

        // 5. Pressing Right from the 1st card's action button moves to the 2nd card's whole card
        // and updates Select to secondID.
        #expect(app.handleWorkbenchControllerInput(.direction(.right, source: .directionalPad, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == .mediaCard(secondID))
        #expect(workbenchHighlight.selectedID == secondID)
        #expect(!workbenchHighlight.isSelected(firstID))
        #expect(workbenchHighlight.isSelected(secondID))

        // Pressing Right again at the right boundary still suppresses any restored mouse Hover.
        PointerHoverScrollState.shared.notePointerMoved()
        workbenchHighlight.noteHover(true, id: secondID, showsHand: true)
        #expect(workbenchHighlight.isPointerHovered(secondID))
        #expect(app.handleWorkbenchControllerInput(.direction(.right, source: .directionalPad, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == .mediaCard(secondID))
        #expect(workbenchHighlight.selectedID == secondID)
        #expect(!workbenchHighlight.isPointerHovered(secondID))
        #expect(workbenchHighlight.isSuppressedByKeyboard)

        // 6. Moving accessibility focus out of the card grid immediately clears Workbench card Select,
        // while Playback retains its mandatory persistent Select.
        app.workbenchAccessibility.setFocus(.toolbarSortButton)
        #expect(workbenchHighlight.selectedID == nil)
        #expect(!workbenchHighlight.isSelected(secondID))
        #expect(playbackHighlight.selectedID == "playback-ep1")

        // 7. Re-entering the card grid and pressing Esc / Circle to exit accessibility
        // also immediately clears Workbench card Select.
        app.workbenchAccessibility.setFocus(.mediaCard(firstID))
        #expect(workbenchHighlight.selectedID == firstID)
        #expect(app.handleWorkbenchControllerInput(.button(.east, isRepeat: false)))
        #expect(!app.workbenchAccessibility.isActive)
        #expect(workbenchHighlight.selectedID == nil)
        #expect(playbackHighlight.selectedID == "playback-ep1")
    }

    @Test
    func controllerRoutesToOpenMenuGateWithAccessibilityAndDismissRules() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let highlight = MenuHighlightModel()
        highlight.open(selectablePositions: [0, 2], allPositions: [0, 1, 2])
        var dismissed = false
        var activated: [Int] = []
        let session = app.interfaceLayers.menuGate.open(
            MenuGate.Client(
                owner: .workbenchPage,
                kind: .cardMenu,
                window: { nil },
                isPointerOnMenu: { _ in false },
                handleKey: { keyCode, _ in
                    highlight.handleStandardMenuKey(
                        keyCode: keyCode,
                        onActivate: {
                            if let pos = highlight.activeTriggerPosition,
                               highlight.selectablePositions.contains(pos) {
                                activated.append(pos)
                            }
                        },
                        onDismiss: {
                            dismissed = true
                        }
                    )
                },
                dismiss: { _ in
                    dismissed = true
                }
            )
        )
        defer { session.close() }

        // R1 enters menu accessibility on item 0.
        #expect(app.handleGlobalControllerInput(
            .button(.rightShoulder, isRepeat: false),
            isMainWindowKey: true,
            isSettingsWindowKey: false
        ))
        #expect(highlight.accessibilityPosition == 0)
        #expect(highlight.selectedPosition == 0)

        // R1 moves to disabled item 1 (focus ring only, no Select).
        #expect(app.handleGlobalControllerInput(
            .button(.rightShoulder, isRepeat: false),
            isMainWindowKey: true,
            isSettingsWindowKey: false
        ))
        #expect(highlight.accessibilityPosition == 1)
        #expect(highlight.selectedPosition == nil)

        // South (X) on disabled item 1 does nothing and keeps menu open.
        #expect(app.handleGlobalControllerInput(
            .button(.south, isRepeat: false),
            isMainWindowKey: true,
            isSettingsWindowKey: false
        ))
        #expect(activated.isEmpty)
        #expect(!dismissed)

        // 1st East (Circle) clears accessibility without closing the menu;
        // 2nd East (Circle) dismisses the menu.
        #expect(app.handleGlobalControllerInput(
            .button(.east, isRepeat: false),
            isMainWindowKey: true,
            isSettingsWindowKey: false
        ))
        #expect(!highlight.isAccessibilityActive)
        #expect(!dismissed)

        #expect(app.handleGlobalControllerInput(
            .button(.east, isRepeat: false),
            isMainWindowKey: true,
            isSettingsWindowKey: false
        ))
        #expect(dismissed)
    }

    @Test
    func filePageObservesAccessibilityFocusAndActivatesAddFolderAndCardMenus() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let rootURL = URL(fileURLWithPath: "/Media/Anime")
        app.indexing.selectedFolders = [rootURL]
        app.activateWorkbenchPanelMode(.file)

        let rootView = WorkbenchFileView(tasks: app.tasks)
            .environmentObject(app.settings.localization)
            .environmentObject(app)
            .environmentObject(app.indexing)
            .environmentObject(app.workbenchLayout.route)
            .environmentObject(app.library)
            .environment(\.workbenchAccessibility, app.workbenchAccessibility)
            .environment(\.interfaceLayers, app.interfaceLayers)
        let host = NSHostingView(rootView: rootView)
        host.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        host.layoutSubtreeIfNeeded()

        let targets = app.currentWorkbenchAccessibilityTargets()
        let rootPath = rootURL.mediaPath
        #expect(targets.suffix(5) == [
            .fileAddFolderButton,
            .fileIndexNowButton,
            .fileStatusIndicatorText,
            .fileCard(rootPath),
            .fileCardActionButton(rootPath),
        ])

        app.workbenchAccessibility.setFocus(.fileAddFolderButton)
        host.layoutSubtreeIfNeeded()
        #expect(app.workbenchAccessibility.isFocused(.fileAddFolderButton))
        #expect(app.workbenchAccessibility.onToggleFileAddFolderMenu != nil)

        app.workbenchAccessibility.setFocus(.fileCardActionButton(rootPath))
        host.layoutSubtreeIfNeeded()
        #expect(app.workbenchAccessibility.isFocused(.fileCardActionButton(rootPath)))
        #expect(app.workbenchAccessibility.activateFileCardAction(id: rootPath))
        // Opening a card menu on the File page clears underlying accessibility focus.
        #expect(app.workbenchAccessibility.focusedTarget == nil)
    }

    @Test
    func recentVideosAndLibraryEpisodeGridIncludeWholeCardAndDotsThreeActionButton() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let recentItem1 = RecentLibraryWatchingPresentation(
            videoFileID: 1,
            subtitleFileID: 101,
            videoPath: "/Media/Show/Episode 1.mkv",
            videoName: "Episode 1.mkv",
            duration: 100,
            subtitlePath: "/Media/Show/Episode 1.srt",
            subtitleFormat: .srt,
            displayTitle: "Episode 1",
            fileExtension: "mkv",
            folderPath: "/Media/Show",
            folderTitle: "Show",
            episodeNumber: 1,
            positionMilliseconds: 1_000,
            playbackDuration: 100,
            startedAt: "2026-07-22T00:00:00Z",
            completedAt: nil,
            updatedAt: "2026-07-22T00:00:00Z",
            coverPath: nil,
            coverRevision: nil
        )
        let recentItem2 = RecentLibraryWatchingPresentation(
            videoFileID: 2,
            subtitleFileID: 102,
            videoPath: "/Media/Show/Episode 2.mkv",
            videoName: "Episode 2.mkv",
            duration: 100,
            subtitlePath: "/Media/Show/Episode 2.srt",
            subtitleFormat: .srt,
            displayTitle: "Episode 2",
            fileExtension: "mkv",
            folderPath: "/Media/Show",
            folderTitle: "Show",
            episodeNumber: 2,
            positionMilliseconds: 0,
            playbackDuration: 100,
            startedAt: nil,
            completedAt: nil,
            updatedAt: "",
            coverPath: nil,
            coverRevision: nil
        )

        app.activateWorkbenchPanelMode(.recentWatching)
        app.workbenchLayout.selectRecentSection(.videos)
        app.library.testRecentWatchingStatus = .idle
        app.library.testRecentWatchingItems = [recentItem1, recentItem2]

        let recentVideoTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(recentVideoTargets.suffix(4) == [
            .mediaCard(recentItem1.id),
            .mediaCardActionButton(recentItem1.id),
            .mediaCard(recentItem2.id),
            .mediaCardActionButton(recentItem2.id),
        ])

        let episodeVideo = CompleteLibraryVideoPresentation(
            videoFileID: 1,
            subtitleFileID: 101,
            videoPath: "/Media/Show/Episode 1.mkv",
            videoName: "Episode 1.mkv",
            fileSize: 1_024,
            videoCodec: "h264",
            videoWidth: 1_920,
            videoHeight: 1_080,
            frameRate: 24,
            duration: 100,
            subtitlePath: "/Media/Show/Episode 1.srt",
            subtitleFormat: .srt,
            displayTitle: "Episode 1",
            fileExtension: "mkv",
            episodeNumber: 1,
            positionMilliseconds: 1_000,
            playbackDuration: 100,
            startedAt: "2026-07-22T00:00:00Z",
            completedAt: nil,
            historyUpdatedAt: "2026-07-22T00:00:00Z",
            coverPath: nil,
            coverRevision: nil
        )
        let folderSummary = CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/Show",
            folderTitle: "Show",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-07-22T00:00:00Z"
        )
        let folderDetail = CompleteLibraryFolderDetailPresentation(
            folderPath: "/Media/Show",
            folderTitle: "Show",
            videos: [episodeVideo]
        )

        app.library.completeLibraryFolderSummaries = [folderSummary]
        app.library.completeLibraryFolderDetailStatusesByPath["/Media/Show"] = .idle
        app.library.completeLibraryFolderDetailsByPath["/Media/Show"] = folderDetail
        app.navigateWorkbench(to: .libraryFolder(folderPath: "/Media/Show"))

        let episodeDetailTargets = app.currentWorkbenchAccessibilityTargets()
        #expect(episodeDetailTargets.suffix(5) == [
            .coverSummaryPrimaryButton,
            .coverSummaryEditCoverButton,
            .coverSummaryMoreButton,
            .mediaCard(episodeVideo.id),
            .mediaCardActionButton(episodeVideo.id),
        ])
    }

    @Test
    func schemaWorkbenchSearchToolbarSyncsSelectionModeAndRestoresNormalToolbarTargetsOnExit() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.activateWorkbenchPanelMode(.search)

        final class ToolbarStateBox: ObservableObject {
            @Published var isSelectionMode = false
            @Published var query = ""
            var openedFilterCount = 0
            var toggledSortCount = 0
            var exitedSelectionCount = 0
            var triggeredSelectionActionIDs: [String] = []
        }

        struct TestToolbarHost: View {
            @ObservedObject var box: ToolbarStateBox

            var body: some View {
                SchemaWorkbenchSearchToolbar(
                    placeholder: "Search",
                    searchDraft: $box.query,
                    searchResultCountText: "10 results",
                    selectedCountText: "1 selected",
                    selectionActions: [
                        SchemaWorkbenchSelectionAction(
                            id: "anki",
                            title: "Export to Anki",
                            icon: .copy,
                            keyLabel: "E",
                            keyCode: 14,
                            perform: { box.triggeredSelectionActionIDs.append("anki") }
                        ),
                        SchemaWorkbenchSelectionAction(
                            id: "copy-deep-links",
                            title: "Copy Deep Links",
                            icon: .copy,
                            keyLabel: "D",
                            keyCode: 2,
                            perform: { box.triggeredSelectionActionIDs.append("copy-deep-links") }
                        ),
                        SchemaWorkbenchSelectionAction(
                            id: "copy-table",
                            title: "Copy Table",
                            icon: .copy,
                            keyLabel: "C",
                            keyCode: 8,
                            perform: { box.triggeredSelectionActionIDs.append("copy-table") }
                        ),
                    ],
                    isSelectionMode: box.isSelectionMode,
                    onFilter: {
                        box.openedFilterCount += 1
                    },
                    onSort: {
                        guard !box.isSelectionMode else { return }
                        box.toggledSortCount += 1
                    },
                    onToggleSelectionMode: {
                        box.exitedSelectionCount += 1
                        box.isSelectionMode = false
                    }
                )
            }
        }

        let box = ToolbarStateBox()
        let host = NSHostingView(
            rootView: TestToolbarHost(box: box)
                .environment(\.workbenchAccessibility, app.workbenchAccessibility)
        )
        host.frame = NSRect(x: 0, y: 0, width: 900, height: 80)
        host.layoutSubtreeIfNeeded()

        #expect(!app.workbenchAccessibility.isTableInSelectionMode)
        #expect(app.currentWorkbenchAccessibilityTargets().suffix(3) == [
            .toolbarSearchField,
            .toolbarFilterButton,
            .toolbarSortButton,
        ])

        // Enter Selection Mode -> toolbar targets immediately switch to Selection Mode buttons
        // and each button's action callback is wired.
        box.isSelectionMode = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded()

        #expect(app.workbenchAccessibility.isTableInSelectionMode)
        #expect(app.currentWorkbenchAccessibilityTargets().suffix(4) == [
            .toolbarExitSelectButton,
            .toolbarSelectionAction(.exportToAnki),
            .toolbarSelectionAction(.copyDeepLinks),
            .toolbarSelectionAction(.copyTable),
        ])

        app.workbenchAccessibility.setFocus(.toolbarSelectionAction(.copyTable))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded()
        #expect(SchemaWorkbenchSelectionActionButton.lastRenderedFocusedByID["copy-table"] == true)
        #expect(SchemaWorkbenchSelectionActionButton.lastRenderedFocusedByID["anki"] == false)

        app.workbenchAccessibility.setFocus(.toolbarSelectionAction(.exportToAnki))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded()
        #expect(SchemaWorkbenchSelectionActionButton.lastRenderedFocusedByID["copy-table"] == false)
        #expect(SchemaWorkbenchSelectionActionButton.lastRenderedFocusedByID["anki"] == true)
        #expect(WorkbenchButton.lastFocusedButtonTitleForTesting == "Export to Anki")

        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarSelectionAction(.exportToAnki)))
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarSelectionAction(.copyDeepLinks)))
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarSelectionAction(.copyTable)))
        #expect(box.triggeredSelectionActionIDs == ["anki", "copy-deep-links", "copy-table"])

        // Activate Exit Selection button -> exits Selection Mode and restores normal toolbar targets.
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarExitSelectButton))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        host.layoutSubtreeIfNeeded()

        #expect(box.exitedSelectionCount == 1)
        #expect(!box.isSelectionMode)
        #expect(!app.workbenchAccessibility.isTableInSelectionMode)
        #expect(app.currentWorkbenchAccessibilityTargets().suffix(3) == [
            .toolbarSearchField,
            .toolbarFilterButton,
            .toolbarSortButton,
        ])

        // Normal Filter & Sort buttons remain responsive after exiting Selection Mode.
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarFilterButton))
        #expect(box.openedFilterCount == 1)
        #expect(app.activateWorkbenchAccessibilityTarget(.toolbarSortButton))
        #expect(box.toggledSortCount == 1)
    }
}
