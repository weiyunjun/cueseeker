# Missing groups render side by side, and the preview shows each one as it lands

Human-owned documents:

- `docs/human/requirements/20260909-Feature-Collage Preview Renders Missing Groups Concurrently.md`

## Why

The previous requirement removed duplicate group renders, but a burst of five checkbox clicks still waited about 1.7 seconds after the last click, because the groups that were still missing rendered one after another. Each group is an independent frame grab and subtitle render, so nothing forces that order. And while the plan kept changing, nothing reached the screen at all: the preview was only published once every group of the current plan was rendered, which during a burst is a moment that keeps moving away.

The failed-group path had a real defect too: a group that failed after the plan had moved on left the worker exited and the store stuck in its rendering state until the next click.

## What changed

- The worker renders the missing groups of the current plan as one batch of concurrent tasks, at most four at a time. Each task keeps its result the moment it finishes; the plan is re-read when the batch is done.
- Every time the set of rendered groups the current plan can show changes — a group lands, or the selection changes — the store composes those groups in plan order and publishes that image at once. Missing groups simply are not in it yet. The final publish, once every group is present, composes the whole plan once more and commits it; a publish generation discards any partial compose that lands after a newer one.
- Copy Collage and Export Collage are no longer disabled while rendering. The session store owns the rule: both the buttons and the controller mapping call it, and a result that is not committed yet answers with the playback feedback capsule, carrying the triggered button's icon and the text `Collage Not Ready` / `长截图未就绪`. The playback store wires that hook to the playback view model when it creates the session.
- A batch failure is reported only when the plan still depends on the failed group; otherwise the loop continues with the current plan.
- The batch runs as unstructured tasks on purpose: cancelling the worker (leaving Collage) does not cut a batch short, the worker stops at the batch boundary, and nothing waits for it.

The structured task group was tried first and rejected by the compiler: the injected render closure is not sendable, and making it main-actor isolated did not satisfy the `sending` check either. Tasks that inherit the main actor need neither.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreviewStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreview.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusSessionStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCollagePreviewTests.swift`

## Verification

Sample: `It's MyGO!!!!!` episode 05, Debug build, driven by the Debug E2E controller exactly as the previous record: Library to the episode, Enter, `P`, then checkbox clicks 100 ms apart on five reel rows that form three new groups — two pairs sharing their timestamps and one single cue. Each round leaves and re-enters Collage first. Timing is by continuous capture at about 90 ms resolution; a capture whose whole PNG hash differs from the previous one counts as a preview change, which was checked to stay stable while idle and not to fire on the checkbox toggle itself. Render counts come from a temporary line on stderr removed before this commit.

The baseline column is the "cache + one-at-a-time" column of the previous record, as the requirement asks. The middle column was measured after the concurrent batch alone, before per-group publishing existed.

| | baseline | concurrent batch | batch + publish per group |
|---|---|---|---|
| single click, wait | 0.650s | 0.686 / 0.705 / 0.706s | 0.594 / 0.509 / 0.503s |
| five clicks, first visible change after the first click | — | — | 1.144 / 1.146 / 1.227s |
| five clicks, first visible change after the last click | — | — | 0.740 / 0.741 / 0.823s |
| five clicks, final image after the last click | 1.690 / 1.697 / 1.690s | 1.208 / 1.198 / 1.185s | **1.018 / 1.113 / 1.104s** |
| five clicks, renders (3–5 needed) | 4 / 4 / 4 | 4 / 4 / 4 | 4 / 4 / 4 |
| phys_footprint steady / peak | 155 MB / 234 MB | 148 MB / 309 MB | 149 MB / 309 MB |

Per-phase timing from the temporary log, Debug build: decoding the subtitle costs 0.10s per group call, the frame grab 0.30s on its own, the subtitle render and composite 0.26s. A batch of three took 0.89s wall time instead of 0.30s: the three ffmpeg processes contend for the cores, and their grabs finished at 0.22 / 0.31 / 0.53s, so the slowest one sets the batch. The speed-up over sequential rendering is about 2.2×.

The not-ready capsule was checked in the same session: ticking a cue and pressing Copy Collage or Export Collage right away shows `Collage Not Ready` with the copy or the export icon over the editor, the capsule is gone a second later, and Copy after the preview settled puts a PNG on the pasteboard. The capture during the export check also showed the preview already holding two groups while the third was still rendering.

Memory: steady footprint unchanged; the peak rises by about 75 MB, which is the frames, subtitle layers and composites of three groups in flight at once, and it falls back once they are kept.

Unit tests: the eight Collage preview tests pass, three of them new — four renders at a time with the fifth waiting, a failed group the plan no longer needs, and partial publishing with Copy/Export held until commit.

Full `swift test`, 1166 tests: 18 names failed in the full run. One was this change — the bundled-languages key check, because the new string was missing from `zh-Hant`; it passes since the key was added. Of the other 17, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` and `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks` pass when run on their own, and the rest — native playback audio and seeking, library folder removal, the Debug E2E window geometry, and the Search and Shiori refresh-scope integration tests `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori` — are listed as failing in earlier records on this tree. None touches the Collage editor, the subtitle focus session, or the playback feedback.

## Hardware decode, measured and rejected

Asked whether the frame grab should decode with VideoToolbox like the player, with software fallback: measured on the same title with the same ffmpeg command, six runs each. At the recorded sample instant (21 frames after the keyframe) software took 0.120s and hardware 0.124s; 105 frames after the keyframe software 0.154s against hardware 0.222s; one frame after the keyframe 0.228s against 0.210s. The output bytes were identical. Process start, container probe, the first decode and writing the 6 MB frame to the pipe cost 0.065s regardless of decoder; software decode already uses every core (single-threaded the same grab takes 0.266s), while hardware decode drops that threading and copies every decoded frame back from the media engine, session set-up included, in a fresh process each time. Not worth doing.

Incidentally, ffmpeg moves an input seek 0.13s earlier to cover B-frame reordering, so an instant within 0.13s after a keyframe decodes from the previous keyframe; that is why the one-frame case above is the slowest.

## Known limits

The batch boundary is now the largest remaining wait. The first click starts a batch of one group at once; every group selected during those ~0.6s only starts when that batch ends. In the measured burst the first click's group was superseded anyway (the second click selected its timestamp partner, which changes the group), so the first visible update arrived 1.1–1.2s after the first click. Starting groups as soon as they are selected, up to the same cap, would move the first update to roughly 0.4s after the last click and the final image to roughly 0.7–0.8s; that is a change to the requirement's first item, not to this one.

Contention among concurrent ffmpeg processes limits the batch speed-up to about 2.2× on this machine.

The partial composes run as separate tasks, so their completion order is not fixed; a generation counter keeps the newest one on screen, and the unit test compares the set of composes rather than their order.

The figures are Debug-build figures, only comparable with the previous record's Debug figures. Reel coordinates were derived for this run from a capture and are not accepted procedure coordinates.
