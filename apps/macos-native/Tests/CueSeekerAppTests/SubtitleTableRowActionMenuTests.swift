import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableSearchRowActionMenuUsesUnifiedOrderAndDivider() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: true)

    #expect(model.elements == [
        .action(.play),
        .action(.openSubtitleFolder),
        .divider,
        .action(.copyCueText),
        .action(.copyDeepLink),
        .action(.copyCueGroupText),
        .action(.copyTimeRange),
    ])
    #expect(model.actions.map(\.title) == [
        "Play",
        "Open Subtitle Folder",
        "Copy Cue Text",
        "Copy Deep Link",
        "Copy Cue Group Text",
        "Copy Time Range",
    ])
}

@Test
func subtitleTableRowActionMenuSelectablePositionsSkipDividersAndDisabledItems() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: false)

    // Elements are play, openSubtitleFolder, divider, copyCueText,
    // copyDeepLink, copyTimeRange.
    #expect(
        model.selectablePositions(
            disabledActions: [],
            canOpenFolder: true
        ) == [0, 1, 3, 4, 5]
    )

    // The divider at position 2 is never an action.
    #expect(model.action(at: 2) == nil)
    #expect(model.action(at: 0) == .play)
    #expect(model.action(at: 99) == nil)

    // A disabled action and an unopenable folder drop out, so arrow keys skip
    // them instead of parking the highlight on a dead row.
    #expect(
        model.selectablePositions(
            disabledActions: [.play],
            canOpenFolder: false
        ) == [3, 4, 5]
    )
}

@Test
func subtitleTableRowActionMenuSubmenuParentsStayEnabledWithoutOtherLists() {
    let model = SubtitleTableRowActionMenuModel(style: .shiori, showsCueGroup: false)

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

    // An unavailable Shiori still disables both.
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
        .copyCueText,
        .copyDeepLink,
        .copyTimeRange,
    ])
}

@Test
func subtitleTableShioriRowActionMenuAddsTransferSubmenusAndDividers() {
    let model = SubtitleTableRowActionMenuModel(style: .shiori, showsCueGroup: true)

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
        .action(.removeShiori),
    ])
}

@Test
func subtitleTableUnavailableShioriActionsFollowResourceAvailability() {
    let videoMissing = SubtitleTableCueState.unavailable(.videoMissing)
    #expect(videoMissing.systemImage == "questionmark.circle")
    #expect(videoMissing.subtitleFileIsAvailable)
    #expect(videoMissing.disabledRowActions == [
        .play,
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
    #expect(!subtitleMissing.disabledRowActions.contains(.removeShiori))
}

@Test
func subtitleTableChangedShioriRemainsAvailable() {
    let state = SubtitleTableCueState.contentChanged(
        previous: "Previous",
        current: "Current"
    )
    #expect(state.systemImage == "clock.arrow.circlepath")
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
func subtitleTableShioriSubmenuOpensOnHoverWithoutDelay() {
    let state = SubtitleTableRowActionSubmenuState()

    state.open(.moveToList)
    #expect(state.highlightedParent == .moveToList)
    #expect(state.openParent == .moveToList)
    #expect(state.closeSubmenu())
    #expect(state.openParent == nil)
    state.open(.moveToList)
    #expect(state.openParent == .moveToList)

    state.setOtherItemHovered(true)
    #expect(state.highlightedParent == nil)
    #expect(state.openParent == nil)

    let hoverState = SubtitleTableRowActionSubmenuState()
    let openParents = OpenParentRecorder()
    hoverState.onOpenParentChange = { openParents.record($0) }

    hoverState.setParentHovered(.moveToList, isHovered: true)
    #expect(hoverState.highlightedParent == .moveToList)
    #expect(hoverState.openParent == .moveToList)

    hoverState.setParentHovered(.moveToList, isHovered: false)
    #expect(hoverState.openParent == .moveToList)

    hoverState.setParentHovered(.duplicateToList, isHovered: true)
    #expect(hoverState.highlightedParent == .duplicateToList)
    #expect(hoverState.openParent == .duplicateToList)
    // The trigger the pointer left closes before the one it reached opens.
    #expect(openParents.recorded == [.moveToList, nil, .duplicateToList])

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

// The menu sits at x 100...340, its Move to... item at y 246...286, and the
// submenu hangs off that item's top edge, flush against the menu's right side.
private enum SubmenuPointerFixture {
    static let parentMenu = CGRect(x: 100, y: 100, width: 240, height: 400)
    static let trigger = CGRect(x: 104, y: 246, width: 232, height: 40)
    static let submenu = CGRect(x: 340, y: 246, width: 160, height: 120)
}

@MainActor
@Test
func subtitleTableShioriSubmenuStaysOpenWhileThePointerCrossesToIt() {
    let f = SubmenuPointerFixture.self
    let state = SubtitleTableRowActionSubmenuState()
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
    state.setOtherItemHovered(true)
    state.setParentHovered(.duplicateToList, isHovered: true)
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
func subtitleTableShioriSubmenuClosesOnceThePointerLeavesTheSafeArea() {
    let f = SubmenuPointerFixture.self
    let state = SubtitleTableRowActionSubmenuState()
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
    let rightward = SubtitleTableRowActionSubmenuState()
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
func subtitleTableShioriSubmenuStaysOpenOverTheParentMenuOutsideTheSafeArea() {
    let f = SubmenuPointerFixture.self
    let state = SubtitleTableRowActionSubmenuState()
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
    state.setOtherItemHovered(true)
    #expect(state.openParent == nil)
}

@Test
func subtitleTableShioriSubmenuSafeAreaSpansTheTriangleAndTheGap() {
    let f = SubmenuPointerFixture.self
    let anchor = CGPoint(x: 330, y: 266)

    #expect(SubtitleTableRowActionSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 300),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))
    #expect(!SubtitleTableRowActionSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 420),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))
    // No anchor means the pointer never came off the trigger, so nothing is
    // being crossed and nothing is safe.
    #expect(!SubtitleTableRowActionSubmenuSafeArea.contains(
        CGPoint(x: 336, y: 300),
        anchor: nil,
        parentMenuFrame: f.parentMenu,
        submenuFrame: f.submenu
    ))

    // A submenu pushed to the left side turns the triangle around with it.
    let leftSubmenu = CGRect(x: -60, y: 246, width: 160, height: 120)
    #expect(SubtitleTableRowActionSubmenuSafeArea.contains(
        CGPoint(x: 104, y: 300),
        anchor: CGPoint(x: 110, y: 266),
        parentMenuFrame: f.parentMenu,
        submenuFrame: leftSubmenu
    ))

    // Parted menus: the strip between them is safe on its own.
    let partedSubmenu = CGRect(x: 380, y: 246, width: 160, height: 120)
    #expect(SubtitleTableRowActionSubmenuSafeArea.contains(
        CGPoint(x: 360, y: 360),
        anchor: anchor,
        parentMenuFrame: f.parentMenu,
        submenuFrame: partedSubmenu
    ))
}

@Test
func subtitleTableShioriSubmenuAlignsWithItsParentItemTop() {
    let parentMenuFrame = CGRect(x: 100, y: 100, width: 240, height: 400)
    let parentItemFrame = CGRect(x: 4, y: 246, width: 232, height: 40)
    let submenuFrame = SubtitleTableRowActionSubmenuGeometry.frame(
        parentMenuFrame: parentMenuFrame,
        parentItemFrame: parentItemFrame,
        submenuSize: CGSize(width: 160, height: 100),
        visibleRect: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )

    #expect(SubtitleTableRowActionSubmenuGeometry.horizontalGap == 0)
    #expect(submenuFrame.minX == parentMenuFrame.maxX)
    #expect(
        submenuFrame.minY
            == parentMenuFrame.minY + parentItemFrame.minY
    )
}

@Test
func subtitleTableRowActionMetadataUsesAcceptedLabelsAndSymbols() {
    #expect(SubtitleTableRowAction.openSubtitleFolder.title == "Open Subtitle Folder")
    #expect(SubtitleTableRowAction.copyDeepLink.title == "Copy Deep Link")
    #expect(SubtitleTableRowAction.copyTimeRange.title == "Copy Time Range")
    #expect(SubtitleTableRowAction.moveToList.title == "Move to ...")
    #expect(SubtitleTableRowAction.duplicateToList.title == "Duplicate to ...")
    #expect(SubtitleTableRowAction.moveToList.systemImage == "arrow.right")
    #expect(SubtitleTableRowAction.duplicateToList.systemImage == "arrow.right")
    #expect(SubtitleTableRowAction.copyCueText.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.copyDeepLink.systemImage == "link")
    #expect(SubtitleTableRowAction.copyCueGroupText.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.copyTimeRange.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.removeShiori.systemImage == "bookmark.slash")
    #expect(SubtitleTableRowAction.removeShiori.isDestructive)
    #expect(!SubtitleTableRowAction.play.isDestructive)
    #expect(!SubtitleTableRowAction.duplicateToList.isDestructive)
}
