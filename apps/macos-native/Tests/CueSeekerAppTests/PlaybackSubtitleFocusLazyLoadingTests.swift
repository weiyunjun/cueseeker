import CueSeekerCore
import Testing
@testable import CueSeekerApp

@Test
func subtitleFocusLoadSchedulerKeepsOneActiveAndLatestPending() throws {
    var scheduler = PlaybackSubtitleFocusLoadScheduler(
        source: lazySourceIdentity(),
        sessionGeneration: 1
    )
    let firstIntent = lazyTargetIntent(ordinal: 10, range: 4..<14)
    let secondIntent = lazyTargetIntent(ordinal: 20, range: 14..<24)
    let latestIntent = lazyTargetIntent(ordinal: 30, range: 24..<34)

    let issuedFirst = scheduler.enqueue(firstIntent)
    let first = try #require(issuedFirst)
    #expect(scheduler.enqueue(firstIntent) == nil)
    #expect(scheduler.enqueue(secondIntent) == nil)
    #expect(scheduler.pendingRequest?.intent == secondIntent)
    #expect(scheduler.enqueue(latestIntent) == nil)
    #expect(scheduler.activeRequest == first)
    #expect(scheduler.pendingRequest?.intent == latestIntent)

    let completedFirst = scheduler.complete(first)
    let firstCompletion = try #require(completedFirst)
    #expect(!firstCompletion.shouldPublish)
    let latest = try #require(firstCompletion.nextRequest)
    #expect(latest.intent == latestIntent)
    #expect(scheduler.activeRequest == latest)
    #expect(scheduler.pendingRequest == nil)

    let completedLatest = scheduler.complete(latest)
    let latestCompletion = try #require(completedLatest)
    #expect(latestCompletion.shouldPublish)
    #expect(latestCompletion.nextRequest == nil)
    #expect(!scheduler.hasWork)
}

@Test
func subtitleFocusLoadSchedulerDoesNotDeduplicateStaleActiveIntent() throws {
    var scheduler = PlaybackSubtitleFocusLoadScheduler(
        source: lazySourceIdentity(),
        sessionGeneration: 1
    )
    let firstIntent = lazyTargetIntent(ordinal: 10, range: 4..<14)
    let otherIntent = lazyTargetIntent(ordinal: 20, range: 14..<24)
    let issuedFirst = scheduler.enqueue(firstIntent)
    let first = try #require(issuedFirst)
    #expect(scheduler.enqueue(otherIntent) == nil)
    #expect(scheduler.enqueue(firstIntent) == nil)
    let replacement = try #require(scheduler.pendingRequest)

    #expect(replacement.intent == firstIntent)
    #expect(replacement.token != first.token)
    let completedFirst = scheduler.complete(first)
    let completion = try #require(completedFirst)
    #expect(!completion.shouldPublish)
    #expect(completion.nextRequest == replacement)
}

@MainActor
@Test
func subtitleFocusPrefetchStartsOnlyAfterUserReachesTwoCueThreshold() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 40, selectedOrdinal: 12, range: 6..<16)
    )

    #expect(session.windowLoadRequestAfterNavigation(.forward) == nil)
    #expect(session.moveSelection(.forward))
    let request = try #require(
        session.windowLoadRequestAfterNavigation(.forward)
    )

    #expect(request.intent.kind == .sequential(direction: .forward))
    #expect(request.intent.range == 16..<26)
    #expect(session.windowLoadRequestAfterNavigation(.forward) == nil)
    #expect(session.activeWindowLoadRequest == request)

    #expect(session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 40, range: 16..<26)
    ) == nil)
    #expect(session.currentSnapshot?.selectedOrdinal == 13)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(6..<26))
    #expect(session.retainedCueCount == 20)
}

@MainActor
@Test
func subtitleFocusNavigationAtCacheBoundaryCanStartPrefetch() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 40, selectedOrdinal: 15, range: 6..<16)
    )

    #expect(!session.moveSelection(.forward))
    let request = try #require(
        session.windowLoadRequestAfterNavigation(.forward)
    )
    #expect(request.intent.range == 16..<26)
}

@MainActor
@Test
func subtitleFocusSequentialPrefetchEvictsOppositeBatchAndKeepsSelection() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 27, range: 0..<30)
    )
    let request = try #require(
        session.windowLoadRequestAfterNavigation(.forward)
    )

    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 30..<40)
    )

    #expect(session.retainedCueCount == 30)
    #expect(session.currentSnapshot?.selectedOrdinal == 27)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(10..<40))
}

@MainActor
@Test
func subtitleFocusSequentialPrefetchRejectsEvictionAfterDirectionBecomesInvalid() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 27, range: 0..<30)
    )
    let request = try #require(
        session.windowLoadRequestAfterNavigation(.forward)
    )
    for _ in 0..<22 {
        #expect(session.moveSelection(.backward))
    }
    #expect(session.currentSnapshot?.selectedOrdinal == 5)

    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 30..<40)
    )

    #expect(session.currentSnapshot?.selectedOrdinal == 5)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(0..<30))
    #expect(session.retainedCueCount == 30)
}

@MainActor
@Test
func subtitleFocusSequentialPrefetchNeverEvictsReportedVisibleCues() throws {
    let initial = lazySnapshot(totalCount: 50, selectedOrdinal: 12, range: 10..<40)
    let session = lazySession(snapshot: initial)
    session.updateProtectedVisibleOrdinalRange(11..<40)
    let rejectedRequest = try #require(
        session.windowLoadRequestAfterNavigation(.backward)
    )

    _ = session.completeWindowLoad(
        rejectedRequest,
        batch: lazyBatch(totalCount: 50, range: 0..<10)
    )

    #expect(session.currentSnapshot == initial)
    #expect(session.retainedCueCount == 30)

    session.updateProtectedVisibleOrdinalRange(10..<30)
    let acceptedRequest = try #require(
        session.windowLoadRequestAfterNavigation(.backward)
    )
    _ = session.completeWindowLoad(
        acceptedRequest,
        batch: lazyBatch(totalCount: 50, range: 0..<10)
    )

    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(0..<30))
    #expect(session.retainedCueCount == 30)
}

@MainActor
@Test
func subtitleFocusFarTargetKeepsOldWindowUntilAtomicCommit() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    )
    session.noteScrollbarPreviewChanged(ordinal: 30)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )

    #expect(request.intent.range == 24..<34)
    #expect(session.isTargetWindowLoading)
    #expect(session.currentSnapshot?.selectedOrdinal == 6)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(0..<10))

    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 24..<34)
    )

    #expect(session.currentSnapshot?.selectedOrdinal == 30)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(24..<34))
    #expect(session.retainedCueCount == 10)
    #expect(!session.isTargetWindowLoading)
    #expect(session.targetWindowState.resolutionGeneration == 1)
    #expect(session.targetWindowCommit == PlaybackSubtitleFocusTargetWindowCommit(
        sequence: 1,
        direction: .forward
    ))
}

@MainActor
@Test
func subtitleFocusFarTargetFailureRollsBackWithoutChangingSnapshot() throws {
    let initial = lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    let session = lazySession(snapshot: initial)
    session.noteScrollbarPreviewChanged(ordinal: 30)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )

    _ = session.completeWindowLoad(request, batch: nil)

    #expect(session.currentSnapshot == initial)
    #expect(session.retainedCueCount == 10)
    #expect(!session.isTargetWindowLoading)
    #expect(session.targetWindowState.resolutionGeneration == 1)
    #expect(session.targetWindowCommit == nil)
}

@MainActor
@Test
func subtitleFocusBackwardFarTargetPublishesOneFinalAlignmentMotion() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 60, selectedOrdinal: 40, range: 34..<44)
    )
    session.noteScrollbarPreviewChanged(ordinal: 10)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 10)
    )

    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 60, range: 4..<14)
    )

    #expect(session.targetWindowCommit == PlaybackSubtitleFocusTargetWindowCommit(
        sequence: 1,
        direction: .backward
    ))
    #expect(session.currentSnapshot?.selectedOrdinal == 10)
}

@MainActor
@Test
func subtitleFocusMalformedTargetBatchIsRejectedAtomically() throws {
    let initial = lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    let wrongTotalSession = lazySession(snapshot: initial)
    wrongTotalSession.noteScrollbarPreviewChanged(ordinal: 30)
    let wrongTotalRequest = try #require(
        wrongTotalSession.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )
    _ = wrongTotalSession.completeWindowLoad(
        wrongTotalRequest,
        batch: lazyBatch(totalCount: 49, range: 24..<34)
    )

    #expect(wrongTotalSession.currentSnapshot == initial)
    #expect(wrongTotalSession.retainedCueCount == 10)

    let wrongRangeSession = lazySession(snapshot: initial)
    wrongRangeSession.noteScrollbarPreviewChanged(ordinal: 30)
    let wrongRangeRequest = try #require(
        wrongRangeSession.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )
    _ = wrongRangeSession.completeWindowLoad(
        wrongRangeRequest,
        batch: lazyBatch(totalCount: 50, range: 25..<35)
    )

    #expect(wrongRangeSession.currentSnapshot == initial)
    #expect(wrongRangeSession.retainedCueCount == 10)
}

@MainActor
@Test
func subtitleFocusUncachedPreviewSuppressesActionsBeforeDebounceRequest() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    )

    session.noteScrollbarPreviewChanged(ordinal: 30)

    #expect(session.isTargetWindowLoading)
    #expect(session.activeWindowLoadRequest == nil)
    #expect(session.pendingWindowLoadRequest == nil)
}

@MainActor
@Test
func subtitleFocusKeyboardIntentRejectsFarResultBeforeViewDrain() throws {
    let initial = lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    let session = lazySession(snapshot: initial)
    session.noteScrollbarPreviewChanged(ordinal: 30)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )

    #expect(session.requestKeyboardNavigation(.forward))
    #expect(!session.isTargetWindowLoading)
    #expect(session.windowLoadRequestForScrollbarTarget(ordinal: 30) == nil)
    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 24..<34)
    )

    #expect(session.currentSnapshot == initial)
    #expect(session.keyboardNavigationRequest?.targetOrdinal == 7)
}

@MainActor
@Test
func subtitleFocusCachedTargetSupersedesLateFarResultWithoutQuery() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    )
    session.noteScrollbarPreviewChanged(ordinal: 30)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )

    #expect(session.commitCachedScrollbarTarget(ordinal: 8))
    #expect(session.currentSnapshot?.selectedOrdinal == 8)
    #expect(!session.isTargetWindowLoading)

    _ = session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 24..<34)
    )
    #expect(session.currentSnapshot?.selectedOrdinal == 8)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(0..<10))
}

@MainActor
@Test
func subtitleFocusFarTargetsPublishOnlyLatestPendingResult() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 60, selectedOrdinal: 6, range: 0..<10)
    )
    session.noteScrollbarPreviewChanged(ordinal: 20)
    let first = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 20)
    )
    session.noteScrollbarPreviewChanged(ordinal: 30)
    #expect(session.windowLoadRequestForScrollbarTarget(ordinal: 30) == nil)
    session.noteScrollbarPreviewChanged(ordinal: 40)
    #expect(session.windowLoadRequestForScrollbarTarget(ordinal: 40) == nil)

    let latest = try #require(session.completeWindowLoad(
        first,
        batch: lazyBatch(totalCount: 60, range: 14..<24)
    ))
    #expect(latest.intent.kind == .target(ordinal: 40))
    #expect(session.currentSnapshot?.selectedOrdinal == 6)

    _ = session.completeWindowLoad(
        latest,
        batch: lazyBatch(totalCount: 60, range: 34..<44)
    )
    #expect(session.currentSnapshot?.selectedOrdinal == 40)
    #expect(session.currentSnapshot?.cues.map(\.ordinal) == Array(34..<44))
}

@MainActor
@Test
func subtitleFocusCloseClearsWindowLoadQueueAndRejectsLateResult() throws {
    let session = lazySession(
        snapshot: lazySnapshot(totalCount: 50, selectedOrdinal: 6, range: 0..<10)
    )
    session.noteScrollbarPreviewChanged(ordinal: 30)
    let request = try #require(
        session.windowLoadRequestForScrollbarTarget(ordinal: 30)
    )
    session.noteScrollbarPreviewChanged(ordinal: 40)
    _ = session.windowLoadRequestForScrollbarTarget(ordinal: 40)

    _ = session.dismissByUser()
    #expect(session.activeWindowLoadRequest == nil)
    #expect(session.pendingWindowLoadRequest == nil)
    #expect(session.retainedCueCount == 0)
    #expect(session.completeWindowLoad(
        request,
        batch: lazyBatch(totalCount: 50, range: 24..<34)
    ) == nil)
}

@Test
func subtitleFocusScrollbarMetricsStayBoundToCompleteDocument() throws {
    let empty = PlaybackSubtitleFocusScrollbarMetrics(
        totalCount: 0,
        cueViewportHeight: 656,
        displayedOrdinal: 0
    )
    #expect(empty.presentation.vertical == nil)

    let single = PlaybackSubtitleFocusScrollbarMetrics(
        totalCount: 1,
        cueViewportHeight: 656,
        displayedOrdinal: 0
    )
    #expect(single.presentation.vertical?.visibleFraction == 1)
    #expect(single.presentation.vertical?.positionFraction == 0)

    let short = PlaybackSubtitleFocusScrollbarMetrics(
        totalCount: 3,
        cueViewportHeight: 656,
        displayedOrdinal: 2
    )
    #expect(short.presentation.vertical?.visibleFraction == 1)
    #expect(short.presentation.vertical?.positionFraction == 1)

    let document = PlaybackSubtitleFocusScrollbarMetrics(
        totalCount: 20,
        cueViewportHeight: 656,
        displayedOrdinal: 10
    )
    let expectedFraction = 656 / PlaybackSubtitleFocusMetrics.reelHeight(cueCount: 20)
    #expect(abs((document.presentation.vertical?.visibleFraction ?? 0) - expectedFraction) < 0.0001)
    #expect(document.ordinal(for: 0) == 0)
    #expect(document.ordinal(for: 0.5) == 10)
    #expect(document.ordinal(for: 1) == 19)
}

@Test
func subtitleFocusFarTargetMotionUsesOnlyOneFinalCueSlot() {
    #expect(
        PlaybackSubtitleFocusTargetCommitMotion.insertionOffset(for: .forward)
            == PlaybackSubtitleFocusMetrics.cueSlotPitch
    )
    #expect(
        PlaybackSubtitleFocusTargetCommitMotion.insertionOffset(for: .backward)
            == -PlaybackSubtitleFocusMetrics.cueSlotPitch
    )
}

@Test
func subtitleFocusProtectedRangeUsesViewportAnchorAndAnimationMargin() {
    let normal = PlaybackSubtitleFocusProtectedRange.resolve(
        loadedOrdinals: Array(6..<16),
        selectedOrdinal: 12,
        focusAnchorY: 360,
        viewportMinY: 32,
        viewportMaxY: 688,
        presentationTranslation: 0
    )
    #expect(normal == 7..<16)

    let tallViewport = PlaybackSubtitleFocusProtectedRange.resolve(
        loadedOrdinals: Array(10..<40),
        selectedOrdinal: 12,
        focusAnchorY: 32,
        viewportMinY: 32,
        viewportMaxY: 5_000,
        presentationTranslation: 0
    )
    #expect(tallViewport == 10..<40)
}

@Test
func subtitleFocusScrollbarInteractionCommitsCachedTargetsImmediately() {
    var interaction = PlaybackSubtitleFocusScrollbarInteractionState()
    interaction.synchronizeCommittedOrdinal(6, force: true)
    #expect(interaction.handleDrag(
        phase: .began,
        targetOrdinal: 6,
        committedOrdinal: 6,
        isCached: true
    ).isEmpty)

    let effects = interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 8,
        committedOrdinal: 6,
        isCached: true
    )

    #expect(effects == [
        .cancelDebounce,
        .publishPreview(8),
        .commitCachedTarget(8),
    ])
    #expect(interaction.previewOrdinal == 8)
    #expect(interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 8,
        committedOrdinal: 8,
        isCached: true
    ).isEmpty)
}

@Test
func subtitleFocusScrollbarInteractionWaitsOneHundredMillisecondsForStableTarget() {
    var interaction = PlaybackSubtitleFocusScrollbarInteractionState()
    interaction.synchronizeCommittedOrdinal(6, force: true)
    _ = interaction.handleDrag(
        phase: .began,
        targetOrdinal: 6,
        committedOrdinal: 6,
        isCached: true
    )

    let effects = interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    )

    #expect(
        PlaybackSubtitleFocusScrollbarInteractionState.stableTargetDelayNanoseconds
            == 100_000_000
    )
    #expect(effects == [
        .cancelDebounce,
        .publishPreview(30),
        .scheduleDebounce(30),
    ])
    #expect(interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    ).isEmpty)
    #expect(interaction.debounceElapsed(
        for: 30,
        isCached: false
    ) == .requestTarget(30))
}

@Test
func subtitleFocusScrollbarInteractionRequestsUncachedMouseUpImmediately() {
    var interaction = PlaybackSubtitleFocusScrollbarInteractionState()
    interaction.synchronizeCommittedOrdinal(6, force: true)
    _ = interaction.handleDrag(
        phase: .began,
        targetOrdinal: 6,
        committedOrdinal: 6,
        isCached: true
    )
    _ = interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    )

    #expect(interaction.handleDrag(
        phase: .ended,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    ) == [
        .cancelDebounce,
        .requestTarget(30),
    ])
}

@Test
func subtitleFocusScrollbarInteractionRollsBackFailureAndCancellation() {
    var interaction = PlaybackSubtitleFocusScrollbarInteractionState()
    interaction.synchronizeCommittedOrdinal(6, force: true)
    _ = interaction.handleDrag(
        phase: .began,
        targetOrdinal: 6,
        committedOrdinal: 6,
        isCached: true
    )
    _ = interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    )
    _ = interaction.debounceElapsed(for: 30, isCached: false)

    #expect(interaction.resolveTarget(committedOrdinal: 6) == [.cancelDebounce])
    #expect(interaction.previewOrdinal == 6)
    #expect(interaction.failedStableTarget == 30)
    #expect(interaction.handleDrag(
        phase: .changed,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    ) == [
        .cancelDebounce,
        .publishPreview(30),
    ])
    #expect(interaction.handleDrag(
        phase: .cancelled,
        targetOrdinal: 30,
        committedOrdinal: 6,
        isCached: false
    ) == [
        .cancelDebounce,
        .publishPreview(6),
    ])
    #expect(interaction.previewOrdinal == 6)
    #expect(!interaction.isDragging)
    #expect(interaction.lastRequestedTarget == nil)
    #expect(interaction.failedStableTarget == nil)
}

@MainActor
private func lazySession(
    snapshot: SubtitleFocusSnapshot
) -> PlaybackSubtitleFocusSessionStore {
    let session = PlaybackSubtitleFocusSessionStore(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: lazySourceIdentity(),
            timestampMilliseconds: 6_500,
            wasPlaying: false
        ),
        sessionGeneration: 1
    )
    #expect(session.publishInitialSnapshot(snapshot, token: session.token))
    return session
}

private func lazySourceIdentity() -> SubtitleFocusSourceIdentity {
    SubtitleFocusSourceIdentity(
        videoPath: "/Media/Lazy.mkv",
        subtitlePath: "/Media/Lazy.srt",
        subtitleFormat: .srt
    )
}

private func lazyTargetIntent(
    ordinal: Int,
    range: Range<Int>
) -> PlaybackSubtitleFocusWindowLoadIntent {
    PlaybackSubtitleFocusWindowLoadIntent(
        kind: .target(ordinal: ordinal),
        range: range,
        totalCount: 60
    )
}

private func lazySnapshot(
    totalCount: Int,
    selectedOrdinal: Int,
    range: Range<Int>
) -> SubtitleFocusSnapshot {
    SubtitleFocusSnapshot(
        totalCount: totalCount,
        selectedOrdinal: selectedOrdinal,
        cues: lazyCues(range)
    )
}

private func lazyBatch(
    totalCount: Int,
    range: Range<Int>
) -> SubtitleFocusCueBatch {
    SubtitleFocusCueBatch(
        totalCount: totalCount,
        cues: lazyCues(range)
    )
}

private func lazyCues(_ range: Range<Int>) -> [SubtitleFocusCue] {
    range.map { ordinal in
        SubtitleFocusCue(
            id: Int64(ordinal + 1),
            ordinal: ordinal,
            startMilliseconds: ordinal * 1_000,
            endMilliseconds: ordinal * 1_000 + 900,
            lines: ["lazy cue \(ordinal)"]
        )
    }
}
