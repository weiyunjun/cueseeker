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
- Enable future time-windowed ASS preparation so large source files can load the
  selected cue window and nearby deterministic cue windows before falling back
  to full-file preparation.
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

The database cue timings are derived from the same source ASS events used for
rendering. For a selected ASS cue, the selected cue time and the next nearby cue
times can therefore be determined from indexed cue-group timing. The source
`.ass` file is still required to retrieve the exact render payload for those
times, including styles, override tags, vector drawing data, `Effect` fields,
and other formatting or visual-effect details.

This timing relationship allows a future segmented preparation path: load or
parse the source ASS data for the selected time window and nearby deterministic
windows first, then expand or fall back to full-file preparation only when the
renderer, cache state, or source format requires it.

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

ADR-0009 selects a dedicated source-faithful ASS renderer path with `libass` as
the preferred renderer dependency to evaluate and integrate first. This replaces
any plan that treats ASS Lite as the solution for complex ASS rendering. ASS
Lite remains a simple readable-text fallback and diagnostic comparison path.

The dependency decision must account for:

- Packaging and notarization.
- Font discovery and font fallback.
- Embedded or same-directory fonts.
- Renderer threading and cache behavior.
- Pixel format and alpha compositing over the native video surface.
- Behavior on both Playback Inspector and Theater Mode fullscreen surfaces.

ASS Lite remains an interim fallback for simple text-only cases and for
regression isolation.

### Playback Renderer Optimization Direction

The source-faithful renderer should preserve the sparse shape of `libass`
output instead of treating every subtitle update as a full-video-frame image.
The current isolated renderer probe may produce full RGBA frames because that
is convenient for PNG validation, but production playback should not assume
that full-frame bitmap output is the final architecture.

The optimization direction is:

```text
libass ASS_Image list
Process actual subtitle images or dirty rectangles only
Reuse subtitle buffers or upload subtitle output to a texture
Update renderer output only when libass reports a visual change or the subtitle
event timeline requires it
Reuse the previous subtitle surface while video frames continue to advance
```

Implementation notes:

- `libass` returns an `ASS_Image` linked list from `ass_render_frame`. Each
  image already carries bitmap, size, destination position, color, and alpha
  information for the visible subtitle output. The playback path should prefer
  this sparse image list over immediately expanding it into a full
  `videoWidth * videoHeight * 4` RGBA buffer.
- Dirty-rectangle rendering should bound CPU work and memory to the actual
  subtitle area. A single dialogue line on a 1080p or 4K video should not force
  allocation and compositing of a transparent full-frame subtitle bitmap.
- Subtitle buffers should be reused across frames when the render dimensions
  remain compatible. Reuse should reduce large transient allocations, Swift
  `Data` copies, `CGImage` churn, autorelease pressure, and Core Animation
  backing-store growth.
- Texture-backed subtitle presentation is preferred for the production overlay
  if it proves practical. A texture or layer surface can be updated by region
  and composited over the video by the native graphics stack, avoiding repeated
  full-frame `CGImage` creation.
- `ass_render_frame` provides a change signal through its `detect_change`
  output. For static ASS dialogue, playback should keep presenting the previous
  subtitle surface when visual output has not changed. Animated ASS features
  such as karaoke, fades, moves, transforms, and dense effects may still update
  frequently, but they should not require full-frame allocation as the default
  cost model.
- Video frame refresh and subtitle surface refresh are separate lifecycles. The
  video may continue advancing while the subtitle overlay reuses the most recent
  valid surface until the subtitle renderer produces a changed one.

Memory optimization work should first focus on avoiding full-frame subtitle
bitmap expansion in the playback path before considering a change of ASS
semantic renderer. `libass` remains the selected renderer direction; the likely
optimization gap is how CueSeeker consumes and presents its output.

### Native Subtitle Engine Direction

CueSeeker may introduce a project-owned native subtitle engine alongside the
current `libass`-backed legacy renderer. The version name `legacy` refers to the
current `libass` sparse-image playback path. Native engine versions start at
`v0`; this version sequence is independent from Git commit versions.

This section intentionally documents only the first phase in detail. Later
phases are high-level placeholders and must be refined when work on each phase
actually begins.

#### Phase 1 Detailed Plan: `v0` Native Text Core

The first native engine version should focus on ordinary subtitle rendering, not
danmaku-specific behavior. Its goal is to establish a small, testable, native
pipeline that can render common ASS dialogue with lower memory overhead than a
full ASS renderer path.

The minimal pipeline is:

```text
ASS source file
Parse source sections into a native model
Select active events for the playback timestamp
Lay out styled text
Produce small subtitle surfaces sized to text bounds
Composite those surfaces over the displayed video rectangle
```

Input scope:

- `[Script Info]`, including `PlayResX` and `PlayResY` when present.
- `[V4+ Styles]` style rows and their active `Format:` mapping.
- `[Events]` dialogue rows and their active `Format:` mapping.
- Dialogue start time, end time, layer, style, margins, and text.

First-phase non-goals:

- ASS danmaku lane assignment or collision handling.
- `\move`, animation, karaoke, `\clip`, `\iclip`, vector drawing, rotation,
  complex transforms, and blur.
- Full VSFilter or `libass` visual compatibility.
- Replacing the legacy renderer for complex ASS files.

The parser should not render directly. It should produce a normalized model so
future renderers can share the same source interpretation:

```text
NativeASSDocument
NativeASSStyle
NativeASSEvent
NativeASSCue
```

The first native style model should preserve:

- Style name.
- Font name and font size.
- Primary text color.
- Outline color and basic outline width.
- Shadow color and basic shadow offset.
- Bold and italic flags.
- Alignment and margins.
- Event start, end, layer, source order, raw text, cleaned text, and `\N` line
  breaks.

First-phase rendering should support:

- Selecting active events by playback timestamp.
- Ordering simultaneous events by layer and source order.
- Handling `\N` line breaks.
- Stripping unsupported override tags instead of rendering tag text.
- Applying style font, size, color, basic outline, basic shadow, alignment, and
  margins.
- Mapping ASS script coordinates into the displayed video rectangle, not the
  whole black playback container.
- Producing one small subtitle surface per active cue or cue group, bounded by
  the text layout, instead of allocating a full-video-frame transparent bitmap.

First-phase cache behavior should stay conservative:

- Cache only current and recently used subtitle surfaces.
- Use a cache key based on text, style identity, and a coarse render scale.
- Clear native subtitle surfaces when the source file, video size, renderer
  mode, or relevant style state changes.
- Avoid complex LRU caches, glyph atlases, Metal texture atlases, or object
  pools until the basic native pipeline proves stable.

The first native engine version is acceptable only if:

- Common ASS dialogue appears correctly enough for subtitle-context review.
- Simple bilingual or multi-line subtitles remain readable.
- Playback, seek, subtitle visibility toggling, and fullscreen remain stable.
- Memory use is meaningfully lower than the legacy full-frame style of ASS
  presentation for ordinary subtitles.
- Unsupported complex ASS features fail by omission or fallback, not by showing
  raw override syntax as user-visible subtitle text.

#### Later Phases, High-Level Only

Phase 2: expand static ASS support. Candidate areas include more override tags,
more exact alignment and margin behavior, positioned signs such as `\pos`, and
multiple simultaneous active events.

Phase 3: optimize the native text renderer after `v0` is stable. Candidate
areas include better surface caching, layout caching, allocation reduction, and
object reuse.

Phase 4: define complex ASS routing. The app should decide which source files
or events stay on the native path, which degrade gracefully, and which continue
to use the legacy `libass` path.

Phase 5: add danmaku-specific optimization only after ordinary subtitle
rendering is stable. Danmaku work may include ASS danmaku classification, lane
assignment, density controls, batching, and GPU-oriented rendering, but those
details should be designed later.

### Failure Visibility During Development

Renderer failures should be explicit while the source-faithful path is being
developed. Silent fallback from the source-faithful renderer to ASS Lite must
not hide defects in dependency loading, font discovery, renderer preparation,
timestamp rendering, or overlay compositing.

Fallback may remain available as a deliberate diagnostic mode or simple ASS
path, but complex ASS rendering bugs should surface as source-faithful renderer
failures until they are fixed.

## Architecture

Expected components:

- `SearchProjectionStore`: the existing SQLite search database and FTS index.
- `ASSRenderTimeline`: source-derived render events preserving timing, layer,
  style, raw override tags, drawing data, and event order. The timeline may be
  prepared for the full source file or for a bounded playback time window.
- `ASSRenderCache`: an in-memory and optional persistent cache keyed by subtitle
  path, file size, modified time, renderer version, and time window when a
  partial timeline is cached.
- `ASSRenderCoordinator`: orchestrates async source loading, cache lookup,
  window selection, renderer preparation, cancellation, and current-time
  catch-up.
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

### Phase 0: ADR, Dependency, And Evidence

1. Record the source-faithful renderer decision in an ADR before renderer
   integration work begins.
2. Treat `libass` as the preferred first renderer dependency to evaluate.
3. Document dependency, packaging, signing, notarization, license, and font
   discovery implications before a build containing the renderer is treated as
   releasable.
4. Add fixtures or repeatable local validation samples for complex real-world
   ASS patterns:
   - `Effect=fx` events.
   - `\p1` vector drawing events.
   - `\clip(...)` text reveal events.
   - `\pos(...)` and `\move(...)` placement.
   - alpha, blur, border, fade, rotation, and transform overrides.
   - Repeated short-duration karaoke or visual-effect events.
   - Zero-duration or near-zero-duration events.
5. Add timing instrumentation around:
   - Search result click handling.
   - Video open and seek.
   - ASS source file read.
   - ASS parse or render preparation.
   - First subtitle frame presentation.
6. Define performance budgets:
   - Search row selection should be visible within one UI frame.
   - Video open or seek should not wait for ASS preparation.
   - Subtitle preparation may complete later and catch up.
7. Document failure exposure behavior for missing, unreadable, unsupported, or
   renderer-failed subtitle rendering. During source-faithful development,
   failures should be visible instead of silently hidden by ASS Lite fallback.

### Phase 1: Isolated Renderer Probe

1. Add a minimal `CASSRendering` native bridge or equivalent isolated target.
2. Build a renderer probe or test harness that accepts:
   - source `.ass` URL,
   - video frame size,
   - playback timestamp,
   - optional font directory inputs when needed.
3. Make the probe produce an RGBA bitmap, alpha bitmap, texture-compatible
   buffer, or equivalent renderer output.
4. Validate the probe before UI integration against complex ASS samples:
   - vector drawing must render as drawing, not text;
   - clipping must affect output;
   - special-position text must appear at source-specified coordinates;
   - fades, alpha, blur, border, rotation, and transforms must be represented
     by renderer output where the source uses them;
   - dense short-duration effects must not require main-thread rendering work.
5. Keep this phase out of the production playback UI until renderer output and
   dependency behavior are understood.

### Phase 2: Non-blocking Playback Contract

1. Split search result selection from playback startup:
   - Update `selectedSearchResult` immediately.
   - Open the Playback Inspector immediately.
   - Schedule playback work after the UI state update is committed.
2. Change playback startup so video open and seek do not synchronously call ASS
   parser or renderer preparation.
3. Introduce an async source-faithful subtitle preparation task:
   - Cancel stale tasks when another result is selected.
   - Reuse prepared subtitle state for the same file.
   - Attach output only if the selected result is still current.
4. Keep playback running when subtitle preparation fails, while surfacing the
   renderer failure explicitly.
5. Preserve SRT behavior and subtitle visibility controls.

### Phase 3: Render Coordinator, Timeline, And Cache

1. Introduce a real `ASSRenderCoordinator` for the source-faithful renderer.
   This coordinator must not be a wrapper around ASS Lite.
2. The coordinator owns:
   - source file identity,
   - renderer initialization,
   - preparation cancellation,
   - cache lookup and invalidation,
   - renderer readiness and failure state,
   - current-time catch-up.
3. Replace playback-only all-events text parsing with source renderer state or
   source render timeline data that preserves raw timed events.
4. Build an active-time index so the renderer can query events by current time
   without scanning and sorting every dialogue on every frame.
5. Use database cue timing to prioritize the selected time window and prefetch
   neighboring windows.
6. Add a segmented preparation path that uses indexed cue-group timing to choose
   the selected cue window and nearby deterministic windows, while retrieving
   the exact render payload from the source `.ass` file.
7. Cache parsed timelines by source file identity and, for partial timelines, by
   the prepared time window.
8. Keep search projection and render timeline separate in code and tests.

### Phase 4: Source-faithful Overlay Integration

1. Add a `SubtitleOverlayHost` capable of displaying renderer bitmap, texture,
   layer, or equivalent alpha output.
2. Attach renderer output to the existing playback render container.
3. Drive subtitle frames from the native playback clock with sufficient cadence
   for short-duration effects.
4. Keep Theater Mode fullscreen and Playback Inspector using the same overlay
   host.
5. Ensure subtitle visibility toggles renderer output without stopping video.
6. Handle renderer readiness, failure, and catch-up states without blocking
   playback controls.

### Phase 5: Search And Playback Regression Hardening

1. Verify search results still return real dialogue and lyric text.
2. Verify complex ASS visual-effect events are not exposed as meaningless
   search text.
3. Verify complex timed events remain available to playback rendering.
4. Verify SRT indexing and playback do not regress.
5. Add large-file performance regression tests or repeatable manual profiling
   scripts.
6. Verify ASS Lite remains limited to simple text fallback behavior and is not
   used to mask source-faithful renderer defects.

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
- Segmented loading must not lose source events whose exact render behavior
  extends beyond the selected cue's simple timing window.
- Maintaining both ASS Lite fallback and source-faithful renderer paths can
  increase complexity unless ownership boundaries stay explicit.

## Decision

Accepted.

CueSeeker will move ASS playback from the current ASS Lite text overlay toward a
source-faithful, non-blocking ASS rendering pipeline. Search projection remains
optimized for readable text search. Playback rendering remains source-file-owned
and must preserve timed ASS events. Video playback and UI selection must not be
blocked by ASS parsing or rendering.
