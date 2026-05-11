# CueSeeker Shared Core Fixtures

These fixtures capture the current macOS implementation as the behavioral fact
standard for the first shared-core migration slice.

The fixtures are intentionally app-shell independent. Swift tests and Rust
shared-core tests should read the same input files and expected outputs.

Current coverage:

- Subtitle-to-video matching by same-directory basename.
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
