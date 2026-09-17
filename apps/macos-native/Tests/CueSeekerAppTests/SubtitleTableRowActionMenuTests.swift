import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableSearchRowActionMenuUsesUnifiedOrderAndDivider() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: true)

    #expect(model.elements == [
        .action(.play),
        .action(.openSubtitleFolder),
        .action(.saveToExcerpt),
        .divider,
        .action(.copyCueText),
        .action(.copyDeepLink),
        .action(.copyCueGroupText),
        .action(.copyTimeRange),
    ])
    #expect(model.actions.map(\.title) == [
        "Play",
        "Open Subtitle Folder",
        "Save to Excerpt List",
        "Copy Cue Text",
        "Copy Deep Link",
        "Copy Cue Group Text",
        "Copy Time Range",
    ])
}

@Test
func subtitleTableRowActionMenuSelectablePositionsSkipDividersAndDisabledItems() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: false)

    // Elements are play, openSubtitleFolder, saveToExcerpt, divider,
    // copyCueText, copyDeepLink, copyTimeRange.
    #expect(
        model.selectablePositions(
            disabledActions: [],
            canOpenFolder: true
        ) == [0, 1, 2, 4, 5, 6]
    )

    // The divider at position 3 is never an action.
    #expect(model.action(at: 3) == nil)
    #expect(model.action(at: 0) == .play)
    #expect(model.action(at: 99) == nil)

    // A disabled action and an unopenable folder drop out, so arrow keys skip
    // them instead of parking the highlight on a dead row.
    #expect(
        model.selectablePositions(
            disabledActions: [.play],
            canOpenFolder: false
        ) == [2, 4, 5, 6]
    )
}

@Test
func subtitleTableRowActionMenuSubmenuParentsStayEnabledWithoutOtherLists() {
    let model = SubtitleTableRowActionMenuModel(style: .excerpt, showsCueGroup: false)

    // The submenu always offers New List, so the only list is not a dead end.
    #expect(
        model.isEnabled(
            .moveToList,
            disabledActions: [],
            canOpenFolder: true
        )
    )
    #expect(
        model.isEnabled(
            .duplicateToList,
            disabledActions: [],
            canOpenFolder: true
        )
    )

    // An unavailable Excerpt still disables both.
    #expect(
        !model.isEnabled(
            .moveToList,
            disabledActions: [.moveToList, .duplicateToList],
            canOpenFolder: true
        )
    )
    let positions = model.selectablePositions(
        disabledActions: [.moveToList, .duplicateToList],
        canOpenFolder: true
    )
    #expect(!positions.contains(where: {
        model.action(at: $0)?.opensDestinationSubmenu == true
    }))
}

@Test
func subtitleTableRowActionMenuHidesCueGroupCopyWhenCueGroupIsHidden() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: false)

    #expect(model.actions == [
        .play,
        .openSubtitleFolder,
        .saveToExcerpt,
        .copyCueText,
        .copyDeepLink,
        .copyTimeRange,
    ])
}

@Test
func subtitleTableExcerptRowActionMenuAddsTransferSubmenusAndDividers() {
    let model = SubtitleTableRowActionMenuModel(style: .excerpt, showsCueGroup: true)

    #expect(model.elements == [
        .action(.play),
        .action(.openSubtitleFolder),
        .divider,
        .action(.copyCueText),
        .action(.copyDeepLink),
        .action(.copyCueGroupText),
        .action(.copyTimeRange),
        .divider,
        .action(.moveToList),
        .action(.duplicateToList),
        .divider,
        .action(.removeExcerpt),
    ])
}

@Test
func subtitleTableUnavailableExcerptActionsFollowResourceAvailability() {
    let videoMissing = SubtitleTableCueState.unavailable(.videoMissing)
    #expect(videoMissing.icon == .question)
    #expect(videoMissing.subtitleFileIsAvailable)
    #expect(videoMissing.disabledRowActions == [
        .play,
        .saveToExcerpt,
        .moveToList,
        .duplicateToList,
    ])
    #expect(
        videoMissing.unavailableMessage
            == "The video file is missing. The subtitle file is still available."
    )

    let cueMissing = SubtitleTableCueState.unavailable(.cueMissing)
    #expect(cueMissing.subtitleFileIsAvailable)
    #expect(!cueMissing.disabledRowActions.contains(.openSubtitleFolder))

    let subtitleMissing = SubtitleTableCueState.unavailable(.subtitleMissing)
    #expect(!subtitleMissing.subtitleFileIsAvailable)
    #expect(subtitleMissing.disabledRowActions.contains(.openSubtitleFolder))
    #expect(!subtitleMissing.disabledRowActions.contains(.copyCueText))
    #expect(!subtitleMissing.disabledRowActions.contains(.copyDeepLink))
    #expect(!subtitleMissing.disabledRowActions.contains(.copyCueGroupText))
    #expect(!subtitleMissing.disabledRowActions.contains(.copyTimeRange))
    #expect(!subtitleMissing.disabledRowActions.contains(.removeExcerpt))
}

@Test
func subtitleTableChangedExcerptRemainsAvailable() {
    let state = SubtitleTableCueState.contentChanged(
        previous: "Previous",
        current: "Current"
    )
    #expect(state.icon == .clockCounterClockwise)
    #expect(!state.isUnavailable)
    #expect(state.disabledRowActions.isEmpty)
}

@Test
func cueStateTipUsesRightSideThenFallsBackToLeft() {
    let visibleRect = CGRect(x: 0, y: 0, width: 1_000, height: 600)
    let size = CGSize(width: 300, height: 120)
    let rightAnchor = CGRect(x: 100, y: 240, width: 16, height: 16)
    let rightFrame = CueStateTipGeometry.frame(
        anchor: rightAnchor,
        size: size,
        visibleRect: visibleRect
    )
    #expect(rightFrame.minX == rightAnchor.maxX + CueStateTipGeometry.gap)
    #expect(rightFrame.midY == rightAnchor.midY)

    let leftAnchor = CGRect(x: 850, y: 240, width: 16, height: 16)
    let leftFrame = CueStateTipGeometry.frame(
        anchor: leftAnchor,
        size: size,
        visibleRect: visibleRect
    )
    #expect(leftFrame.maxX == leftAnchor.minX - CueStateTipGeometry.gap)
    #expect(leftFrame.midY == leftAnchor.midY)
}

@MainActor
@Test
func subtitleTableExcerptSubmenuOpensOnHoverWithoutDelay() {
    let state = MenuSubmenuState<SubtitleTableRowAction>()

    state.open(.moveToList)
    #expect(state.highlightedParent == .moveToList)
    #expect(state.openParent == .moveToList)
    #expect(state.closeSubmenu())
    #expect(state.openParent == nil)
    state.open(.moveToList)
    #expect(state.openParent == .moveToList)

    let hoverState = MenuSubmenuState<SubtitleTableRowAction>()
    let openParents = OpenParentRecorder()
    hoverState.onOpenParentChange = { openParents.record($0) }

    hoverState.noteItemHover(true, at: 8, trigger: .moveToList, highlight: nil)
    #expect(hoverState.highlightedParent == .moveToList)
    #expect(hoverState.openParent == .moveToList)

    hoverState.noteItemHover(false, at: 8, trigger: .moveToList, highlight: nil)
    #expect(hoverState.openParent == .moveToList)

    hoverState.noteItemHover(true, at: 9, trigger: .duplicateToList, highlight: nil)
    #expect(hoverState.highlightedParent == .duplicateToList)
    #expect(hoverState.openParent == .duplicateToList)
    // The trigger the pointer left closes before the one it reached opens.
    #expect(openParents.recorded == [.moveToList, nil, .duplicateToList])

    // Any other item closes it.
    hoverState.noteItemHover(true, at: 11, trigger: nil, highlight: nil)
    #expect(hoverState.highlightedParent == nil)
    #expect(hoverState.openParent == nil)

    hoverState.reset()
    #expect(hoverState.highlightedParent == nil)
    #expect(hoverState.openParent == nil)
}

@MainActor
private final class OpenParentRecorder {
    private(set) var recorded: [SubtitleTableRowAction?] = []

    func record(_ action: SubtitleTableRowAction?) {
        recorded.append(action)
    }
}

// The menu sits at x 100...340, its Move to... item at y 246...286 with
// Duplicate to... below it, and the submenu hangs off Move to...'s top edge,
// flush against the menu's right side. Positions follow the Excerpt row menu:
// Move to... 8, Duplicate to... 9, Remove Excerpt 11.
private enum SubmenuPointerFixture {
    static let parentMenu = CGRect(x: 100, y: 100, width: 240, height: 400)
    static let trigger = CGRect(x: 104, y: 246, width: 232, height: 40)
    static let submenu = CGRect(x: 340, y: 246, width: 160, height: 120)
}

@MainActor
@Test
func subtitleTableExcerptSubmenuStaysOpenWhileThePointerCrossesToIt() {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    state.open(.moveToList)

    // On the trigger, about to leave it.
    state.notePointer(
        CGPoint(x: 330, y: 266),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == .moveToList)
    #expect(!state.isPointerInSafeArea)

    // Cutting the corner over the item below, aimed at the submenu's lower
    // rows: inside the triangle, so nothing else may react to it.
    state.notePointer(
        CGPoint(x: 336, y: 300),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == .moveToList)
    #expect(state.isPointerInSafeArea)
    state.noteItemHover(true, at: 11, trigger: nil, highlight: nil)
    state.noteItemHover(true, at: 9, trigger: .duplicateToList, highlight: nil)
    #expect(state.openParent == .moveToList)
    #expect(state.highlightedParent == .moveToList)

    // Arrived.
    state.notePointer(
        CGPoint(x: 400, y: 320),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == .moveToList)
    #expect(!state.isPointerInSafeArea)
}

@MainActor
@Test
func subtitleTableExcerptSubmenuClosesOnceThePointerLeavesTheSafeArea() {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    state.open(.moveToList)
    state.notePointer(
        CGPoint(x: 330, y: 266),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )

    // Turning away below both menus, well outside the triangle.
    state.notePointer(
        CGPoint(x: 360, y: 560),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == nil)
    #expect(!state.isPointerInSafeArea)

    // Out to the right of the submenu closes it just the same.
    let rightward = MenuSubmenuState<SubtitleTableRowAction>()
    rightward.open(.moveToList)
    rightward.notePointer(
        CGPoint(x: 400, y: 300),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    rightward.notePointer(
        CGPoint(x: 700, y: 300),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(rightward.openParent == nil)
}

@MainActor
@Test
func subtitleTableExcerptSubmenuStaysOpenOverTheParentMenuOutsideTheSafeArea() {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    state.open(.moveToList)
    state.notePointer(
        CGPoint(x: 330, y: 266),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )

    // Back over the menu's own rows: the rows own that case, so the pointer
    // report leaves the submenu alone and stops shielding them.
    state.notePointer(
        CGPoint(x: 150, y: 400),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == .moveToList)
    #expect(!state.isPointerInSafeArea)
    state.noteItemHover(true, at: 11, trigger: nil, highlight: nil)
    #expect(state.openParent == nil)
}

@MainActor
@Test
func subtitleTableKeyboardOpenedSubmenuWaitsForThePointerToMove() {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    let highlight = MenuHighlightModel()
    highlight.open(selectablePositions: [0, 8, 9, 11])

    // The pointer rests on Play while the keys walk down to Move to... and
    // open its submenu.
    state.noteItemHover(true, at: 0, trigger: nil, highlight: highlight)
    highlight.moveHighlight(by: 1)
    state.open(.moveToList)

    // The submenu appearing makes Play report its hover again. The pointer
    // has not moved, so the submenu stays and so does the highlight.
    state.noteItemHover(false, at: 0, trigger: nil, highlight: highlight)
    state.noteItemHover(true, at: 0, trigger: nil, highlight: highlight)
    #expect(state.openParent == .moveToList)
    #expect(highlight.highlightedPosition == 8)

    // The first real move puts the pointer's rules back: it rests on Play.
    highlight.notePointerMoved()
    state.notePointer(
        CGPoint(x: 150, y: 120),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.openParent == nil)
    #expect(highlight.highlightedPosition == 0)
}

@MainActor
@Test
func subtitleTableSubmenuSafeAreaEndsWhenThePointerTurnsAway() {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    let highlight = MenuHighlightModel()
    highlight.open(selectablePositions: [8, 9, 11])
    state.open(.moveToList)
    highlight.notePointerMoved()
    state.notePointer(
        CGPoint(x: 330, y: 266),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    state.notePointer(
        CGPoint(x: 336, y: 300),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    state.noteItemHover(true, at: 9, trigger: .duplicateToList, highlight: highlight)

    // Straight down keeps the direction the pointer was going.
    state.notePointer(
        CGPoint(x: 336, y: 305),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(state.isPointerInSafeArea)
    #expect(state.openParent == .moveToList)
    #expect(highlight.highlightedPosition == 8)

    // Back toward the trigger, still inside the triangle: the crossing is
    // over, and Duplicate to..., which the pointer is on, takes effect.
    state.notePointer(
        CGPoint(x: 333, y: 290),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    #expect(!state.isPointerInSafeArea)
    #expect(state.openParent == .duplicateToList)
    #expect(highlight.highlightedPosition == 9)
    highlight.close()

    // Turning away over no item closes the submenu.
    let bare = MenuSubmenuState<SubtitleTableRowAction>()
    bare.open(.moveToList)
    for point in [CGPoint(x: 330, y: 266), CGPoint(x: 336, y: 300), CGPoint(x: 333, y: 290)] {
        bare.notePointer(
            point,
            parentMenuFrame: f.parentMenu,
            triggerFrame: f.trigger,
            submenuFrame: f.submenu
        )
    }
    #expect(bare.openParent == nil)
}

@MainActor
@Test
func subtitleTableSubmenuSafeAreaEndsWhenThePointerStops() async throws {
    let f = SubmenuPointerFixture.self
    let state = MenuSubmenuState<SubtitleTableRowAction>()
    state.open(.moveToList)
    state.notePointer(
        CGPoint(x: 330, y: 266),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    state.notePointer(
        CGPoint(x: 336, y: 300),
        parentMenuFrame: f.parentMenu,
        triggerFrame: f.trigger,
        submenuFrame: f.submenu
    )
    state.noteItemHover(true, at: 9, trigger: .duplicateToList, highlight: nil)
    #expect(state.isPointerInSafeArea)
    #expect(state.openParent == .moveToList)

    // The pointer stops over Duplicate to... and never moves again. The wait
    // is generous because other tests can hold the main actor for seconds.
    let deadline = ContinuousClock.now + .seconds(20)
    while state.isPointerInSafeArea, ContinuousClock.now < deadline {
        try await Task.sleep(nanoseconds: 25_000_000)
    }
    #expect(!state.isPointerInSafeArea)
    #expect(state.openParent == .duplicateToList)
}

@Test
func subtitleTableExcerptSubmenuSafeAreaSpansTheTriangleAndTheGap() {
    let f = SubmenuPointerFixture.self
    let anchor = CGPoint(x: 330, y: 266)

    #expect(MenuSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 300),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))
    #expect(!MenuSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 420),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))
    // No anchor means the pointer never came off the trigger, so nothing is
    // being crossed and nothing is safe.
    #expect(!MenuSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 300),
        anchor: nil,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))

    // A submenu pushed to the left side turns the triangle around with it.
    let leftSubmenu = CGRect(x: -60, y: 246, width: 160, height: 120)
    #expect(MenuSubmenuSafeArea.contains(
        CGPoint(x: 104, y: 300),
        anchor: CGPoint(x: 110, y: 266),
        parentMenuFrame: f.parentMenu,
        submenuFrame: leftSubmenu
    ))

    // Parted menus: the strip between them is safe on its own.
    let partedSubmenu = CGRect(x: 380, y: 246, width: 160, height: 120)
    #expect(MenuSubmenuSafeArea.contains(
        CGPoint(x: 360, y: 360),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: partedSubmenu
    ))
}

@Test
func subtitleTableExcerptSubmenuAlignsWithItsParentItemTop() {
    let parentMenuFrame = CGRect(x: 100, y: 100, width: 240, height: 400)
    let parentItemFrame = CGRect(x: 4, y: 246, width: 232, height: 40)
    let submenuFrame = MenuSubmenuGeometry.frame(
        parentMenuFrame: parentMenuFrame,
        parentItemFrame: parentItemFrame,
        submenuSize: CGSize(width: 160, height: 100),
        visibleRect: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )

    #expect(MenuSubmenuGeometry.horizontalGap == 0)
    #expect(submenuFrame.minX == parentMenuFrame.maxX)
    #expect(
        submenuFrame.minY
            == parentMenuFrame.minY + parentItemFrame.minY
    )
}

@Test
func subtitleTableExcerptSubmenuGivesUpHeightTheBoundaryCannotHold() {
    // A boundary shorter than the submenu. It does not flip and it does not
    // hang over the edge: it takes the boundary's height and scrolls the rest.
    let visibleRect = CGRect(x: 0, y: 0, width: 1_000, height: 300)
    let parentMenuFrame = CGRect(x: 100, y: 0, width: 240, height: 300)
    let parentItemFrame = CGRect(x: 4, y: 200, width: 232, height: 40)
    let submenuFrame = MenuSubmenuGeometry.frame(
        parentMenuFrame: parentMenuFrame,
        parentItemFrame: parentItemFrame,
        submenuSize: CGSize(width: 160, height: 480),
        visibleRect: visibleRect
    )

    #expect(submenuFrame.height == visibleRect.height)
    #expect(submenuFrame.minY == visibleRect.minY)
    #expect(submenuFrame.maxY == visibleRect.maxY)
}

@Test
func subtitleTableRowActionMetadataUsesAcceptedLabelsAndSymbols() {
    #expect(SubtitleTableRowAction.openSubtitleFolder.title == "Open Subtitle Folder")
    #expect(SubtitleTableRowAction.copyDeepLink.title == "Copy Deep Link")
    #expect(SubtitleTableRowAction.copyTimeRange.title == "Copy Time Range")
    #expect(SubtitleTableRowAction.moveToList.title == "Move to ...")
    #expect(SubtitleTableRowAction.duplicateToList.title == "Duplicate to ...")
    #expect(SubtitleTableRowAction.moveToList.icon == .arrowRight)
    #expect(SubtitleTableRowAction.duplicateToList.icon == .arrowRight)
    #expect(SubtitleTableRowAction.copyCueText.icon == .copy)
    #expect(SubtitleTableRowAction.copyDeepLink.icon == .linkSimple)
    #expect(SubtitleTableRowAction.copyCueGroupText.icon == .copy)
    #expect(SubtitleTableRowAction.copyTimeRange.icon == .copy)
    #expect(SubtitleTableRowAction.removeExcerpt.icon == .heart)
    #expect(SubtitleTableRowAction.removeExcerpt.isDestructive)
    #expect(!SubtitleTableRowAction.play.isDestructive)
    #expect(!SubtitleTableRowAction.duplicateToList.isDestructive)
}
