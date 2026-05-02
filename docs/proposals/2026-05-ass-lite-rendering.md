# ASS Lite Source Subtitle Rendering

Status: Accepted

Follow-up direction:

- This proposal records the accepted and implemented interim ASS Lite rendering
  step.
- Complex ASS playback now follows
  `docs/proposals/2026-05-source-faithful-ass-rendering-pipeline.md`.
- ASS Lite remains useful as a simple text fallback and regression isolation
  layer, but it is not the endpoint for source-faithful ASS playback rendering.

## Background

CueSeeker already supports `.ass` subtitle scanning, indexing, grouped search
results, and click-to-playback behavior. Source ASS subtitle rendering remains
deferred in the accepted ASS search proposal.

The product is a language-learning and subtitle-context review tool, not a
general-purpose immersive media player. ASS rendering should therefore improve
learning usefulness and source-context accuracy without turning the native app
into a full VSFilter-compatible subtitle renderer.

The current direction is to implement a project-owned ASS Lite renderer instead
of adopting an external ASS rendering library in the first rendering step.

## Goals

- Render source `.ass` subtitle files during playback for ASS search results.
- Keep playback source-file-owned: load the source `.ass` file associated with
  the selected search result.
- Avoid treating database cue-group projections as the playback subtitle
  renderer.
- Avoid adding an external ASS rendering dependency in the first implementation.
- Support the common static subtitle cases needed for language learning:
  dialogue text, bilingual lines, ASS source styles, basic placement, and
  subtitle visibility toggling.
- Keep the implementation incremental and reviewable.

## Non-goals

- Full VSFilter or libass compatibility.
- External ASS rendering libraries in the first implementation.
- Embedded subtitle stream decoding.
- MKV font attachment extraction.
- Advanced ASS animation support in the first implementation.
- Full VSFilter or libass-compatible restoration of every ASS visual behavior
  in the first implementation.
- Turning CueSeeker into a full media player.

## Current Implementation Scope

The first ASS Lite rendering step should support:

- Loading the source `.ass` file from the selected search result.
- Parsing the ASS sections needed for rendering:
  - `[Script Info]`
  - `[V4+ Styles]`
  - `[V4 Styles]`
  - `[Events]`
- Parsing `PlayResX` and `PlayResY` when present.
- Parsing `Style:` rows for commonly used style fields:
  - `Name`
  - `Fontname`
  - `Fontsize`
  - `PrimaryColour`
  - `SecondaryColour`
  - `OutlineColour`
  - `BackColour`
  - `Bold`
  - `Italic`
  - `Underline`
  - `StrikeOut`
  - `ScaleX`
  - `ScaleY`
  - `Spacing`
  - `Angle`
  - `BorderStyle`
  - `Alignment`
  - `MarginL`
  - `MarginR`
  - `MarginV`
  - `Outline`
  - `Shadow`
  - `Encoding`
  These fields are the source visual style for the first implementation where
  the native renderer supports them.
- Parsing `Dialogue:` rows according to the active `[Events] Format:` mapping.
- Showing active dialogue events based on playback time.
- Supporting ASS `\N` line breaks.
- Supporting basic override handling:
  - Strip unsupported override tags.
  - Support inline alignment overrides from `\an1` through `\an9`.
- Supporting basic static placement from style alignment and margins.
- Rendering text from the selected ASS style's font, font size, primary color,
  outline color, background or shadow color, bold, italic, underline,
  strikeout, scale, spacing, border style, outline, and shadow values where
  supported.
- Falling back to platform fonts only when the named ASS font is unavailable,
  while preserving the rest of the ASS style semantics.
- Avoiding AppKit attributed text stroke attributes as a direct substitute for
  ASS outline rendering.
- Rendering multiple active dialogue events at the same timestamp.
- Ordering simultaneous events by layer and source order.
- Mapping ASS script coordinates into the actual displayed video rectangle, not
  the full black playback container.
- Preserving the current subtitle visibility button and `C` keyboard shortcut.
- Reusing the existing Playback Inspector and Theater Mode fullscreen surfaces.

## Deferred Future Support

Future ASS rendering iterations may add:

- `\pos(x,y)` placement.
- `\move(...)` placement with animation.
- `\fad(...)` and `\fade(...)` timing effects.
- Karaoke tags such as `\k`, `\K`, `\kf`, and `\ko`.
- Rich inline style overrides for font size, color, outline, shadow, bold,
  italic, and spacing.
- More exact ASS style restoration for source fonts, transforms, border style,
  boxed backgrounds, and renderer-specific edge cases.
- Rotation, transform, scaling, blur, border, and alpha overrides.
- `\clip` and `\iclip`.
- ASS vector drawing events.
- Better text shaping and font fallback behavior.
- Optional user-configured subtitle font directories.
- Optional same-directory font discovery when explicitly documented.
- Embedded font extraction from media containers, if later required.
- Embedded subtitle stream rendering.
- More accurate behavior for anamorphic video and pixel aspect ratio edge cases.
- Dedicated rendering performance instrumentation.

## User Flow

The first ASS Lite playback flow is:

```text
Open Search
Search indexed subtitle text
Click an ASS search result
Playback Inspector opens or updates
Matched video opens or seeks to the cue group start timestamp
Source .ass file loads into the ASS Lite renderer
The renderer shows active dialogue events over the video surface
The subtitle button or C key shows and hides the subtitle overlay
The same subtitle overlay follows Theater Mode fullscreen
```

## UI/UX Impact

Playback remains focused on subtitle context review.

Expected behavior:

- ASS subtitles appear over the video surface when the selected result comes
  from an `.ass` file.
- SRT playback may continue using the existing app-owned text overlay.
- The subtitle visibility control applies to both SRT overlay text and ASS Lite
  rendering.
- If ASS parsing or rendering fails, playback should continue and the UI should
  surface a concise subtitle-unavailable message or diagnostic state.
- Fullscreen must reuse the same render container so ASS subtitles move with the
  video experience.

## Data Model Impact

No database schema change is required for the first ASS Lite rendering step.

Rules:

- The database remains a searchable projection and local index.
- The source `.ass` file remains the playback rendering source.
- Search result cue lines remain useful for result preview, not for reconstructing
  full ASS playback visuals.
- The playback request should carry enough subtitle-source information for the
  player to load the source subtitle file.

## Architecture Impact

The first implementation should introduce a dedicated rendering module rather
than mixing playback rendering into search indexing code.

Expected components:

- A source ASS parser for playback rendering.
- A normalized ASS Lite render model.
- A native overlay view or layer hosted by the playback render container.
- A bridge from playback time updates to subtitle overlay updates.
- A visibility state shared with existing playback controls.

The renderer should be independent from the SQLite search layer. It may share
small parsing utilities only if they are deliberately extracted and tested.

## Technical Risk

Risks:

- ASS is large enough that implicit compatibility goals can expand quickly.
- Incorrect video-rectangle mapping can make otherwise correct subtitles appear
  visibly misplaced.
- Complex ASS files may contain animation, clipping, vector drawing, or font
  assumptions that the first renderer intentionally ignores.
- AppKit, Core Text, SwiftUI, or CALayer text rendering may differ from common
  ASS renderers.
- Mapping large ASS outline values directly into platform attributed text can
  produce hollow or decorative CJK glyphs instead of normal readable subtitles.
- The current playback time delegate updates at a coarse cadence. Static
  dialogue display may be acceptable, but future animation support will need a
  higher-frequency rendering clock.
- Font fallback behavior may differ across machines.

Mitigations:

- Treat ASS Lite as a documented subset.
- Add fixtures that capture both supported and intentionally unsupported cases.
- Keep unsupported tags visible in test coverage as graceful degradation cases.
- Implement video-rectangle mapping before fine-tuning style fidelity.
- Keep first-pass visual styling source-owned, but implement ASS outline with
  filled multi-pass offset drawing instead of platform stroke attributes.
- Add future support only after each tag or behavior has a clear acceptance
  rule.

## Detailed Task Flow For Current Scope

1. Documentation approval
   - Review this proposal.
   - Decide whether ASS Lite is the accepted first rendering strategy.
   - If accepted, merge stable conclusions into product, engineering, and
     testing documents before implementation depends on them.

2. Rendering model design
   - Define `ASSLiteScript`, `ASSLiteStyle`, `ASSLiteDialogue`, and
     `ASSLiteOverride` models.
   - Define `ASSLiteStyle` as the source visual style selected by each
     `Dialogue` row.
   - Define unsupported-tag behavior as explicit graceful degradation.
   - Define render-time inputs: subtitle file URL, current playback time, video
     display rectangle, visibility state, and backing scale.

3. Playback ASS parser
   - Parse `[Script Info]` for `PlayResX` and `PlayResY`.
   - Parse `[V4+ Styles]` and `[V4 Styles]` `Format:` and `Style:` rows.
   - Parse `[Events]` `Format:` and `Dialogue:` rows.
   - Convert timecodes to milliseconds.
   - Preserve source order and layer.
   - Normalize text line breaks.
   - Extract supported inline alignment overrides.
   - Strip unsupported override tags without dropping visible text.

4. Unit tests for parser and model
   - Add fixtures for basic dialogue, bilingual simultaneous dialogue, styles,
     margins, `\N`, inline `\an` alignment, and unsupported override stripping.
   - Add explicit future-support fixtures for tags that should currently degrade
     gracefully.

5. Subtitle source plumbing
   - Extend playback request data so ASS results pass subtitle source URL and
     format to playback.
   - Keep SRT behavior unchanged unless refactoring is required to share the
     visibility control.

6. Overlay host integration
   - Add an ASS Lite overlay view or layer owned by the playback render
     container.
   - Ensure the overlay moves with the singleton render container in Playback
     Inspector and Theater Mode fullscreen.
   - Ensure the overlay does not intercept playback-surface clicks or playback
     controls.

7. Video rectangle mapping
   - Determine the displayed video rectangle inside the render container.
   - Map ASS script coordinates from `PlayResX` and `PlayResY` into that
     rectangle.
   - Handle aspect-fit letterboxing consistently for inspector and fullscreen.

8. Text rendering
   - Render active dialogue events using AppKit, Core Text, SwiftUI, or CALayer
     primitives selected during implementation.
   - Apply parsed ASS style for font, size, fill color, outline color, shadow
     color, bold, italic, underline, strikeout, scale, spacing, border style,
     outline, shadow, alignment, and margins where supported.
   - Draw outline with small offset fill passes around the text, then draw
     filled text normally; do not use platform text stroke attributes for the
     first implementation.
   - Stack simultaneous events by layer and source order.

9. Playback clock integration
   - Update active ASS dialogue when playback time changes.
   - Update immediately after seek and after selecting another result.
   - If coarse time updates produce visible lag, add a lightweight renderer
     timer only while ASS subtitles are visible.

10. Visibility and lifecycle
    - Connect the existing subtitle button and `C` shortcut to the ASS Lite
      overlay visibility.
    - Clear the ASS Lite overlay when playback stops, a non-ASS result is
      selected, or the subtitle file cannot be loaded.
    - Keep playback running if subtitle rendering fails.

11. Manual verification
    - Verify basic ASS subtitles appear near the expected position.
    - Verify bilingual simultaneous dialogue displays together.
    - Verify same-video result selection seeks and refreshes subtitles.
    - Verify switching to SRT keeps existing SRT subtitle behavior.
    - Verify subtitle visibility toggling works from controls and keyboard.
    - Verify Theater Mode fullscreen shows the same ASS overlay.

12. Regression verification
    - Run the Swift test suite.
    - Verify existing SRT search and playback behavior.
    - Verify existing ASS search result grouping and click-to-playback behavior.
    - Record known ASS Lite gaps in the proposal or follow-up documentation.

## Acceptance Criteria

- ASS search results load their source `.ass` file for playback rendering.
- Basic ASS dialogue text appears over the video surface at the active playback
  time.
- ASS source style, alignment, margins, and `\N` line breaks are reflected
  closely enough for subtitle context review.
- CJK subtitles render as normal filled readable subtitle text, not hollow
  stroke-heavy glyphs.
- Multiple active dialogue events can appear together.
- Unsupported override tags do not break rendering of visible text.
- The overlay follows both Playback Inspector and Theater Mode fullscreen.
- The subtitle visibility control shows and hides ASS Lite subtitles.
- Missing or unreadable subtitle files do not prevent video playback.
- SRT playback behavior does not regress.
- Automated parser/model tests cover the supported subset.
- Known unsupported ASS features are explicitly documented.

## Decision

Accepted.

The first step is a project-owned ASS Lite renderer with a documented subset of
ASS behavior, source-style-driven visual rendering, and no external ASS
rendering dependency. Future compatibility improvements should be added
incrementally only after each feature has clear product value and acceptance
criteria.
