import Foundation
import Combine
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func workbenchLayoutStateDefaultsToSearchWithExpandedSidebar() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(layoutState.panelMode == .search)
        #expect(layoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateMigratesLegacyLibraryPanelToSearch() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        userDefaults.set("library", forKey: "workbenchPanelMode")

        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        #expect(layoutState.panelMode == .search)
    }
}

@MainActor
@Test
func workbenchLayoutStatePersistsSelectedPanelMode() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.navigate(to: .library)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.panelMode == .testLibrary)
    }
}

@MainActor
@Test
func workbenchLayoutStateDoesNotInvalidateAnAlreadySelectedLibraryPanel() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        layoutState.navigate(to: .library)
        var routeInvalidations = 0
        let cancellable = layoutState.route.objectWillChange.sink {
            routeInvalidations += 1
        }

        layoutState.navigate(to: .library)

        #expect(routeInvalidations == 0)
        #expect(layoutState.panelMode == .testLibrary)
        withExtendedLifetime(cancellable) {}
    }
}

@MainActor
@Test
func workbenchLayoutStatePersistsSidebarVisibility() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.toggleSidebarVisibility()

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(!reloadedLayoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func sidebarVisibilityDoesNotInvalidateRouteState() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        var routeInvalidations = 0
        var layoutInvalidations = 0

        let routeCancellable = layoutState.route.objectWillChange.sink {
            routeInvalidations += 1
        }
        let layoutCancellable = layoutState.objectWillChange.sink {
            layoutInvalidations += 1
        }

        layoutState.toggleSidebarVisibility()

        #expect(routeInvalidations == 0)
        #expect(layoutInvalidations == 1)
        #expect(layoutState.panelMode == .search)

        withExtendedLifetime(routeCancellable) {}
        withExtendedLifetime(layoutCancellable) {}
    }
}

@MainActor
@Test
func workbenchLayoutStateCollapsesSidebarForCompactWindowOnce() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        // At the exact threshold (e.g. 840px), the sidebar stays docked.
        let collapsedAtThreshold = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 840,
            threshold: 840
        )
        #expect(!collapsedAtThreshold)
        #expect(layoutState.isSidebarVisible)

        // Below the threshold (< 840px), the sidebar auto-collapses.
        let collapsedBelowThreshold = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 839,
            threshold: 840
        )
        let expandedAgain = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 900,
            threshold: 840
        )

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(collapsedBelowThreshold)
        #expect(!expandedAgain)
        #expect(!layoutState.isSidebarVisible)
        #expect(!reloadedLayoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateIgnoresNonPositiveCompactWindowWidth() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        let collapsed = layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: 0,
            threshold: 760
        )

        #expect(!collapsed)
        #expect(layoutState.isSidebarVisible)
    }
}

@MainActor
@Test
func workbenchLayoutStateTracksExcerptListDetailWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)

        layoutState.navigate(to: .excerptList(id: 42))
        #expect(layoutState.selectedExcerptListID == 42)
        #expect(layoutState.route.selectedExcerptListID == 42)

        layoutState.navigate(to: .excerpt)
        #expect(layoutState.selectedExcerptListID == nil)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedExcerptListID == nil)
    }
}

@MainActor
@Test
func workbenchLayoutStateTracksRecentSectionWithoutPersistingIt() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(layoutState.selectedRecentSection == .videos)

        layoutState.selectRecentSection(.excerpts)
        #expect(layoutState.selectedRecentSection == .excerpts)
        #expect(layoutState.route.selectedRecentSection == .excerpts)

        layoutState.navigate(to: .file)
        #expect(layoutState.selectedRecentSection == .excerpts)

        let reloadedLayoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(reloadedLayoutState.selectedRecentSection == .videos)
    }
}

@MainActor
@Test
func workbenchHistoryStepsThroughPagesAndDropsForwardOnNewNavigation() {
    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        #expect(layoutState.currentRoute == .search)
        #expect(!layoutState.route.canGoBack)
        #expect(!layoutState.route.canGoForward)

        layoutState.navigate(to: .recent)
        layoutState.navigate(to: .library)
        layoutState.navigate(to: .libraryFolder(folderPath: "/Media/Show"))
        #expect(layoutState.panelMode == .testLibrary)
        #expect(layoutState.selectedLibraryFolderPath == "/Media/Show")
        #expect(layoutState.route.canGoBack)
        #expect(!layoutState.route.canGoForward)

        layoutState.goBack()
        #expect(layoutState.currentRoute == .library)
        #expect(layoutState.selectedLibraryFolderPath == nil)
        #expect(layoutState.route.canGoForward)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .recent)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .search)
        #expect(!layoutState.route.canGoBack)
        layoutState.goBack()
        #expect(layoutState.currentRoute == .search)

        layoutState.goForward()
        layoutState.goForward()
        layoutState.goForward()
        #expect(layoutState.currentRoute == .libraryFolder(folderPath: "/Media/Show"))
        #expect(!layoutState.route.canGoForward)
        layoutState.goForward()
        #expect(layoutState.currentRoute == .libraryFolder(folderPath: "/Media/Show"))

        layoutState.goBack()
        layoutState.navigate(to: .excerpt)
        #expect(layoutState.currentRoute == .excerpt)
        #expect(!layoutState.route.canGoForward)
        #expect(layoutState.route.history == [.search, .recent, .library, .excerpt])

        layoutState.navigate(to: .excerpt)
        #expect(layoutState.route.history.count == 4)

        layoutState.navigate(to: .excerptList(id: 42))
        #expect(layoutState.selectedExcerptListID == 42)
        layoutState.goBack()
        #expect(layoutState.selectedExcerptListID == nil)
        #expect(layoutState.panelMode == .excerpt)
    }
}

@MainActor
private func withTemporaryWorkbenchLayoutUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerWorkbenchLayoutStateTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}

@Test
func workbenchSidebarCollapsesBeforeThePageDropsBelowItsMinimumWidth() {
    #expect(WorkbenchControlMetrics.redesignWindowDefaultWidth == 1_000)
    #expect(WorkbenchControlMetrics.redesignWindowMinimumWidth == 600)
    #expect(WorkbenchControlMetrics.redesignWindowMinimumHeight == 560)
    #expect(WorkbenchControlMetrics.redesignSidebarMotionDuration == 0.18)
    #expect(WorkbenchControlMetrics.redesignBorderHairlineWidth == 1)

    #expect(AppShellLayout.defaultWindowWidth == WorkbenchControlMetrics.redesignWindowDefaultWidth)
    #expect(AppShellLayout.minimumWindowWidth == WorkbenchControlMetrics.redesignWindowMinimumWidth)
    #expect(AppShellLayout.pageContentMinimumWidth == 600)
    #expect(AppShellLayout.minimumWindowHeight == WorkbenchControlMetrics.redesignWindowMinimumHeight)
    #expect(AppShellLayout.sidePanelAnimationDuration == WorkbenchControlMetrics.redesignSidebarMotionDuration)
    #expect(AppShellLayout.sidebarBorderWidth == WorkbenchControlMetrics.redesignBorderHairlineWidth)
    #expect(AppShellLayout.modeControlsOuterPadding == WorkbenchControlMetrics.redesignSpacing3)
    #expect(AppShellLayout.sidebarWidth == 240)
    #expect(
        AppShellLayout.sidebarAutoCollapseWindowWidth
            == AppShellLayout.pageContentMinimumWidth + AppShellLayout.sidebarWidth
    )
    #expect(AppShellLayout.sidebarAutoCollapseWindowWidth == 840)
    #expect(AppShellLayout.isCompactWindow(width: 839))
    #expect(!AppShellLayout.isCompactWindow(width: 840))

    // At the threshold an expanded sidebar leaves exactly the page content
    // minimum, so widening past it never needs page-level horizontal scrolling.
    #expect(
        AppShellLayout.sidebarAutoCollapseWindowWidth - AppShellLayout.sidebarWidth
            == AppShellLayout.pageContentMinimumWidth
    )
}

@MainActor
@Test
func overlaySidebarMouseLeaveCollapsesOnlyInCompactWindowWhenPointerLeaves240Width() {
    let sidebarBounds = CGRect(x: 0, y: 0, width: 240, height: 600)

    // 1. During entrance cooldown, even a pointer past x > 240 does not abort the fade-in.
    #expect(
        !OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 320, y: 27),
            sidebarBounds: sidebarBounds,
            isWithinEntranceCooldown: true
        )
    )

    // 2. Pointer inside x <= 240 (including upward nudges above the top-left toggle button) stays open.
    #expect(
        !OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 96, y: 27),
            sidebarBounds: sidebarBounds
        )
    )
    #expect(
        !OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 96, y: -6),
            sidebarBounds: sidebarBounds
        )
    )
    #expect(
        !OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 96, y: 605),
            sidebarBounds: sidebarBounds
        )
    )
    #expect(
        !OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 240, y: 300),
            sidebarBounds: sidebarBounds
        )
    )

    // 3. Pointer moving horizontally past x > 240 after entrance cooldown collapses the overlay sidebar.
    #expect(
        OverlaySidebarPointerMonitorNSView.shouldCollapseForPointerLocation(
            CGPoint(x: 241, y: 300),
            sidebarBounds: sidebarBounds
        )
    )

    withTemporaryWorkbenchLayoutUserDefaults { userDefaults in
        let layoutState = WorkbenchLayoutState(userDefaults: userDefaults)
        layoutState.setSidebarVisible(true)

        // Docked mode (>= 840px) never collapses on mouse leave.
        #expect(!layoutState.collapseOverlaySidebarOnMouseLeaveIfNeeded(width: 840))
        #expect(layoutState.isSidebarVisible)

        // Overlay mode (< 840px) immediately collapses on mouse leave.
        #expect(layoutState.collapseOverlaySidebarOnMouseLeaveIfNeeded(width: 720))
        #expect(!layoutState.isSidebarVisible)
    }
}

@Test
func adaptiveHeaderGeometryCentersShiftsAndTruncatesWith12PxMinimumGap() {
    let leadingNaturalSize = CGSize(width: 140, height: 28)
    let centerNaturalSize = CGSize(width: 190, height: 36)
    let trailingNaturalSize = CGSize(width: 60, height: 28)
    let leadingInset: CGFloat = 128
    let trailingInset: CGFloat = 16
    let gap: CGFloat = 12

    // 1. Wide container (800px): center sits at exact horizontal center (400px), no truncation.
    let wide = WorkbenchAdaptiveHeaderGeometry.resolve(
        containerSize: CGSize(width: 800, height: 54),
        leadingNaturalSize: leadingNaturalSize,
        centerNaturalSize: centerNaturalSize,
        trailingNaturalSize: trailingNaturalSize,
        leadingInset: leadingInset,
        trailingInset: trailingInset,
        minimumGap: gap
    )
    #expect(wide.centerFrame.midX == 400)
    #expect(wide.leadingFrame.width == 140)
    #expect(wide.centerFrame.minX - wide.leadingFrame.maxX >= gap)
    #expect(wide.trailingFrame.minX - wide.centerFrame.maxX >= gap)

    // 2. Single-side contact (600px): ideal center minX is 205, which would be < 128 + 140 + 12 = 280.
    // Center shifts right to 280 (maintaining 12px gap from leading) without truncating leading title.
    let shiftedRight = WorkbenchAdaptiveHeaderGeometry.resolve(
        containerSize: CGSize(width: 600, height: 54),
        leadingNaturalSize: leadingNaturalSize,
        centerNaturalSize: centerNaturalSize,
        trailingNaturalSize: trailingNaturalSize,
        leadingInset: leadingInset,
        trailingInset: trailingInset,
        minimumGap: gap
    )
    #expect(shiftedRight.centerFrame.minX == 280)
    #expect(shiftedRight.leadingFrame.width == 140)
    #expect(shiftedRight.centerFrame.minX - shiftedRight.leadingFrame.maxX == 12)
    #expect(shiftedRight.trailingFrame.minX - shiftedRight.centerFrame.maxX > 12)

    // 3. Right-side contact first: wide trailing controls push center left without truncating leading.
    let shiftedLeft = WorkbenchAdaptiveHeaderGeometry.resolve(
        containerSize: CGSize(width: 600, height: 54),
        leadingNaturalSize: CGSize(width: 60, height: 28),
        centerNaturalSize: centerNaturalSize,
        trailingNaturalSize: CGSize(width: 200, height: 28),
        leadingInset: 20,
        trailingInset: 20,
        minimumGap: gap
    )
    #expect(shiftedLeft.centerFrame.maxX == shiftedLeft.trailingFrame.minX - 12)
    #expect(shiftedLeft.leadingFrame.width == 60)
    #expect(shiftedLeft.centerFrame.minX - shiftedLeft.leadingFrame.maxX > 12)

    // 4. Both sides at 12px limit (520px): center locks at trailing.minX - 12 - 190 = 242,
    // and leading title width compresses to 242 - 12 - 128 = 102 (< 140).
    let compressed = WorkbenchAdaptiveHeaderGeometry.resolve(
        containerSize: CGSize(width: 520, height: 54),
        leadingNaturalSize: leadingNaturalSize,
        centerNaturalSize: centerNaturalSize,
        trailingNaturalSize: trailingNaturalSize,
        leadingInset: leadingInset,
        trailingInset: trailingInset,
        minimumGap: gap
    )
    #expect(compressed.trailingFrame.minX == 444)
    #expect(compressed.centerFrame.maxX == 432)
    #expect(compressed.centerFrame.minX == 242)
    #expect(compressed.leadingFrame.width == 102)
    #expect(compressed.centerFrame.minX - compressed.leadingFrame.maxX == 12)
}

@Test
func workbenchRecentSectionLabelsAndShortLabelsMatchSpecification() {
    #expect(WorkbenchRecentSection.videos.label == "Recent Videos")
    #expect(WorkbenchRecentSection.excerpts.label == "Recent Excerpt Lists")
    #expect(WorkbenchRecentSection.videos.shortLabel == "Videos")
    #expect(WorkbenchRecentSection.excerpts.shortLabel == "Excerpt Lists")
}
