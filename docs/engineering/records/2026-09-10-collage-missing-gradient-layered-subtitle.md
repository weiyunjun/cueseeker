# Collage brings back the clipped copies of a gradient subtitle line

Human-owned documents:

- `docs/human/requirements/20260910-Bug-Collage Missing Gradient Layered Subtitle.md`

## Why

A Collage of Cue 8515265 (Girls Band Cry episode 06, `0:22:17.20`) came out with no subtitle at all, while a screenshot taken from the playback screen at the same time showed both lines. From that Cue to the end of the file every Collage of that subtitle behaved the same way.

The subtitle paints the ED lyrics as a vertical colour gradient. One lyric line is not one event: it is seven identical events stacked on top of each other, each `\clip`ped to an eight-pixel horizontal band of the same glyphs. In this file the technique starts exactly at `0:22:17.20` and covers 254 events across 34 lyric lines; the two ED lines before it are ordinary single events, which is why they still worked.

Indexing collapses events that differ only in their override tags, so the Cue keeps one of the seven and drops the copies. That is right for search and for the Cue list. Collage, however, renders a Cue by filtering the script down to the event indices the Cue recorded, so it drew one band out of seven — the top edge of an outline, invisible against the picture. The playback screenshot path renders the whole script at the timestamp, so all seven bands are drawn and the line looks normal.

The Cue's recorded event index was never wrong: file event 1067 is exactly the line the Cue points at. The defect is that one indexed event is no longer enough to reproduce what the viewer sees, and it has been there since Collage began filtering by event index.

## What changed

The Collage script filter now also keeps the Dialogue lines that differ from a selected line only inside `{...}`.

`SubtitleScreenshotExporter.selectedASSRenderScript` takes a first pass over the script bytes to record, for each selected event, the line with its override blocks removed. The emitting pass keeps a Dialogue line when its index is selected, or when the same stripped form is one of those. Every other line is treated exactly as before.

That test is a sufficient condition for indexing's own deduplication identity — same style, same remaining fields, same start and end, same cleaned text — so it can only ever pull in events that were collapsed into the selected Cue, never a different Cue's line. It is not the necessary condition: an exotic pair that indexing merges through `\N` versus `\n` would not be recognised, and would render exactly as it does today.

Two alternatives were rejected on cost. Asking `ASSParser` for the collapsed groups measured 2.75 s on a 12 MB script, and `renderCollageGroups` runs once per group, so every Collage checkbox tick would have paid it. Rebuilding the deduplication identity field by field would need the event format and a split per line, for the same result as comparing bytes.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/SubtitleScreenshotExporterTests.swift`

## Verification

Unit: `subtitleCollageASSRenderScriptKeepsTheClippedCopiesOfASelectedDialogue` selects one event of a two-event gradient stack and asserts the script keeps both copies, drops an unrelated line at the same time and style, and drops a copy whose margin differs. `swift test --filter CueSeekerPlaybackTests` passes, 71 tests. `swift test --filter CueSeekerCoreTests` passes, 300 tests. `CueSeekerAppTests` has two failures in `CueGroupRefreshScopeIntegrationTests` that also fail with this change stashed; they are unrelated.

Selection, on the reported sample: `_selectedASSRenderScriptForTesting` with the Cue's two recorded events, 944 and 1067, now emits 14 Dialogue lines, byte for byte the seven Chinese and seven Japanese copies of that lyric.

Rendering, through `ASSRenderingProbe` at 1 338 390 ms, 1920×1080:

| | events in script | drawn pixels | drawn rows |
|---|---|---|---|
| before | 2 | 991 | y 1014–1020 |
| after | 14 | 25 192 | y 30–1055 |

Before, the Chinese line at the top of the frame drew nothing at all and the Japanese line drew a seven-pixel band. After, both lines are complete and match the playback screenshot the user reported.

Cost, release build, on the 12 MB `It's MyGO!!!!!` episode 06 script with 44 269 dialogue lines: building the selected script goes from 0.004 s to 0.034 s, against a Collage group render of about 0.66 s.

Application acceptance — opening the Collage editor on that Cue and comparing the exported image — is left to the human owner as the requirement states; the Debug E2E controller was not extended for it.
