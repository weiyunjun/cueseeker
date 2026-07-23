import CoreGraphics
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableSearchRowActionMenuUsesUnifiedOrderAndDivider() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: true)

    #expect(model.elements == [
        .action(.play),
        .action(.openSubtitleFolder),
        .action(.context),
        .divider,
        .action(.copyCueText),
        .action(.copyCueGroupText),
        .action(.copyTimeRange),
    ])
    #expect(model.actions.map(\.title) == [
        "Play",
        "Open Subtitle Folder",
        "Context",
        "Copy Cue Text",
        "Copy Cue Group Text",
        "Copy Time Range",
    ])
}

@Test
func subtitleTableRowActionMenuHidesCueGroupCopyWhenCueGroupIsHidden() {
    let model = SubtitleTableRowActionMenuModel(style: .search, showsCueGroup: false)

    #expect(model.actions == [
        .play,
        .openSubtitleFolder,
        .context,
        .copyCueText,
        .copyTimeRange,
    ])
}

@Test
func subtitleTableShioriRowActionMenuAddsTransferSubmenusAndDividers() {
    let model = SubtitleTableRowActionMenuModel(style: .shiori, showsCueGroup: true)

    #expect(model.elements == [
        .action(.play),
        .action(.openSubtitleFolder),
        .action(.context),
        .divider,
        .action(.copyCueText),
        .action(.copyCueGroupText),
        .action(.copyTimeRange),
        .divider,
        .action(.moveToList),
        .action(.duplicateToList),
        .divider,
        .action(.removeShiori),
    ])
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
    #expect(state.openHighlightedParent())
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
func subtitleTableShioriSubmenuUsesTopDownItemFrameInAppKitCoordinates() {
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
        submenuFrame.maxY
            == parentMenuFrame.maxY - parentItemFrame.minY
    )
}

@Test
func subtitleTableRowActionMetadataUsesAcceptedLabelsAndSymbols() {
    #expect(SubtitleTableRowAction.openSubtitleFolder.title == "Open Subtitle Folder")
    #expect(SubtitleTableRowAction.copyTimeRange.title == "Copy Time Range")
    #expect(SubtitleTableRowAction.moveToList.title == "Move to ...")
    #expect(SubtitleTableRowAction.duplicateToList.title == "Duplicate to ...")
    #expect(SubtitleTableRowAction.moveToList.systemImage == "arrow.right")
    #expect(SubtitleTableRowAction.duplicateToList.systemImage == "copy")
    #expect(SubtitleTableRowAction.copyCueText.systemImage == "copy")
    #expect(SubtitleTableRowAction.copyTimeRange.systemImage == "copy")
    #expect(SubtitleTableRowAction.removeShiori.systemImage == "bookmark.slash")
}
