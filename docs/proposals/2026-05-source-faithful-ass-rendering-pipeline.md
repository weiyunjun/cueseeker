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

The long-term direction is a project-owned native ASS rendering pipeline that
can render source ASS events into overlay surfaces synchronized to the native
playback clock.

ADR-0009 selects native `v0` as the first renderer phase and a project-owned
native ASS rendering pipeline as the default direction. This replaces any plan
that treats ASS Lite as the final solution for complex ASS rendering. ASS Lite
remains a simple readable-text fallback and diagnostic comparison path. The
existing `libass` path remains a long-term selectable renderer for comparison,
fallback, compatibility, and native-renderer reference output, while new native
design discussion defaults to the native renderer.

If a build includes a non-system legacy ASS renderer dependency, that decision
must account for:

- Packaging and notarization.
- Font discovery and font fallback.
- Embedded or same-directory fonts.
- Renderer threading and cache behavior.
- Pixel format and alpha compositing over the native video surface.
- Behavior on both Playback Inspector and Theater Mode fullscreen surfaces.

ASS Lite remains an interim fallback for simple text-only cases and for
regression isolation.

### Legacy Renderer Optimization Context

The current legacy `libass` path should preserve the sparse shape of `libass`
output instead of treating every subtitle update as a full-video-frame image.
This section is guidance for the retained legacy path, not the primary native
`v0` renderer plan. A diagnostic renderer probe may produce full RGBA frames
because that is convenient for PNG validation, but production playback should
not assume that full-frame bitmap output is the final architecture.

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

Legacy renderer memory optimization should focus on avoiding full-frame
subtitle bitmap expansion in the playback path. Native renderer work should
focus on the `v0` text core first and then expand ASS feature coverage in later
phases.

Verified legacy `libass` optimization directions:

- H4, playback overlay presentation through layer contents, is a validated
  `libass` optimization direction. The useful part is to move legacy ASS output
  presentation away from repeated AppKit draw-time image construction and toward
  a retained layer-backed subtitle output. This is a legacy `libass`
  presentation optimization, not evidence that AppKit text drawing can match ASS
  visual behavior.
- H3, cropped subtitle bitmap presentation, is a validated `libass`
  optimization direction. The useful part is to carry only the visible subtitle
  bitmap bounds through playback presentation instead of retaining a full-frame
  transparent subtitle image. Earlier measurements showed this direction can
  reduce simple ASS physical-footprint delta into the low tens of megabytes and
  keep complex ASS substantially below the previous full-frame style cost.
- H7, explicit clear, stop, and teardown recovery, is a partially validated
  `libass` optimization direction. The useful part is to reduce retained ASS
  presentation state after subtitle clearing or playback stop. The known risk is
  lifecycle correctness: teardown crash or leak behavior must be fixed before
  this direction is accepted as complete.
- Subtitle clock consolidation is a validated legacy `libass` stabilization
  direction. The useful part is to avoid driving ASS rendering from multiple
  asynchronous playback time sources. Playback should keep UI progress updates
  separate from subtitle render-clock updates, and the subtitle renderer should
  receive timing from one display-refresh-oriented source.

Non-validated or rejected legacy optimization directions should not be treated as
accepted just because they appear in the high-level optimization list above.
In particular, detect-change throttling, tick-frequency changes, generic buffer
reuse, and generic texture upload need fresh evidence in the current codebase
before they can be treated as useful. The committed optimization direction for
legacy `libass` should therefore start from H4, H3, and the lifecycle-safe subset
of H7.

Current legacy `libass` implementation state:

- H7 has a first lifecycle-safe implementation: the bridge exposes explicit
  idempotent renderer-session close behavior, and playback clears retained ASS
  presentation state when the subtitle source is removed, playback stops, or
  renderer state is reset.
- H4 has a first implementation: legacy ASS playback presentation uses retained
  layer contents instead of rebuilding subtitle images during AppKit draw calls.
- H3 has a first implementation: the bridge composites libass output into a
  cropped subtitle surface instead of carrying a full-video transparent subtitle
  bitmap through playback presentation.
- The cropped surface keeps libass top-origin coordinates and maps them into
  the playback layer coordinate space when presenting over the displayed video
  rectangle.
- Legacy ASS render timing is now driven from a single `CVDisplayLink`-based
  subtitle clock. Native playback time delegate updates still drive UI progress
  state, but they no longer directly trigger ASS overlay rendering.

Known remaining legacy `libass` limitations:

- Complex animated ASS such as `\move` combined with rotation, shearing, blur,
  and dense effects may still show some visible jitter. This is acceptable for
  the current Phase 1 native `v0` acceptance bar, but it should remain tracked
  for later native renderer timing and presentation work.
- The display-link subtitle clock reduces irregular timing caused by dual time
  sources, but it does not make ASS rendering frame-perfect with the native video
  presentation pipeline.
- The native ASS renderer may reuse the same high-level timing lesson: it should
  avoid multiple subtitle render-clock sources and should prefer a single
  display-refresh-oriented render coordinator when dynamic ASS features are
  implemented.

### Native Subtitle Engine Direction

CueSeeker will introduce a project-owned native subtitle engine alongside the
current selectable legacy renderer paths. The version name `legacy` refers to
non-native retained renderers such as the current `libass` sparse-image
playback path. Native engine versions start at `v0`; this version sequence is
independent from Git commit versions. The default product direction is native
rendering, with `libass` retained as a long-term selectable reference and
compatibility option.

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

Later phases are deliberately flexible because ASS compatibility is an
exploratory renderer project, not a fixed feature checklist. The detailed scope
of each phase must be decided when that phase starts, based on real subtitle
samples, renderer diagnostics, visual comparison results, and user review.

Phase 2: real-sample ASS coverage exploration. The user provides representative
real-world ASS samples. The AI adds or runs analysis scripts that identify the
ASS syntax, style fields, effects, timing patterns, and rendering features used
by those samples. Each discovered feature must then be translated into
human-readable behavior before implementation scope is accepted. Phase 2 may
iterate many times across different samples. Its goal is to decide and
implement as many known rendering behaviors as practical, rather than splitting
the work into a separate static phase and a later complex phase.

Phase 3: compromise and unsupported-behavior policy. After Phase 2 has exposed
features that native rendering cannot reproduce accurately enough, Phase 3
defines how to handle them. Candidate outcomes include approximate rendering,
explicit omission, diagnostic warnings, user-visible unsupported states, or
temporary legacy renderer routing. Phase 3 should avoid silent degradation that
makes renderer defects look correct.

Phase 4: performance, memory, and long-run stability. Only after the major
rendering behavior questions are understood should native ASS work focus on
cache policy, allocation reduction, renderer invalidation, subtitle visibility
toggle behavior, long-run playback memory, fullscreen behavior, and automated
benchmark coverage.

Danmaku-specific playback remains outside these native ASS subtitle phases
unless a later discussion explicitly folds it into the playback roadmap. If it
is added, it should be treated as a separate overlay domain from subtitles, with
its own track model, visibility control, lane assignment, density controls, and
high-throughput renderer. ASS files may still be classified as danmaku inputs
through syntax and timeline heuristics, but danmaku rendering should not force
the subtitle renderer to become a lane scheduler.

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

### Native Phase 0: Routing, Evidence, And Baseline

1. Keep ADR-0009 aligned with the native renderer direction.
2. Treat native mode as the default discussion and implementation path.
3. Keep current Settings-based renderer selection available during the
   transition.
4. Document dependency, packaging, signing, notarization, license, and font
   discovery implications before any build containing a non-system legacy
   renderer dependency is treated as releasable.
5. Keep timing instrumentation or repeatable observation points around:
   - Search result click handling.
   - Video open and seek.
   - ASS source file read.
   - Native ASS parse or render preparation.
   - First subtitle surface presentation.
6. Preserve the non-blocking contract:
   - Search row selection should be visible within one UI frame.
   - Video open or seek should not wait for ASS preparation.
   - Subtitle preparation may complete later and catch up.
7. Document failure exposure behavior for missing, unreadable, unsupported, or
   renderer-failed subtitle rendering. During native renderer development,
   failures should be visible instead of silently hidden by fallback behavior.

### Native Phase 1: `v0` Native Text Core

1. Implement the native source parser and normalized model:
   - `NativeASSDocument`
   - `NativeASSStyle`
   - `NativeASSEvent`
   - `NativeASSCue`
2. Parse `[Script Info]`, `[V4+ Styles]`, `[V4 Styles]`, and `[Events]` using
   each section's active `Format:` mapping.
3. Preserve the first-phase style and event fields listed in the native `v0`
   plan above.
4. Select active events by playback timestamp and order simultaneous events by
   layer and source order.
5. Apply ordinary dialogue styling, `\N` line breaks, alignment, margins, basic
   outline, and basic shadow.
6. Strip unsupported override tags instead of rendering tag syntax as visible
   text.
7. Produce small subtitle surfaces sized to text bounds and composite them over
   the displayed video rectangle.
8. Keep playback running when native subtitle rendering fails, while surfacing
   the renderer state explicitly.
9. Preserve SRT behavior and subtitle visibility controls.
10. Complete ordinary dialogue visual alignment before treating Phase 1 as
    complete.
11. Use user manual playback testing as the authority for visual acceptance.

#### Phase 1 Ordinary Dialogue Visual Alignment

This alignment step is part of Phase 1, not Phase 2. It exists because the
native `v0` text core can parse and draw ordinary dialogue while still producing
visibly different subtitle size or placement from reference players.

Goal:

- Make ordinary, static ASS dialogue look credible against `legacy libass` and
  reference players such as Movist Pro for subtitle-context review.

Required Phase 1 alignment scope:

- Respect `PlayResX` and `PlayResY` when mapping ASS script coordinates into the
  displayed video rectangle.
- Keep backing scale as a bitmap sharpness concern only; it must not change ASS
  script-coordinate font size.
- Apply source style `Fontsize`, `ScaleX`, `ScaleY`, margins, basic outline, and
  basic shadow consistently with the displayed video rectangle.
- Support dialogue-level leading static size overrides that affect ordinary
  subtitle size:
  - `\fs`
  - `\fscx`
  - `\fscy`
- Treat those leading overrides as cue-level style adjustments in Phase 1. Rich
  per-run style changes inside a dialogue line belong to Phase 2.
- Keep unsupported override tags stripped or omitted instead of showing raw ASS
  syntax.
- Preserve the non-blocking playback contract while native ASS source loading
  and subtitle surface rendering catch up asynchronously.

Phase 1 alignment non-goals:

- Full `libass`, VSFilter, or Movist Pro visual parity.
- Rich inline style runs where only part of a dialogue line changes size, font,
  color, or other style fields.
- Static sign positioning through `\pos`.
- Animation, karaoke, clipping, vector drawing, transforms, blur, or dense
  effects.
- Font attachment extraction or same-directory font discovery.

Phase 1 is complete only when ordinary dialogue sizing and placement are close
enough for manual subtitle-context review, and the known remaining visual gaps
are clearly deferred to Phase 2 or later.

#### Phase 1.1 Font Fallback Parity

Phase 1.1 is part of Phase 1 ordinary dialogue alignment. It exists because
native `v0` can parse the source style name and `Fontname` while still choosing
a different fallback face from the legacy comparison renderer when the requested
font is unavailable. That difference changes text metrics before any `Fontsize`
calibration can be trusted.

Goal:

- Make native ordinary dialogue use a documented, diagnosable font selection
  path that can be compared against the legacy `libass` path before further
  size or placement tuning.

Reference behavior to capture:

- The current legacy comparison path initializes `libass` with font extraction
  enabled, an optional configured fonts directory, CoreText/autodetected system
  font lookup on macOS, and default fallback family `Helvetica`.
- `libass` font selection is not a single fallback rule. It depends on the
  requested ASS family name, bold and italic attributes, available embedded or
  configured fonts, the active platform font provider, default fallback family,
  and glyph coverage fallback when a selected face lacks a glyph.
- Phase 1.1 must capture `libass` `fontselect` diagnostics for representative
  Phase 1 samples instead of inferring the selected face from the ASS style
  alone.

Implementation scope:

- Introduce a native font resolution layer for ordinary dialogue styles rather
  than resolving fonts inline inside text rendering.
- Preserve the source ASS font request, style name, bold and italic flags, and
  selected native font face in diagnostics.
- Match installed-font lookup by considering family names, display names,
  PostScript names, localized names where available, and bold or italic trait
  conversion.
- Match the configured legacy fallback family when the requested ASS font cannot
  be found. For the current legacy bridge this fallback family is `Helvetica`,
  not the platform default system font.
- Keep embedded `[Fonts]`, same-directory fonts, and media-container attachment
  fonts explicitly tracked. If they are not implemented in Phase 1.1, native
  diagnostics must report that they were unavailable rather than silently using a
  different fallback.
- Record per-glyph fallback as a separate behavior from whole-style fallback.
  Native `v0` may continue to rely on AppKit/CoreText glyph fallback for
  ordinary dialogue, but Phase 1.1 must not hide cases where `libass` selects a
  different fallback face for missing glyphs.

Acceptance checks:

- For a missing source font such as `方正准圆_GBK` in an ordinary dialogue style,
  native diagnostics identify that the requested face was unavailable and show
  the selected fallback face.
- For the same file, timestamp, and style, the native selected fallback family
  matches the legacy comparison path when both paths have access to the same font
  sources.
- The comparison harness records the source style, requested font, native
  resolved font, legacy `fontselect` line, and whether the difference is caused
  by unavailable embedded or external fonts.
- Phase 1 font-size or placement calibration must not be accepted until this
  font fallback evidence is available for the samples being compared.

### Native Phase 2: Real-Sample ASS Coverage Exploration

Phase 2 is a long, user-led technical exploration phase. It replaces the earlier
idea of first expanding only static ASS support and leaving complex behavior to
a later routing phase.

Phase 2 must remain flexible. The project cannot know the exact implementation
order before real subtitle samples are analyzed, and the phase may need many
analysis and implementation cycles before the user considers coverage good
enough.

Process:

1. The user provides one or more real ASS samples and the relevant video context
   when visual comparison is needed.
2. The AI runs or extends scripts that inspect the sample and output
   machine-readable feature inventories when practical.
3. The feature inventory identifies used syntax and behavior such as style
   fields, override tags, line-level tags, drawing mode, vector drawing
   commands, clip shapes, positioning, movement, transforms, fade, karaoke,
   scroll or banner effects, layer usage, short-duration event density, font
   requests, and embedded or external font expectations.
4. The AI translates each discovered feature into human-readable rendering
   behavior so the user can decide whether native rendering should attempt to
   reproduce it in the current cycle.
5. Implementation scope is decided from the sample evidence, not from a fixed
   static-versus-complex split.
6. The selected behavior is implemented and compared against `legacy libass`
   and reference-player output where useful.
7. The cycle repeats with new samples until the user decides the native renderer
   coverage is sufficient to move on.

Phase 2 goals:

- Discover what real subtitle files actually use before locking the renderer
  roadmap.
- Cover as many known rendering issues as practical within native ownership.
- Keep source ASS rendering failures visible during development.
- Build parser, model, renderer, diagnostics, and comparison tooling that can
  evolve as samples reveal new behavior.
- Avoid treating static and complex ASS as separate chronological phases when a
  real file may mix ordinary dialogue, signs, vector drawings, clipping,
  animation, and dense effects in the same timeline.

Phase 2 non-goals:

- Guarantee full `libass`, VSFilter, Movist Pro, or renderer-specific edge-case
  parity before the phase starts.
- Freeze a complete tag support matrix before samples have been analyzed.
- Treat automated analysis as a substitute for user review and visual
  acceptance.
- Optimize memory or renderer throughput before major visual behavior questions
  are understood, except where a performance issue blocks the exploration.

Expected Phase 2 deliverables:

- Sample analysis scripts or script extensions that can be reused across real
  ASS files.
- Machine-readable feature inventories for user-provided samples when
  practical.
- Human-readable explanations of discovered ASS behavior and its expected visual
  effect.
- Per-cycle scope decisions that say which features will be reproduced now,
  deferred, approximated, or left unsupported for later review.
- Parser, model, renderer, diagnostic, and comparison improvements driven by
  accepted sample evidence.
- Manual comparison notes against `legacy libass` and reference-player output
  for representative samples.

### Native Phase 3: Compromise And Unsupported-Behavior Policy

Phase 3 starts after Phase 2 has identified renderer behaviors that cannot be
reproduced precisely enough with the accepted native approach.

Goal:

- Decide how CueSeeker should handle known ASS behavior that native rendering
  cannot accurately reproduce or should not attempt to reproduce.

Candidate Phase 3 outcomes:

- Approximate rendering with documented visual limitations.
- Explicit omission for effects that are not useful enough for the product
  goal.
- User-visible unsupported-feature states during development.
- Diagnostic warnings that identify the unsupported source feature and event.
- Temporary legacy renderer routing for specific files, events, or user-selected
  compatibility mode.
- Policy for whether some dense effects, captions, or decorative typesetting
  are out of scope for the native default path.

Phase 3 must not silently hide complex ASS renderer failures behind fallback.
If behavior is approximated, omitted, or routed to a legacy renderer, that must
be an explicit policy decision based on Phase 2 evidence.

### Native Phase 4: Performance, Memory, And Long-Run Stability

Phase 4 starts after the major visual behavior and compromise-policy questions
are understood well enough to make performance work meaningful.

Goal:

- Make the accepted native ASS renderer behavior stable during real playback,
  seeking, subtitle visibility toggling, and fullscreen usage.

Candidate Phase 4 scope:

- Renderer cache policy and invalidation.
- Surface, layout, glyph, and raster cache behavior.
- Allocation reduction and object reuse where measurements support it.
- Long-run playback memory measurement.
- Subtitle hide/show and renderer teardown recovery.
- Theater Mode and Playback Inspector overlay stability.
- Automated benchmark and regression coverage for representative samples.
- JSON or JSONL diagnostics for performance and memory investigations.

Phase 4 evidence should follow the project memory-testing rules: authoritative
playback memory measurements must run outside the sandbox and should compare
relative RSS and physical-footprint deltas against no-subtitle baselines.

## Acceptance Criteria

- Selecting an ASS search result updates UI selection immediately even for large
  subtitle files.
- Video open, seek, pause, play, and fullscreen controls do not wait for ASS
  parsing or rendering.
- Native `v0` renders ordinary ASS dialogue well enough for subtitle-context
  review during user manual testing.
- Native `v0` ordinary dialogue size and placement are aligned closely enough
  with `legacy libass` and a reference player for common static dialogue.
- Leading `\fs`, `\fscx`, and `\fscy` overrides affect native `v0` ordinary
  dialogue sizing instead of being silently ignored.
- Simple bilingual or multi-line ASS subtitles remain readable.
- Unsupported override tags are omitted or stripped instead of appearing as raw
  subtitle text.
- Native subtitle output maps to the displayed video rectangle.
- Missing or failed native ASS rendering does not prevent video playback.
- Memory behavior for ordinary dialogue is directionally better than full-frame
  subtitle presentation.
- Search results show readable dialogue or lyric text, not vector path commands.
- The distinction between search projection, native render state, and legacy
  renderer paths is covered by documentation.

## Risks

- A fully native ASS renderer is a large implementation effort and may require
  several phases before complex files match user expectations.
- Font behavior may differ from users' reference players unless font discovery
  and fallback are handled carefully.
- Rendering every complex ASS effect can be CPU or GPU intensive and may need
  frame throttling or cache policy.
- The render timeline cache must be invalidated reliably when source subtitle
  files change.
- Segmented loading must not lose source events whose exact render behavior
  extends beyond the selected cue's simple timing window.
- Maintaining ASS Lite, native, and legacy renderer paths during the transition
  can increase complexity unless ownership boundaries stay explicit.

## Decision

Accepted.

CueSeeker will move ASS playback from the current ASS Lite text overlay and
legacy renderer paths toward a fully native, source-file-owned ASS rendering
pipeline. The first detailed implementation phase is native `v0` text rendering
for ordinary ASS dialogue. Search projection remains optimized for readable
text search. Video playback and UI selection must not be blocked by ASS parsing
or rendering.
