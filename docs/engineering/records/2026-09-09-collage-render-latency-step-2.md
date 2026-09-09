# Collage stops re-reading the whole subtitle as strings

Human-owned documents:

- `docs/human/requirements/20260909-Feature-Collage Render Latency.md`

## Why

Entering Collage on an episode whose subtitle is around 12 MB took about 3.5 seconds before the first image appeared, and every additional tick of a checkbox paid the same cost again.

The cause was not rendering. Two separate places walked the entire script line by line and, for every line, allocated a trimmed copy and a full Unicode lowercased copy just to find out whether the line began with `[`, `Format:` or `Dialogue:`. Selecting the events for one group did it once per group, and the shared subtitle decoder did it a second time to confirm the file has an `[Events]` section. On a 44 269-line script that was 2.5 seconds and 0.3 seconds respectively — together roughly four fifths of the wait — while the actual frame grab and libass render accounted for 0.6 seconds.

Deciding what a line is only needs its first few bytes, so the fix reads bytes and never builds a string per line.

## What changed

A single byte-level scanner now walks the script and reports each line as a section header, an event format line, a dialogue line with its index, or anything else. Both callers use it and keep their own logic.

- `ASSScriptScanner` is new. It splits lines on `LF`, `CR` and `CRLF`, skips a leading byte order mark, trims ASCII whitespace by byte, and compares the leading keyword with ASCII case folding.
- Lines whose trimmed content starts with a non-ASCII byte, and lines that start with `[` but end with a non-ASCII byte, fall back to the original string handling. Those are the only shapes where Unicode whitespace could hide a keyword or a closing bracket. Dialogue text never reaches that path — an early version tested the last byte unconditionally, which sent every Chinese and Japanese line down the slow path and saved nothing.
- `SubtitleTextDecoder` uses the scanner for its ASS structure check, and makes the decoded string contiguous before handing it out so a caller's byte scan does not re-materialize the buffer. That is free on the UTF-8 path; it guards the legacy-encoding path, which comes back bridged.
- `SubtitleScreenshotExporter` builds the selected-events script by appending the bytes of the lines it keeps instead of normalizing the whole file, splitting it into strings and joining them back.

The two remaining copies of this line walk, in `ASSRenderSegmenter` and `ASSParser`, sit on the indexing path and are outside this requirement. They are left alone.

Files:

- `apps/macos-native/Sources/CueSeekerCore/ASSScriptScanner.swift`
- `apps/macos-native/Sources/CueSeekerCore/SubtitleTextDecoder.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`

## Verification

Sample: `It's MyGO!!!!!` episode 05, subtitle 12 363 KB with 44 269 dialogue lines, one selected cue, frame at 82 620 ms. External USB volume, page cache warm.

Render path, release build, driven through `renderCollageGroups` and `composeCollage` directly:

| | before | after |
|---|---|---|
| first run | 3.720s | 1.113s |
| steady median | 3.414s | 0.663s |
| grab frame and write the intermediate file | 0.570s | 0.549s |
| read it back and actually decode it | 0.054s | 0.054s |
| read and validate the whole `.ass` | 0.312s | 0.014s |
| byte scan of the whole script | 0.361s | 0.004s |

The intermediate frame file is unchanged at 8 567 KB and 16 bits per channel; that is step 3's subject.

Real application, Debug build, Library to the episode, Enter, then `P`, timed by continuous capture at about 65 ms resolution: 3.712 / 3.725 / 3.726 s before, 1.236 / 1.321 / 1.359 s after.

Equivalence: the composed collage was written to PNG from a build of the pre-change tree and from the changed tree with identical inputs. Both files are `7c5e4997de66a80e22f704a69ab3b22ed8bfdbf9dbaa1b70dde4c4b3b66803d6`.

`swift test`: 14 failing tests after the change against 15 before, compared by test name on the same machine with the debug application shut down. Nothing new fails; the difference is one flaky refresh-scope case that passed this time. The pre-existing failures are the families earlier records already list — native playback timeline and audio, cue group refresh scope, library folder removal and Debug E2E window geometry.

## Known limits

The structure check no longer treats `U+000B`, `U+000C`, `U+0085`, `U+2028` and `U+2029` as line separators; the old string form did, because `Character.isNewline` covers them. A script that separated its `[Events]` header from the rest with one of those would now fail validation. libass and the project's own ASS parser do not accept those as line breaks either, so the narrowing is deliberate rather than an oversight. The selection path is unaffected: it only ever split on `LF` and `CR`.

The contiguity guard on the legacy-encoding path is reasoned, not measured. No legacy-encoded sample of comparable size was on hand.

The benchmark harness is a throwaway built outside the repository: the package is copied to a scratch directory and the existing `PlaybackSyncProbe` entry point is replaced with the measurement program. Nothing in the repository measures this path, so the numbers above are not reproducible from a clean checkout without rebuilding that harness.

The real-application figures come from a Debug build and are not comparable with the release render-path figures in absolute terms; only the before and after pair is.
