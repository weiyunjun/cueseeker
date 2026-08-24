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
            canOpenFolder: true,
            hasDestinations: false
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
            canOpenFolder: false,
            hasDestinations: false
        ) == [3, 4, 5]
    )
}

@Test
func subtitleTableRowActionMenuSubmenuParentsNeedDestinations() {
    let model = SubtitleTableRowActionMenuModel(style: .shiori, showsCueGroup: false)

    #expect(
        !model.isEnabled(
            .moveToList,
            disabledActions: [],
            canOpenFolder: true,
            hasDestinations: false
        )
    )
    #expect(
        model.isEnabled(
            .moveToList,
            disabledActions: [],
            canOpenFolder: true,
            hasDestinations: true
        )
    )

    let withoutDestinations = model.selectablePositions(
        disabledActions: [],
        canOpenFolder: true,
        hasDestinations: false
    )
    let withDestinations = model.selectablePositions(
        disabledActions: [],
        canOpenFolder: true,
        hasDestinations: true
    )
    #expect(withDestinations.count == withoutDestinations.count + 2)
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
func subtitleTableShioriSubmenuSupportsImmediateAndDelayedEntryRules() {
    let state = SubtitleTableRowActionSubmenuState()
    #expect(
        SubtitleTableRowActionSubmenuState.nativeHoverDelayNanoseconds
            == 300_000_000
    )

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

    let immediateHoverState = SubtitleTableRowActionSubmenuState(
        hoverDelayNanoseconds: 0
    )
    immediateHoverState.setParentHovered(
        .duplicateToList,
        isHovered: true
    )
    #expect(immediateHoverState.highlightedParent == .duplicateToList)
    #expect(immediateHoverState.openParent == .duplicateToList)
    immediateHoverState.setParentHovered(
        .duplicateToList,
        isHovered: false
    )
    #expect(immediateHoverState.openParent == .duplicateToList)

    let cancelledHoverState = SubtitleTableRowActionSubmenuState()
    cancelledHoverState.setParentHovered(.moveToList, isHovered: true)
    cancelledHoverState.setParentHovered(.moveToList, isHovered: false)
    #expect(cancelledHoverState.highlightedParent == nil)
    #expect(cancelledHoverState.openParent == nil)

    immediateHoverState.reset()
    #expect(immediateHoverState.highlightedParent == nil)
    #expect(immediateHoverState.openParent == nil)
}

@MainActor
@Test
func subtitleTableShioriSubmenuStaysOpenAcrossDirectPointerTransfer() async {
    let state = SubtitleTableRowActionSubmenuState()
    state.setParentMenuHovered(true)
    state.open(.moveToList)

    state.setParentMenuHovered(false)
    state.setSubmenuHovered(true)
    try? await Task.sleep(
        nanoseconds:
            SubtitleTableRowActionSubmenuState.pointerTransferGraceNanoseconds
            + 50_000_000
    )

    #expect(state.openParent == .moveToList)

    state.setSubmenuHovered(false)
    try? await Task.sleep(
        nanoseconds:
            SubtitleTableRowActionSubmenuState.pointerTransferGraceNanoseconds
            + 50_000_000
    )

    #expect(state.openParent == nil)
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
    #expect(SubtitleTableRowAction.duplicateToList.systemImage == "copy")
    #expect(SubtitleTableRowAction.copyCueText.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.copyDeepLink.systemImage == "link")
    #expect(SubtitleTableRowAction.copyCueGroupText.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.copyTimeRange.systemImage == "doc.on.doc")
    #expect(SubtitleTableRowAction.removeShiori.systemImage == "bookmark.slash")
}
