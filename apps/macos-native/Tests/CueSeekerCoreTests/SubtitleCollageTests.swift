import Testing
@testable import CueSeekerCore

@Test
func subtitleCollageMergesIdenticalTimestampsAndUsesTheirMidpoint() throws {
    let first = collageCue(
        id: 1,
        eventIndex: 2,
        displayOrder: 1,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let second = collageCue(
        id: 2,
        eventIndex: 1,
        displayOrder: 0,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )

    let plan = try SubtitleCollageSelectionPlan(selectedCues: [first, second])

    #expect(plan.groups.count == 1)
    #expect(plan.groups[0].timeRanges.count == 1)
    #expect(plan.groups[0].cues.map(\.id) == [2, 1])
    #expect(plan.groups[0].renderTimestampMilliseconds == 1_500)
}

@Test
func subtitleCollageSortsTimestampsBeforeGrouping() throws {
    let plan = try SubtitleCollageSelectionPlan(selectedCues: [
        collageCue(id: 3, startMilliseconds: 4_000, endMilliseconds: 5_000),
        collageCue(id: 2, startMilliseconds: 1_000, endMilliseconds: 3_000),
        collageCue(id: 1, startMilliseconds: 1_000, endMilliseconds: 2_000),
    ])

    #expect(plan.groups.flatMap(\.timeRanges) == [
        SubtitleCollageTimeRange(startMilliseconds: 1_000, endMilliseconds: 2_000),
        SubtitleCollageTimeRange(startMilliseconds: 1_000, endMilliseconds: 3_000),
        SubtitleCollageTimeRange(startMilliseconds: 4_000, endMilliseconds: 5_000),
    ])
}

@Test
func subtitleCollageRequiresOneHundredMillisecondsOfGroupIntersection() throws {
    let exactBoundaryPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collageCue(id: 1, startMilliseconds: 0, endMilliseconds: 500),
        collageCue(id: 2, startMilliseconds: 400, endMilliseconds: 900),
    ])
    let belowBoundaryPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collageCue(id: 1, startMilliseconds: 0, endMilliseconds: 500),
        collageCue(id: 2, startMilliseconds: 401, endMilliseconds: 900),
    ])

    #expect(exactBoundaryPlan.groups.count == 1)
    #expect(exactBoundaryPlan.groups[0].renderTimestampMilliseconds == 450)
    #expect(belowBoundaryPlan.groups.count == 2)
}

@Test
func subtitleCollageTestsNewTimestampAgainstTheWholeGroup() throws {
    let plan = try SubtitleCollageSelectionPlan(selectedCues: [
        collageCue(id: 1, startMilliseconds: 0, endMilliseconds: 500),
        collageCue(id: 2, startMilliseconds: 100, endMilliseconds: 1_000),
        collageCue(id: 3, startMilliseconds: 401, endMilliseconds: 900),
    ])

    #expect(plan.groups.count == 2)
    #expect(plan.groups[0].cues.map(\.id) == [1, 2])
    #expect(plan.groups.last?.cues.map(\.id) == [3])
}

@Test
func subtitleCollageIncrementalMutationReportsOnlyChangedGroups() throws {
    let first = collageCue(id: 1, startMilliseconds: 0, endMilliseconds: 500)
    let inserted = collageCue(id: 2, startMilliseconds: 400, endMilliseconds: 900)
    let stable = collageCue(id: 3, startMilliseconds: 2_000, endMilliseconds: 3_000)
    var plan = try SubtitleCollageSelectionPlan(selectedCues: [first, stable])

    let insertion = plan.select(inserted)
    let rebuiltAfterInsertion = try SubtitleCollageSelectionPlan(
        selectedCues: [first, inserted, stable]
    )

    #expect(plan.groups == rebuiltAfterInsertion.groups)
    #expect(
        insertion == .changed(
            SubtitleCollageGroupChange(
                previousGroupRange: 0..<1,
                currentGroupRange: 0..<1
            )
        )
    )

    let removal = plan.deselect(cueID: inserted.id)
    let rebuiltAfterRemoval = try SubtitleCollageSelectionPlan(
        selectedCues: [first, stable]
    )

    #expect(plan.groups == rebuiltAfterRemoval.groups)
    #expect(
        removal == .changed(
            SubtitleCollageGroupChange(
                previousGroupRange: 0..<1,
                currentGroupRange: 0..<1
            )
        )
    )
}

@Test
func subtitleCollageIncrementalSplitMatchesCompleteRebuild() throws {
    let first = collageCue(id: 1, startMilliseconds: 0, endMilliseconds: 1_000)
    let bridge = collageCue(id: 2, startMilliseconds: 100, endMilliseconds: 600)
    let third = collageCue(id: 3, startMilliseconds: 500, endMilliseconds: 900)
    let stable = collageCue(id: 4, startMilliseconds: 2_000, endMilliseconds: 3_000)
    var plan = try SubtitleCollageSelectionPlan(
        selectedCues: [first, bridge, third, stable]
    )

    _ = plan.deselect(cueID: bridge.id)
    let rebuilt = try SubtitleCollageSelectionPlan(
        selectedCues: [first, third, stable]
    )

    #expect(plan.groups == rebuilt.groups)
}

@Test
func subtitleCollageEnforcesFiftyCueSelectionLimit() throws {
    let cues = (0..<SubtitleCollageSelectionPlan.maximumSelectedCueCount).map {
        collageCue(
            id: Int64($0),
            startMilliseconds: $0 * 1_000,
            endMilliseconds: ($0 + 1) * 1_000
        )
    }
    var plan = try SubtitleCollageSelectionPlan(selectedCues: cues)
    let extra = collageCue(
        id: 100,
        startMilliseconds: 60_000,
        endMilliseconds: 61_000
    )

    #expect(plan.selectedCueCount == 50)
    #expect(!plan.canSelectAnotherCue)
    #expect(plan.select(extra) == .selectionLimitReached)
    #expect(plan.deselect(cueID: cues[0].id) != .unchanged)
    #expect(plan.canSelectAnotherCue)
    #expect(plan.select(extra) != .selectionLimitReached)
    #expect(throws: SubtitleCollageSelectionError.selectionLimitExceeded) {
        _ = try SubtitleCollageSelectionPlan(selectedCues: cues + [extra])
    }
}

@Test
func subtitleCollageIncrementalUpdatesMatchCompleteRebuildAcrossSequence() throws {
    var seed: UInt64 = 0xC011_A6E
    let cues = (0..<30).map { index in
        let start = Int(nextCollageTestValue(&seed) % 8_000)
        let duration = 200 + Int(nextCollageTestValue(&seed) % 1_600)
        return collageCue(
            id: Int64(index),
            displayOrder: index % 3,
            startMilliseconds: start,
            endMilliseconds: start + duration
        )
    }
    var selectedCueIDs = Set<Int64>()
    var plan = SubtitleCollageSelectionPlan()

    for _ in 0..<200 {
        let cue = cues[Int(nextCollageTestValue(&seed) % UInt64(cues.count))]
        if selectedCueIDs.remove(cue.id) != nil {
            _ = plan.deselect(cueID: cue.id)
        } else {
            selectedCueIDs.insert(cue.id)
            _ = plan.select(cue)
        }

        let rebuilt = try SubtitleCollageSelectionPlan(
            selectedCues: cues.filter { selectedCueIDs.contains($0.id) }
        )
        #expect(plan.groups == rebuilt.groups)
        #expect(plan.selectedCues == rebuilt.selectedCues)
    }
}

private func collageCue(
    id: Int64,
    eventIndex: Int? = nil,
    displayOrder: Int = 0,
    startMilliseconds: Int,
    endMilliseconds: Int
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: id,
        cueGroupID: id,
        ordinal: Int(id),
        eventIndex: eventIndex ?? Int(id),
        displayOrder: displayOrder,
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: "Cue \(id)"
    )
}

private func nextCollageTestValue(_ seed: inout UInt64) -> UInt64 {
    seed = seed &* 6_364_136_223_846_793_005 &+ 1
    return seed
}
