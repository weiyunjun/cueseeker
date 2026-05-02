# Source-Faithful ASS Playback Rendering Pipeline

Status: Accepted

## Background

CueSeeker now indexes `.ass` files, returns grouped ASS search results, and can
load the selected source `.ass` file into an ASS Lite overlay. Real-world ASS
files can contain tens of thousands of timed `Dialogue` events that are not
plain subtitle text. Common examples include karaoke masks, vector drawings,
blurred particles, bubble effects, clipped text reveals, and many short-lived
`Effect=fx` events.

Search and playback have different responsibilities:

- Search should return real dialogue, lyric, and readable subtitle text.
- Playback rendering must remain faithful to the source subtitle timeline,
  including timed effects and drawing events.

The existing database is a search projection. It stores cleaned text, cue timing,
grouped cue lines, source style names, layers, and approximate layout metadata.
It intentionally does not store enough raw ASS override data to reconstruct a
full subtitle render. The source `.ass` file remains the rendering authority.

The current ASS Lite overlay is useful as an interim readable-text fallback, but
it is not a viable endpoint for complex ASS rendering. A source-faithful ASS
pipeline is required.

## Goals

- Keep search results focused on real searchable text, not vector path commands
  or repeated visual-effect fragments.
- Preserve every timed source ASS event for playback rendering, including
  `Effect=fx`, `\p` vector drawing, `\clip`, karaoke, blur, alpha, transforms,
  and short-duration effect events.
- Decouple ASS subtitle rendering from video playback and the main UI thread.
- Ensure row selection, Playback Inspector visibility, video open, and video
  seek never wait for ASS parsing or ASS rendering to finish.
- Use the database cue timing to optimize playback startup, prefetching, and
  renderer catch-up without treating database rows as a replacement renderer.
- Move toward a renderer that can display complex ASS effects comparably to
  established players such as Movist Pro.
- Keep the implementation staged, measurable, and reversible.

## Non-goals

- Asking users to edit or simplify their ASS subtitle files.
- Dropping timed ASS events from playback rendering because they are complex.
- Treating `Effect=fx` as disposable in playback.
- Rendering vector drawing commands as text.
- Blocking video playback until subtitle rendering is ready.
- Replacing the native video backend with `libmpv`.
- Rebuilding a full ASS renderer by hand if a dedicated renderer dependency is
  the safer engineering choice.

## Decisions

### Search Projection Versus Render Timeline

The SQLite search database remains a projection optimized for search and result
presentation. It may exclude non-searchable effect content from FTS, but it must
not define what playback is allowed to render.

The playback renderer must use a source render timeline derived from the source
`.ass` file or from a cache generated from that exact file. The render timeline
must preserve raw timed events needed for visual fidelity.

### Database Timing As Startup Guidance

Search results already provide the selected cue group's `start_ms`, `end_ms`,
source subtitle path, matched video path, and grouped readable text. Playback
should use this information to:

- Select the playback seek target immediately.
- Decide the initial subtitle time window to prioritize.
- Prefetch nearby render events after playback starts.
- Keep the UI and video path responsive even when the source file is large.

Database cue data must not be used to recreate full ASS visuals. It is a timing
and search guide, not a renderer.

### Non-blocking Playback Contract

The user-visible click path must be:

```text
User clicks search result
Selected row updates immediately
Playback Inspector opens immediately
Video open or seek starts immediately
ASS render preparation starts or reuses cache asynchronously
Renderer attaches output when ready and catches up to current playback time
```

If ASS parsing or rendering is slow, fails, or encounters unsupported features,
video playback must continue. The UI may show a concise subtitle status, but it
must not block row selection or video controls.

### Renderer Direction

The long-term direction is a dedicated ASS rendering pipeline that can render
source ASS events into an overlay bitmap, texture, layer, or equivalent native
surface synchronized to the native playback clock.

The preferred implementation path is to evaluate and integrate a dedicated ASS
renderer such as `libass` before expanding the project-owned ASS Lite renderer
into a custom full ASS renderer. A dependency decision must account for:

- Packaging and notarization.
- Font discovery and font fallback.
- Embedded or same-directory fonts.
- Renderer threading and cache behavior.
- Pixel format and alpha compositing over the native video surface.
- Behavior on both Playback Inspector and Theater Mode fullscreen surfaces.

ASS Lite remains an interim fallback for simple text-only cases and for
regression isolation.

## Architecture

Expected components:

- `SearchProjectionStore`: the existing SQLite search database and FTS index.
- `ASSRenderTimeline`: source-derived render events preserving timing, layer,
  style, raw override tags, drawing data, and event order.
- `ASSRenderCache`: an in-memory and optional persistent cache keyed by subtitle
  path, file size, modified time, and renderer version.
- `ASSRenderCoordinator`: orchestrates async source loading, cache lookup,
  renderer preparation, cancellation, and current-time catch-up.
- `ASSRenderer`: dedicated source-faithful renderer that receives current time
  and returns composited subtitle output.
- `SubtitleOverlayHost`: native overlay surface attached to the playback render
  container without owning video playback.

Ownership rules:

- App state owns selected result, inspector visibility, and playback commands.
- The native video backend owns video decode and presentation.
- The ASS render coordinator owns subtitle preparation and render lifecycle.
- The overlay host only displays renderer output and handles visibility.
- Search indexing does not perform playback rendering.

Threading rules:

- Search result selection and inspector visibility run on the main actor.
- Video open and seek must not synchronously wait on ASS source parsing.
- Source ASS parsing and renderer initialization happen off the main actor.
- Renderer output commits to the overlay host on the main actor only for the
  minimal UI update needed to present the frame.
- Cancelling or replacing a selected result must cancel stale subtitle work.

## Data Model Impact

No immediate schema change is required to unblock non-blocking playback.

Future schema or cache work may add a render-manifest cache, but it must be
separate from FTS search content. A render manifest may store:

- Source file identity: path, size, modified time, hash if needed.
- Parsed event timing and source order.
- Raw event text and override tag data.
- Style definitions and script metadata.
- Renderer compatibility metadata.

Search result rows should continue to expose readable cue text. If a source ASS
file contains many timed effect events with no searchable dialogue text, those
events may be absent from FTS search results while still present in the playback
render timeline.

## Detailed Implementation Plan

### Phase 0: Evidence And Guardrails

1. Add fixtures for complex real-world ASS patterns:
   - `Effect=fx` events.
   - `\p1` vector drawing events.
   - `\clip(...)` text reveal events.
   - Repeated short-duration karaoke or visual-effect events.
   - Zero-duration or near-zero-duration events.
2. Add timing instrumentation around:
   - Search result click handling.
   - Video open and seek.
   - ASS source file read.
   - ASS parse or render preparation.
   - First subtitle frame presentation.
3. Define performance budgets:
   - Search row selection should be visible within one UI frame.
   - Video open or seek should not wait for ASS preparation.
   - Subtitle preparation may complete later and catch up.
4. Document fallback behavior for missing, unreadable, or unsupported subtitle
   rendering.

### Phase 1: Non-blocking ASS Preparation

1. Split search result selection from playback startup:
   - Update `selectedSearchResult` immediately.
   - Open the Playback Inspector immediately.
   - Schedule playback work after the UI state update is committed.
2. Change playback startup so video open and seek do not synchronously call ASS
   parsing.
3. Introduce an async subtitle preparation task:
   - Cancel stale tasks when another result is selected.
   - Reuse prepared subtitle state for the same file.
   - Attach output only if the selected result is still current.
4. Keep playback running when subtitle preparation fails.
5. Preserve SRT behavior and subtitle visibility controls.

### Phase 2: Render Timeline And Cache

1. Replace playback-only all-events text parsing with a source render timeline
   model that preserves raw timed events.
2. Build an active-time index so the renderer can query events by current time
   without scanning and sorting every dialogue on every frame.
3. Use database cue timing to prioritize the selected time window and prefetch
   neighboring windows.
4. Cache parsed timelines by source file identity.
5. Keep search projection and render timeline separate in code and tests.

### Phase 3: Dedicated ASS Renderer Evaluation

1. Evaluate `libass` or an equivalent dedicated ASS renderer for:
   - Static text styling.
   - `\pos`, `\move`, `\clip`, `\p` vector drawing, blur, border, alpha,
     karaoke, and transforms.
   - Complex files with tens of thousands of events.
   - Font discovery and fallback on macOS.
   - Rendering to an alpha bitmap or texture suitable for native overlay
     compositing.
2. Document dependency, packaging, and signing implications before merging the
   renderer.
3. Build a renderer adapter behind a protocol so ASS Lite can remain as a
   fallback during rollout.

### Phase 4: Source-faithful Overlay Integration

1. Attach renderer output to the existing playback render container.
2. Drive subtitle frames from the native playback clock.
3. Keep Theater Mode fullscreen and Playback Inspector using the same overlay
   host.
4. Ensure subtitle visibility toggles renderer output without stopping video.
5. Handle renderer readiness, failure, and catch-up states without blocking
   playback controls.

### Phase 5: Search And Playback Regression Hardening

1. Verify search results still return real dialogue and lyric text.
2. Verify complex ASS visual-effect events are not exposed as meaningless
   search text.
3. Verify complex timed events remain available to playback rendering.
4. Verify SRT indexing and playback do not regress.
5. Add large-file performance regression tests or repeatable manual profiling
   scripts.

## Acceptance Criteria

- Selecting an ASS search result updates UI selection immediately even for large
  subtitle files.
- Video open, seek, pause, play, and fullscreen controls do not wait for ASS
  parsing or rendering.
- Search results show readable dialogue or lyric text, not vector path commands.
- Playback rendering uses source ASS timing and does not discard timed effect
  events because they are complex.
- Complex ASS files with many `Effect=fx`, `\p`, and `\clip` events can play
  without blocking the main UI thread.
- The renderer can show complex effects when the dedicated renderer is enabled.
- Missing or failed ASS rendering does not prevent video playback.
- The distinction between search projection and render timeline is covered by
  tests and documentation.

## Risks

- A dedicated ASS renderer may add native dependencies that affect packaging,
  signing, and notarization.
- Font behavior may differ from users' reference players unless font discovery
  is handled carefully.
- Rendering every complex ASS effect can be CPU or GPU intensive and may need
  frame throttling or cache policy.
- The render timeline cache must be invalidated reliably when source subtitle
  files change.
- Maintaining both ASS Lite fallback and source-faithful renderer paths can
  increase complexity unless ownership boundaries stay explicit.

## Decision

Accepted.

CueSeeker will move ASS playback from the current ASS Lite text overlay toward a
source-faithful, non-blocking ASS rendering pipeline. Search projection remains
optimized for readable text search. Playback rendering remains source-file-owned
and must preserve timed ASS events. Video playback and UI selection must not be
blocked by ASS parsing or rendering.
