# The grabbed frame stops being compressed to a file and back

Human-owned documents:

- `docs/human/requirements/20260909-Feature-Collage Render Latency.md`

## Why

After the subtitle scan stopped dominating, grabbing one frame was what was left: 0.55 seconds of the 0.66 second render.

Almost none of that was decoding. The frame was written out as a PNG into a temporary directory and read back through ImageIO, and because these sources are 10-bit, the PNG carried 16 bits per channel — a 8.4 MB file per frame. The compositor draws into an 8-bit context, so that extra precision was created and then discarded. Measured on the same frame with the same binary, producing the file cost 0.73 seconds against 0.12 seconds for the same decode written uncompressed.

## What changed

The frame now arrives as uncompressed 8-bit BMP on the helper's standard output and is decoded straight from memory. BMP rather than raw pixels because it carries its own dimensions, so nothing has to reason about coded size, sample aspect or rotation — the helper still decides what the displayed frame is.

- `videoFrame` asks for `bgr24` through `image2pipe` and decodes the returned bytes with `CGImageSourceCreateWithData`.
- `runProcessCapturingStandardOutput` is new. It drains the output pipe before waiting on the child, because a frame is far larger than the pipe buffer and the previous helper's wait-then-read order would deadlock on it.
- `loadImage` now takes bytes and a description for its error instead of a file URL.

Three temporary directories, the separate `exportVideoFrame` step and the old `runProcess` had no remaining purpose once the file went away, and are gone with it.

The same frame grab serves single and batch subtitle screenshot export, so those get the same change. Their written output is still produced by the existing PNG writer and is unchanged in format.

Files:

- `apps/macos-native/Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`

## Verification

Same sample as the previous step: `It's MyGO!!!!!` episode 05, one selected cue, frame at 82 620 ms, release build, driven through `renderCollageGroups` and `composeCollage`.

| | before both steps | after step 2 | after step 3 |
|---|---|---|---|
| first run | 3.720s | 1.113s | 0.713s |
| steady median | 3.414s | 0.663s | 0.216s |
| grab the frame | 0.570s | 0.549s | 0.111s |
| get it back into a `CGImage` | 0.054s | 0.054s | 0.003s |
| read and validate the whole `.ass` | 0.312s | 0.014s | 0.014s |
| intermediate | 8 567 KB file, 16 bit/channel | same | 6 075 KB through a pipe, no file |

Real application, Debug build, Library to the episode, Enter, then `P`, timed by continuous capture at about 65 ms resolution: 3.712 / 3.725 / 3.726 s at the baseline, 1.236 / 1.321 / 1.359 s after step 2, 0.613 / 0.639 / 0.736 s after step 3.

Image comparison against the pre-change build, same inputs, 1920×1080: largest single-channel difference 4 of 255, mean difference 0.84, and 63% of channels differ by at least one level. The collage is no longer byte-identical, unlike step 2. The frame now converts 10-bit to 8-bit once inside the helper instead of passing through a 16-bit intermediate that the 8-bit compositing context rounded away, so the two roundings do not land identically. The difference is a rounding-level one and is below what the eye resolves, but it is a real difference and is recorded as such rather than claimed as identical.

`swift test`: 13 failing tests against 15 at the baseline, compared by test name. Nothing new fails.

## Known limits

The pixel difference above was measured on one frame of one title. No sweep across sources, bit depths or pixel formats was run, so the 4-of-255 figure is an observation, not a bound.

8-bit sources previously produced an 8-bit PNG already, so for those the change removes the compression round trip but not a precision step; they were not measured separately.

The benchmark harness remains a throwaway outside the repository, as the previous record notes. The real-application figures are from a Debug build and are only comparable with each other.
