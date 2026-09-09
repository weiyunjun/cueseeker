# One render per group at a time, and finished groups are kept

Human-owned documents:

- `docs/human/requirements/20260909-Feature-Collage Preview Keeps Rendered Groups.md`

## Why

Ticking a checkbox in Collage cancelled whatever render was running and started over from the last published result. Cancelling does not stop the frame grab that is already running — it runs in a detached task and the helper process is never signalled — so the restart began a second render of the very same group. Clicking five times in about half a second produced seven to eight group renders where three to five were needed, and nothing appeared on screen until the whole thing settled.

The first attempt only added the cache the requirement originally described. It measured almost nothing: 1.94–1.99s down to 1.56–1.70s, still seven renders. A cache cannot help while every click restarts the group that is currently in flight, because no group ever finishes between two clicks. The requirement was corrected to say what actually had to change — one render per group at a time, never interrupted — and this record covers that version.

## What changed

The preview store now runs a single long-lived worker instead of a task per request.

- A selection change records the new plan and, if no worker is running, starts one. It never cancels.
- The worker renders one missing group at a time, keeps the result, and then re-reads whatever plan is current before choosing the next group. A plan that changed mid-group is picked up at the group boundary, so the same group is never rendered twice at once.
- Rendered groups are kept in a list keyed by group content and survive a superseded request. After a successful publish the list is pruned to the current plan; leaving Collage clears it.
- The prefix/suffix reuse against the last published result is gone. The cache subsumes it, and the store lost about as much code as it gained.
- Leaving Collage still cancels: the worker checks for cancellation at the top of each pass and after composing, so it stops at the next group boundary, at most one group later. Nothing awaits it, so exit is not held up.

The render closure now takes one group instead of a batch, which is what let the loop interleave with the plan. Its only cost is that the subtitle is decoded once per group rather than once per batch — 0.014s on the largest sample in the library, against roughly 0.5s to render a group.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCollagePreviewStore.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackCollagePreviewTests.swift`

## Verification

Sample: `It's MyGO!!!!!` episode 05, Debug build, driven by the Debug E2E controller. Library to the episode, Enter, `P`, then clicks on checkboxes in the cue reel. Each round first leaves and re-enters Collage so it starts from one selected cue. Timing is from the last click to the first capture whose preview region differs, at about 60 ms resolution; the render count comes from a temporary line on stderr that was removed before this commit.

Both the baseline and the final rounds clicked the same five reel positions. In each case those five cues form three new groups, because two pairs share their timestamps and merge — so three to five renders are genuinely required, the spread depending on whether both halves of a merging pair are clicked before that group starts rendering.

| | baseline | cache only | cache + one-at-a-time |
|---|---|---|---|
| single click, wait | 0.650s | 0.639s | 0.650s |
| single click, renders | 1 | 1 | 1 |
| five clicks, wait after the last | 1.936 / 1.982 / 1.990s | 1.556 / 1.697 / 1.702s | **1.690 / 1.697 / 1.690s** |
| five clicks, renders (3–5 needed) | 7 / 8 / 8 | 7 / 7 / 7 | **4 / 4 / 4** |
| phys_footprint | 148 MB, peak 247 MB | 153 MB, peak 238 MB | 155 MB, peak 234 MB |

**Duplicate rendering is gone** — four renders against three to five required, down from seven or eight. **The wait improved only about 13%**, and that is the honest headline. The duplicates the baseline produced ran concurrently with the work that was actually needed, so they cost processor and disk time rather than wall clock. What is left is the necessary work: at roughly 0.5s per group, four groups started during a 0.5s burst finish about 1.7s after the last click. Cutting that further needs either a faster group render, groups rendered in parallel, or partial results published as they arrive — the last is explicitly out of scope for this requirement.

Memory is unchanged within noise, and the peak came down rather than up.

`swift test`: 14 failing tests against 15 in the pre-change baseline, compared by test name. One name appears in this run that was not in that baseline, `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`; it passed three out of three when its family was run on its own, and library folder removal is one of the families earlier records already list as failing on this tree. All five Collage preview tests pass.

## Known limits

The wait figure is the whole point of the requirement and it barely moved. The change is still worth keeping — it removes real duplicated work and leaves the store smaller — but it does not on its own make fast clicking feel responsive.

The obsolete-result test was rewritten rather than kept as it was. Its old form asserted that superseding a plan starts a second render immediately, which is exactly the behaviour this requirement removes. It now asserts the opposite and additionally checks the total number of renders.

The burst driver sends clicks about 100 ms apart through the E2E controller. That is a plausible fast click, but it is not a measurement of how fast a person actually clicks, and the results depend on that interval relative to the roughly 0.5s a group takes.

An earlier attempt at this measurement drove the selection with arrow keys and Return. Keyboard focus does not advance fast enough at that rate, so the toggles landed on the same cue repeatedly and the round measured nothing. Checkbox clicks are the driver that works; the coordinates were derived ad hoc for this run and are not accepted procedure coordinates.

The render count came from a temporary log that is not in the committed code, so that column cannot be reproduced from this tree without adding it back.
