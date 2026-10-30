import AppKit
import CueSeekerCore
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
    func workbenchCoverCardGridSyncsSelectAndSupportsDirectionalNavigationOnlyInsideGrid() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

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

        // When focus is on a toolbar button outside the card grid, directional keys do nothing.
        app.workbenchAccessibility.setFocus(.toolbarSortButton)
        #expect(!app.handleWorkbenchControllerInput(.direction(.right, source: .directionalPad, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == .toolbarSortButton)

        // When focus is on the 1st card's action button, that card still owns Select and
        // pressing Right moves to the 2nd card's whole card.
        app.workbenchAccessibility.setFocus(.mediaCardActionButton(firstID))
        #expect(app.workbenchAccessibility.focusedTarget?.mediaCardID == firstID)
        #expect(app.handleWorkbenchControllerInput(.direction(.right, source: .directionalPad, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedTarget == .mediaCard(secondID))
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
}
