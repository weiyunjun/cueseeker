import AppKit
import CoreGraphics
import SwiftUI
import Testing
@testable import CueSeekerApp

/// Narrowest Cover Summary the Workbench can present: the page content minimum
/// width less the page's own leading padding and trailing Scrollbar channel.
private let coverSummaryMinimumCardWidth =
    AppShellLayout.pageContentMinimumWidth
        - WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
        - WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding

@Test
func coverSummaryUsesSharedPlaybackActionTitles() {
    #expect(CoverSummaryActionKind.play.title == "Play")
    #expect(CoverSummaryActionKind.resume.title == "Resume")
}

@Test
func coverSummarySwitchesFormsAtItsDerivedWidth() {
    #expect(
        WorkbenchControlMetrics.redesignCoverSummarySplitMinimumWidth
            == WorkbenchControlMetrics.redesignCoverSummarySplitCoverWidth
                + WorkbenchControlMetrics.redesignCoverSummarySplitGap
                + WorkbenchControlMetrics.redesignCoverSummarySplitContentMinWidth
    )
    #expect(WorkbenchControlMetrics.redesignCoverSummarySplitMinimumWidth == 664)

    #expect(CoverSummaryCardLayout.resolve(containerWidth: 664).form == .split)
    #expect(CoverSummaryCardLayout.resolve(containerWidth: 663).form == .backdrop)
}

@Test
func coverSummarySplitFormLocksTheCoverAndLetsContentFillTheRest() {
    let atThreshold = CoverSummaryCardLayout.resolve(containerWidth: 664)
    let wide = CoverSummaryCardLayout.resolve(containerWidth: 1_400)

    #expect(atThreshold.coverFrame == CGRect(x: 0, y: 0, width: 320, height: 180))
    #expect(wide.coverFrame == atThreshold.coverFrame)
    #expect(atThreshold.cardHeight == 180)
    #expect(wide.cardHeight == 180)

    // Content starts past the cover and its gap, then takes every remaining
    // point: the split form is never capped.
    #expect(atThreshold.contentFrame.minX == 344)
    #expect(atThreshold.contentFrame.width == 320)
    #expect(wide.contentFrame.minX == 344)
    #expect(wide.contentFrame.width == 1_056)
    #expect(atThreshold.contentFrame.height == 180)
}

@Test
func coverSummaryBackdropFormKeepsAFixedHeightAtEveryWidth() {
    let narrowest = CoverSummaryCardLayout.resolve(
        containerWidth: coverSummaryMinimumCardWidth
    )
    let belowThreshold = CoverSummaryCardLayout.resolve(containerWidth: 663)

    #expect(coverSummaryMinimumCardWidth == 520)
    #expect(narrowest.form == .backdrop)
    #expect(narrowest.cardHeight == 225)
    #expect(belowThreshold.form == .backdrop)
    #expect(belowThreshold.cardHeight == 225)
    #expect(narrowest.coverFrame == CGRect(x: 0, y: 0, width: 520, height: 225))
    #expect(belowThreshold.coverFrame == CGRect(x: 0, y: 0, width: 663, height: 225))
    #expect(WorkbenchControlMetrics.redesignCoverSummaryBackdropHeight == 225)
}

@Test
func coverSummaryKeepsTheContentColumnHeightAcrossAFormChange() {
    let split = CoverSummaryCardLayout.resolve(containerWidth: 664)
    let backdrop = CoverSummaryCardLayout.resolve(containerWidth: 663)

    #expect(split.contentFrame.height == backdrop.contentFrame.height)
    #expect(split.contentFrame.height == 180)

    // The backdrop block padding is what makes the two heights match, and it is
    // applied equally above and below the content column.
    #expect(backdrop.contentFrame.minY == 22.5)
    #expect(backdrop.cardHeight - backdrop.contentFrame.maxY == 22.5)
    #expect(
        WorkbenchControlMetrics.redesignCoverSummarySplitCoverHeight
            + WorkbenchControlMetrics.redesignCoverSummaryBackdropBlockPadding * 2
            == WorkbenchControlMetrics.redesignCoverSummaryBackdropHeight
    )
}

@Test
func coverSummaryHeightFunctionMatchesTheResolvedLayout() {
    let widths: [CGFloat] = [coverSummaryMinimumCardWidth, 500, 663, 664, 1_064, 1_400]
    for width in widths {
        #expect(
            CoverSummaryCardLayout.height(forCardWidth: width)
                == CoverSummaryCardLayout.resolve(containerWidth: width).cardHeight
        )
    }
}

@Test
func coverSummaryBackdropTextWidthStaysWithinItsInnerAvailableWidth() {
    let layout = CoverSummaryCardLayout.resolve(
        containerWidth: coverSummaryMinimumCardWidth
    )

    #expect(layout.contentFrame.minX == 40)
    #expect(layout.contentFrame.maxX <= layout.coverFrame.maxX)
    #expect(layout.contentFrame.maxY <= layout.coverFrame.maxY)
    #expect(layout.scrimEndLocation == 1)
}

@Test
func coverSummaryBackdropKeepsTheAcceptedLeftToRightScrim() {
    let layout = CoverSummaryCardLayout.resolve(containerWidth: 600)

    #expect(layout.form == .backdrop)
    // The scrim end follows the protected content edge past its default stop.
    #expect(layout.scrimEndLocation == 528.0 / 600.0)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimLeadingOpacity == 0.62)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimStrongOpacity == 0.54)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimMiddleOpacity == 0.34)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryScrimTrailingOpacity == 0.12)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryButtonBackgroundOpacity == 0.14)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryButtonHoverBackgroundOpacity == 0.24)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryButtonPressedBackgroundOpacity == 0.34)
}

@Test
func excerptDetailPageScrollPinsControlsAfterCoverLeavesViewport() {
    let geometry = SubtitleTablePageScrollGeometry(
        scrollableHeaderHeight: 294,
        pinnedHeaderHeight: 52,
        tableHeaderHeight: 40,
        bottomInset: 14
    )

    #expect(geometry.scrollableHeaderOriginY(scrollOffset: 120) == -120)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 120) == 174)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 294) == 0)
    #expect(geometry.pinnedHeaderOriginY(scrollOffset: 500) == 0)
    #expect(geometry.rowsOriginY == 386)
}

@Test
func excerptDetailPageScrollKeepsRowsBelowPinnedChrome() {
    let geometry = SubtitleTablePageScrollGeometry(
        scrollableHeaderHeight: 294,
        pinnedHeaderHeight: 52,
        tableHeaderHeight: 40,
        bottomInset: 14
    )
    let viewportSize = CGSize(width: 1_000, height: 700)

    let initial = geometry.tableBodyVisibleRect(
        scrollOffset: 0,
        viewportSize: viewportSize
    )
    let pinned = geometry.tableBodyVisibleRect(
        scrollOffset: 400,
        viewportSize: viewportSize
    )

    #expect(initial.minY == geometry.rowsOriginY)
    #expect(pinned.minY == 492)
    #expect(pinned.height == 608)
    #expect(geometry.documentHeight(rowsHeight: 2_000, viewportHeight: 700) == 2_400)
    #expect(geometry.scrollOffsetForRow(localRowY: 500, maximumOffset: 2_000) == 794)
}

@Test
func coverSummarySpacingAndProgressTokensMatchSpecification() {
    #expect(WorkbenchControlMetrics.redesignCoverSummaryTitleMetaGap == 12)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryMetaLinesGap == 10)
    #expect(WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription == 20)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingX == 12)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingY == 8)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryProgressLabelGap == 6)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryProgressWidth == 290)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryProgressTrackHeight == 5)
    #expect(WorkbenchControlMetrics.redesignCoverSummaryProgressActionsGap == 14)
    #expect(WorkbenchControlMetrics.redesignSpacing2 == 8)

    let clampedLow = CoverSummaryProgress(labelText: "EP01  00:00 / 24:00", fraction: -0.25)
    let clampedHigh = CoverSummaryProgress(labelText: "EP01  24:00 / 24:00", fraction: 1.5)
    #expect(clampedLow.fraction == 0)
    #expect(clampedHigh.fraction == 1)
}

@Test
func libraryFolderCoverSummarySupportingContentMakesOnlyLocalPathsClickable() {
    var didOpenLocal = false
    let localContent = libraryFolderCoverSummarySupportingContent(
        itemCount: 13,
        folderPath: "/Volumes/Seagate/Ave Mujica",
        onOpenPath: { didOpenLocal = true }
    )
    if case .metadata(let primary, let secondary, let interaction) = localContent {
        #expect(primary == "13 videos  13 subtitles")
        #expect(secondary == "/Volumes/Seagate/Ave Mujica")
        if case .clickablePath(let id, let action) = interaction {
            #expect(id == "/Volumes/Seagate/Ave Mujica")
            action()
            #expect(didOpenLocal)
        } else {
            Issue.record("Expected local folder path to be clickable")
        }
    } else {
        Issue.record("Expected metadata supporting content")
    }

    let remoteContent = libraryFolderCoverSummarySupportingContent(
        itemCount: 5,
        folderPath: "https://webdav.example.com/Anime/MyGO"
    )
    #expect(
        remoteContent
            == .metadata(
                primary: "5 videos  5 subtitles",
                secondary: "https://webdav.example.com/Anime/MyGO",
                secondaryInteraction: .none
            )
    )
}

@Test
func excerptCoverSummaryPlacesCountAndCreatedDateFirstAndDescriptionSecond() {
    let populated = excerptCoverSummarySupportingContent(
        description: "First line\nSecond line",
        cueCount: 18,
        createdAt: "2026-10-12T08:30:00Z"
    )
    #expect(
        populated
            == .metadata(
                primary: "18 excerpts  Created 2026-10-12",
                secondary: "First line Second line",
                secondaryInteraction: .expandableDescription(
                    fullText: "First line\nSecond line"
                )
            )
    )

    let empty = excerptCoverSummarySupportingContent(
        description: "   \n  ",
        cueCount: 1,
        createdAt: "2026-10-12T08:30:00Z"
    )
    #expect(
        empty
            == .metadata(
                primary: "1 excerpt  Created 2026-10-12",
                secondary: "No description",
                secondaryInteraction: .none
            )
    )
}

@Test
func coverSummaryDescriptionPopoverExpandsOutwardWithZeroFirstLineShiftAndCapsAtActionRowBottom() {
    let split = CoverSummaryCardLayout.resolve(containerWidth: 800)
    let paddingX = WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingX
    let paddingY = WorkbenchControlMetrics.redesignCoverSummaryDescriptionPopoverPaddingY
    let lineHeight = WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription
    let descriptionTopOffset: CGFloat = 68

    let shortPopover = CoverSummaryDescriptionPopoverLayout.resolve(
        contentFrame: split.contentFrame,
        descriptionTopOffset: descriptionTopOffset,
        descriptionText: "Short description"
    )

    // Outward expansion: container shifts left by 12px and up by 8px so the
    // first line of text inside the popover sits at the exact same (x, y) and
    // width as the unexpanded single-line description.
    #expect(shortPopover.frame.minX == split.contentFrame.minX - paddingX)
    #expect(shortPopover.frame.minY == split.contentFrame.minY + descriptionTopOffset - paddingY)
    #expect(shortPopover.frame.minX + paddingX == split.contentFrame.minX)
    #expect(shortPopover.frame.minY + paddingY == split.contentFrame.minY + descriptionTopOffset)
    #expect(shortPopover.textWidth == split.contentFrame.width)
    #expect(shortPopover.frame.width == split.contentFrame.width + paddingX * 2)
    #expect(!shortPopover.needsScroll)
    #expect(shortPopover.textHeight == lineHeight)
    #expect(shortPopover.frame.height == lineHeight + paddingY * 2)
    #expect(shortPopover.frame.maxY < split.contentFrame.maxY)

    let longText = Array(
        repeating: "Long excerpt list description line that wraps across multiple lines inside the popover container.",
        count: 10
    ).joined(separator: "\n")
    let tallPopover = CoverSummaryDescriptionPopoverLayout.resolve(
        contentFrame: split.contentFrame,
        descriptionTopOffset: descriptionTopOffset,
        descriptionText: longText
    )

    // Overlay scrollbar (C-07.1, Reserved Gutter: None) preserves full textWidth
    // even when scrolling is required, and bottom outer edge aligns flush with
    // contentFrame.maxY (Action Row bottom outer edge).
    #expect(tallPopover.needsScroll)
    #expect(tallPopover.textWidth == split.contentFrame.width)
    #expect(tallPopover.frame.width == split.contentFrame.width + paddingX * 2)
    #expect(tallPopover.frame.height == tallPopover.maxHeight)
    #expect(tallPopover.frame.maxY == split.contentFrame.maxY)

    let backdropBg = WorkbenchRedesignColors.NS.coverSummaryDescriptionPopoverBackdropBg
        .usingColorSpace(.sRGB)
    #expect(backdropBg != nil)
    if let backdropBg {
        #expect(abs(backdropBg.redComponent - 0x4C / 255.0) < 0.005)
        #expect(abs(backdropBg.greenComponent - 0x4C / 255.0) < 0.005)
        #expect(abs(backdropBg.blueComponent - 0x54 / 255.0) < 0.005)
        #expect(backdropBg.alphaComponent == 1.0)
    }

    // Short single-line description that fits within availableWidth is not expandable;
    // multi-line description or overflowing single-line description is expandable.
    #expect(
        !CoverSummaryDescriptionPopoverLayout.isDescriptionExpandable(
            singleLineText: "Short description",
            fullText: "Short description",
            availableWidth: 400
        )
    )
    #expect(
        CoverSummaryDescriptionPopoverLayout.isDescriptionExpandable(
            singleLineText: "First line Second line",
            fullText: "First line\nSecond line",
            availableWidth: 400
        )
    )
    let overflowingSingleLine = String(repeating: "这是一个列表你知道吗", count: 8)
    #expect(
        CoverSummaryDescriptionPopoverLayout.isDescriptionExpandable(
            singleLineText: overflowingSingleLine,
            fullText: overflowingSingleLine,
            availableWidth: 300
        )
    )
}

@Test
func excerptCoverSummaryHelpersFormatSingleLinePreviewAndCreatedDate() {
    #expect(excerptCoverSummaryCuePreviewText("  Single line cue  ") == "Single line cue")
    #expect(
        excerptCoverSummaryCuePreviewText("First line\nSecond line")
            == "First line..."
    )
    #expect(
        excerptCoverSummaryCuePreviewText("First line...\nSecond line")
            == "First line..."
    )
    #expect(
        excerptListCreatedDateDisplayText(
            for: "2026-10-12T08:30:00Z"
        ) == "2026-10-12"
    )
    #expect(LibraryToastRequest.folderNotInLibrary.icon == .warning)
}

@Test
@MainActor
func coverSummaryMoreMenuAnchorStaysAttachedAcrossFormTransitions() {
    let anchor = MenuAnchorHandle()
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false
    )
    let host = NSHostingView(
        rootView: CoverSummaryCard(
            title: "Ave Mujica",
            supportingContent: .metadata(
                primary: "13 videos  13 subtitles",
                secondary: "/Volumes/Seagate/Ave Mujica"
            ),
            progress: CoverSummaryProgress(
                labelText: "EP01  23:29 / 23:41",
                fraction: 0.99
            ),
            actionKind: .resume,
            isActionEnabled: true,
            action: {},
            secondaryAction: CoverSummarySecondaryAction(
                title: "View in File",
                icon: .folder,
                action: {}
            ),
            moreMenuAnchor: anchor,
            isMoreMenuOpen: false,
            onToggleMoreMenu: {}
        ) {
            Color.black
        }
    )
    window.contentView = host
    host.layoutSubtreeIfNeeded()

    let splitAnchorFrame = anchor.windowFrame
    #expect(splitAnchorFrame != nil)
    #expect(splitAnchorFrame?.size == CGSize(width: 36, height: 36))

    window.setContentSize(NSSize(width: 560, height: 300))
    host.layoutSubtreeIfNeeded()

    let backdropAnchorFrame = anchor.windowFrame
    #expect(backdropAnchorFrame != nil)
    #expect(backdropAnchorFrame?.size == CGSize(width: 36, height: 36))

    window.setContentSize(NSSize(width: 800, height: 300))
    host.layoutSubtreeIfNeeded()

    let restoredSplitAnchorFrame = anchor.windowFrame
    #expect(restoredSplitAnchorFrame != nil)
    #expect(restoredSplitAnchorFrame?.size == CGSize(width: 36, height: 36))
}
