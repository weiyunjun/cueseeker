# CueSeeker Shared Core Fixtures

These fixtures capture the current macOS implementation as the behavioral fact
standard for the first shared-core migration slice.

The fixtures are intentionally app-shell independent. Swift tests and Rust
shared-core tests should read the same input files and expected outputs.

Current coverage:

- Subtitle-to-video matching by same-directory basename.
- Recursive subtitle folder scanning.
- Minimal indexing projection from scanned subtitles to matched videos and cue
  groups.
- Search query matching over indexed cue groups, including Latin prefix, ordered
  Latin tokens, CJK substring, kana substring, and line-level validation.
- Library presentation snapshot rows from indexed video metadata, including
  duplicate video folding, natural ordering, display titles, file extensions,
  duration propagation, and subtitle format propagation.
- Shiori upsert/remove semantics, including cue identity, duplicate metadata
  updates, `created_at` preservation, timestamp clamping, sorting, and cue-line
  derivation.
- Playback request/intent inputs, including local file validation, missing-file
  rejection, start-time clamping, and ASS subtitle source metadata.
- Simple language-suffix subtitle matching.
- SRT parsing, malformed block skipping, missing sequence numbers, multi-line
  text, and CJK text.
- ASS parsing, `Dialogue` filtering, exact-time grouping, near-time non-grouping,
  field-order handling, searchable text cleaning, and display ordering.

Expected cue output files use tab-separated rows:

```text
group sequence start_time end_time start_ms end_ms search_content
line event_index format style layer start_time end_time start_ms end_ms content display_x display_y display_order
```

Empty fields represent `nil`/`None`. Text uses `\n`, `\t`, and `\\` escaping.
Expected path output files use one relative path per row. `NONE` in
video-matching cases represents an expected no-match result. `NONE` in Library
fixture duration input represents an expected missing duration. `NONE` in
Playback fixture input represents an absent optional URL, time window, render
cache, or subtitle source.
