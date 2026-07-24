import Testing
@testable import CueSeekerCore

@Test
func exactCueIdentityIgnoresEventIndexAndDisplayOrder() {
    let stored = storedCue(
        id: 41,
        format: .ass,
        style: "JP",
        remainder: "layer=0",
        start: 1_000,
        end: 2_000,
        content: "同じ"
    )
    let replacement = cueLine(
        eventIndex: 900,
        displayOrder: 17,
        format: .ass,
        style: "JP",
        remainder: "layer=0",
        start: 1_000,
        end: 2_000,
        content: "同じ"
    )

    let assignments = CueIdentityReconciler.reconcile(
        storedCues: [stored],
        newCues: [replacement]
    )

    #expect(assignments[0]?.cueID == 41)
}

@Test
func assIdentityRequiresStableStyleAndAtMostOneChangedPart() {
    let stored = storedCue(
        id: 51,
        format: .ass,
        style: "JP",
        remainder: "layer=0",
        start: 1_000,
        end: 2_000,
        content: "Original"
    )

    let contentOnly = cueLine(
        format: .ass,
        style: "JP",
        remainder: "layer=0",
        start: 1_000,
        end: 2_000,
        content: "Edited"
    )
    let layerOnly = cueLine(
        format: .ass,
        style: "JP",
        remainder: "layer=1",
        start: 1_000,
        end: 2_000,
        content: "Original"
    )
    let timeAndContent = cueLine(
        format: .ass,
        style: "JP",
        remainder: "layer=0",
        start: 3_000,
        end: 4_000,
        content: "Edited"
    )
    let changedStyle = cueLine(
        format: .ass,
        style: "CN",
        remainder: "layer=0",
        start: 1_000,
        end: 2_000,
        content: "Original"
    )

    #expect(
        CueIdentityReconciler.reconcile(
            storedCues: [stored],
            newCues: [contentOnly]
        )[0]?.cueID == 51
    )
    #expect(
        CueIdentityReconciler.reconcile(
            storedCues: [stored],
            newCues: [layerOnly]
        )[0]?.cueID == 51
    )
    #expect(
        CueIdentityReconciler.reconcile(
            storedCues: [stored],
            newCues: [timeAndContent]
        ).isEmpty
    )
    #expect(
        CueIdentityReconciler.reconcile(
            storedCues: [stored],
            newCues: [changedStyle]
        ).isEmpty
    )
}

@Test
func ambiguousSameTimeSRTCuesAllReceiveNewIdentity() {
    let stored = [
        storedCue(
            id: 61,
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "First"
        ),
        storedCue(
            id: 62,
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Second"
        )
    ]
    let replacements = [
        cueLine(
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Changed A"
        ),
        cueLine(
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Changed B"
        )
    ]

    #expect(
        CueIdentityReconciler.reconcile(
            storedCues: stored,
            newCues: replacements
        ).isEmpty
    )
}

@Test
func exactSRTCueLocksBeforeUniqueSiblingEdit() {
    let stored = [
        storedCue(
            id: 71,
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Stable"
        ),
        storedCue(
            id: 72,
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Original"
        )
    ]
    let replacements = [
        cueLine(
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Stable"
        ),
        cueLine(
            format: .srt,
            start: 1_000,
            end: 2_000,
            content: "Edited"
        )
    ]

    let assignments = CueIdentityReconciler.reconcile(
        storedCues: stored,
        newCues: replacements
    )

    #expect(assignments[0]?.cueID == 71)
    #expect(assignments[1]?.cueID == 72)
}

private func storedCue(
    id: Int64,
    format: SubtitleFormat,
    style: String? = nil,
    remainder: String = "",
    start: Int,
    end: Int,
    content: String
) -> StoredCueIdentity {
    StoredCueIdentity(
        cueID: id,
        sourceFormat: format,
        sourceStyle: style,
        sourceIdentityRemainder: remainder,
        startMilliseconds: start,
        endMilliseconds: end,
        content: content
    )
}

private func cueLine(
    eventIndex: Int = 0,
    displayOrder: Int = 0,
    format: SubtitleFormat,
    style: String? = nil,
    remainder: String = "",
    start: Int,
    end: Int,
    content: String
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: format,
        sourceStyle: style,
        sourceLayer: nil,
        sourceIdentityRemainder: remainder,
        startTimecode: "\(start)",
        endTimecode: "\(end)",
        startMilliseconds: start,
        endMilliseconds: end,
        content: content,
        displayX: nil,
        displayY: nil,
        displayOrder: displayOrder
    )
}
