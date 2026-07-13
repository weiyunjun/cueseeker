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
func subtitleTableShioriRowActionMenuAddsSeparatedRemoveAction() {
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
        .action(.removeShiori),
    ])
}

@Test
func subtitleTableRowActionMetadataUsesAcceptedLabelsAndSymbols() {
    #expect(SubtitleTableRowAction.openSubtitleFolder.title == "Open Subtitle Folder")
    #expect(SubtitleTableRowAction.copyTimeRange.title == "Copy Time Range")
    #expect(SubtitleTableRowAction.copyCueText.systemImage == "copy")
    #expect(SubtitleTableRowAction.copyTimeRange.systemImage == "copy")
    #expect(SubtitleTableRowAction.removeShiori.systemImage == "bookmark.slash")
}
