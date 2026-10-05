import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func toastCenterEvictsTheOldestInsteadOfQueueing() {
    let center = ToastCenter()
    let start = Date()
    for index in 1...5 {
        center.show(
            ToastRequest(scenarioID: "scenario.\(index)", message: "Toast \(index)"),
            now: start
        )
    }

    #expect(center.visibleItems.map(\.request.message) == [
        "Toast 2", "Toast 3", "Toast 4", "Toast 5"
    ])

    center.removeExpired(at: start.addingTimeInterval(5.1))
    #expect(center.visibleItems.isEmpty)
}

@MainActor
@Test
func toastCenterKeepsOneToastPerResultAndRestartsItsStay() {
    let center = ToastCenter()
    let start = Date()
    let repeated = ExcerptToastRequest.saveSucceeded(listName: "Study")

    center.show(repeated, now: start)
    let firstID = center.visibleItems[0].id
    center.show(ToastRequest(scenarioID: "scenario.other", message: "Other"), now: start)
    center.show(repeated, now: start.addingTimeInterval(1.0))

    #expect(center.visibleItems.count == 2)
    #expect(center.visibleItems.last?.id == firstID)

    center.removeExpired(at: start.addingTimeInterval(1.6))
    #expect(center.visibleItems.map(\.request.message) == [repeated.message])

    center.removeExpired(at: start.addingTimeInterval(2.6))
    #expect(center.visibleItems.isEmpty)
}

@MainActor
@Test
func toastDurationsRunOnTheWallClock() {
    let center = ToastCenter()
    let start = Date()
    center.show(ToastRequest(message: "Away"), now: start)

    center.removeExpired(at: start.addingTimeInterval(1.4))
    #expect(center.visibleItems.count == 1)

    center.removeExpired(at: start.addingTimeInterval(1.5))
    #expect(center.visibleItems.isEmpty)
}

/// Both surfaces draw their icon through the line width table, and a size the
/// Icon Registry does not document trips an assertion at the moment of drawing
/// rather than at build time. Nothing else in this suite draws.
@MainActor
@Test
func feedbackIconsDrawAtTheirDocumentedSizes() {
    for size in [
        WorkbenchControlMetrics.redesignToastIconSize,
        PlaybackChromeMetrics.feedbackIconSize,
    ] {
        #expect(AppIconLineWidth.bySize[size] != nil, "\(size)pt is not in the registry")
        #expect(AppIconStore.image(.bookmarkSimple, size: size, weight: .fill) != nil)
    }
}

@Test
func excerptToastRequestsMatchTheUsageRegistry() {
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").message == "Moved to “Study”")
    #expect(ExcerptToastRequest.duplicateSucceeded(listName: "Study").message == "Duplicated to “Study”")
    #expect(
        ExcerptToastRequest.destinationUnavailable(listName: "Study").message
            == "“Study” is no longer available"
    )
    #expect(ExcerptToastRequest.moveFailed.message == "Couldn’t move the excerpt")
    #expect(ExcerptToastRequest.duplicateFailed.message == "Couldn’t duplicate the excerpt")
    #expect(ExcerptToastRequest.saveSucceeded(listName: "Study").message == "Saved to “Study”")
    #expect(
        ExcerptToastRequest.saveFailed(listName: "Study").message
            == "Couldn’t save to “Study”"
    )
    #expect(
        ExcerptToastRequest.destinationAlreadyContainsCue(listName: "Study").message
            == "This excerpt already exists in “Study”"
    )
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").duration == 1.5)
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").position == .appCenter)
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").animation == .default)
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").icon == .bookmarkSimple)
    #expect(ExcerptToastRequest.moveSucceeded(listName: "Study").iconWeight == .fill)

    #expect(ExcerptToastRequest.destinationUnavailable(listName: "Study").icon == .warning)
    #expect(ExcerptToastRequest.destinationUnavailable(listName: "Study").duration == 3.0)
    #expect(ExcerptToastRequest.moveFailed.icon == .warning)
    #expect(ExcerptToastRequest.moveFailed.duration == 3.0)
    #expect(ExcerptToastRequest.duplicateFailed.icon == .warning)
    #expect(ExcerptToastRequest.duplicateFailed.duration == 3.0)
    #expect(ExcerptToastRequest.saveFailed(listName: "Study").icon == .warning)
    #expect(ExcerptToastRequest.saveFailed(listName: "Study").duration == 3.0)
    #expect(ExcerptToastRequest.destinationAlreadyContainsCue(listName: "Study").icon == .warning)
    #expect(ExcerptToastRequest.destinationAlreadyContainsCue(listName: "Study").duration == 3.0)
}

@Test
func tableToastRequestsMatchTheUsageRegistry() {
    #expect(TableToastRequest.copyCueText.message == "Cue Text Copied")
    #expect(TableToastRequest.copyCueText.icon == .copy)
    #expect(TableToastRequest.copyCueText.duration == 1.5)

    #expect(TableToastRequest.copyDeepLink.message == "Deep Link Copied")
    #expect(TableToastRequest.copyDeepLink.icon == .copy)
    #expect(TableToastRequest.copyDeepLink.duration == 1.5)

    #expect(TableToastRequest.copyCueGroupText.message == "Cue Group Text Copied")
    #expect(TableToastRequest.copyCueGroupText.icon == .copy)
    #expect(TableToastRequest.copyCueGroupText.duration == 1.5)

    #expect(TableToastRequest.copyTimeRange.message == "Time Range Copied")
    #expect(TableToastRequest.copyTimeRange.icon == .copy)
    #expect(TableToastRequest.copyTimeRange.duration == 1.5)

    #expect(TableToastRequest.copyDeepLinks.message == "Deep Links Copied")
    #expect(TableToastRequest.copyDeepLinks.icon == .copy)
    #expect(TableToastRequest.copyDeepLinks.duration == 1.5)

    #expect(TableToastRequest.copyTable.message == "Table Copied")
    #expect(TableToastRequest.copyTable.icon == .copy)
    #expect(TableToastRequest.copyTable.duration == 1.5)

    #expect(TableToastRequest.cueNotInLibrary.message == "Cue Not in Library")
    #expect(TableToastRequest.cueNotInLibrary.icon == .warning)
    #expect(TableToastRequest.cueNotInLibrary.duration == 3.0)

    #expect(TableToastRequest.cuesNotInLibrary.message == "Cues Not in Library")
    #expect(TableToastRequest.cuesNotInLibrary.icon == .warning)
    #expect(TableToastRequest.cuesNotInLibrary.duration == 3.0)

    #expect(TableToastRequest.cueNotInLibrary(count: 1) == TableToastRequest.cueNotInLibrary)
    #expect(TableToastRequest.cueNotInLibrary(count: 2) == TableToastRequest.cuesNotInLibrary)
}

@MainActor
@Test
func toastCopyIconColorsAreWhiteInsteadOfAccent() {
    #expect(ToastView.iconColor(for: TableToastRequest.copyCueText) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.copyDeepLink) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.copyCueGroupText) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.copyTimeRange) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.copyDeepLinks) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.copyTable) == .white)
    #expect(ToastView.iconColor(for: TableToastRequest.cueNotInLibrary) == WorkbenchRedesignColors.warningText)
    #expect(ToastView.iconColor(for: ExcerptToastRequest.moveFailed) == WorkbenchRedesignColors.dangerText)
    #expect(ToastView.iconColor(for: ExcerptToastRequest.saveSucceeded(listName: "Study")) == WorkbenchRedesignColors.successText)
}
