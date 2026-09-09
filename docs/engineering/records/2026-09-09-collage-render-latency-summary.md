# Collage render latency: the three measurements side by side

Human-owned documents:

- `docs/human/requirements/20260909-Feature-Collage Render Latency.md`

Step records:

- `docs/engineering/records/2026-09-09-collage-render-latency-step-2.md`
- `docs/engineering/records/2026-09-09-collage-render-latency-step-3.md`

## Sample and method

`It's MyGO!!!!!` episode 05: a 638 MB 1080p HEVC 10-bit source with a 12 363 KB subtitle carrying 44 269 dialogue lines. The library's large subtitles are the normal case, not an edge case, so this title rather than a small-subtitle one defines the measurement.

Two instruments, both run at every one of the three points:

- Render path, release build, calling the collage render and compose entry points directly with one selected cue — the first-image case. Four runs; the first is reported separately because it pays one-time warm-up.
- Real application, Debug build, driven by the Debug E2E controller: open the episode from Library, Enter, then `P`. Timed from the keypress to the first capture showing the preview, by continuous capture at about 65 ms resolution. Three runs.

External USB volume, page cache warm. Debug and release figures are not comparable with each other in absolute terms; each instrument is only compared against itself.

## Results

Render path:

| | baseline | after step 2 | after step 3 |
|---|---|---|---|
| first run | 3.720s | 1.113s | **0.713s** |
| steady median | 3.414s | 0.663s | **0.216s** |
| grab the frame | 0.570s | 0.549s | 0.111s |
| get it back into a `CGImage` | 0.054s | 0.054s | 0.003s |
| read and validate the whole `.ass` | 0.312s | 0.014s | 0.014s |
| byte scan of the whole script | 0.361s | 0.004s | 0.004s |
| intermediate | 8 567 KB file, 16 bit/channel | same | 6 075 KB through a pipe, no file |

Real application, first image after `P`:

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| baseline | 3.712s | 3.725s | 3.726s |
| after step 2 | 1.236s | 1.321s | 1.359s |
| after step 3 | 0.613s | 0.639s | 0.736s |

## Conclusion

The first image went from about 3.72 seconds to about 0.65 seconds in the real application, a factor of roughly 5.7. Every additional checkbox tick pays the same reduced cost, since both fixed costs were per-group.

The split between the two steps matches what the baseline attribution predicted. Scanning the script by byte removed 2.4 of the 3.7 seconds, and it was the larger of the two by a wide margin — the opposite of the order the first analysis proposed, which had assumed frame grabbing was the main cost. Reading the frame uncompressed removed a further 0.6 seconds.

What remains at 0.216 seconds is mostly the frame grab at 0.111 seconds, of which decoding is the bulk. Removing the helper process entirely was considered and rejected: the in-process frame source available today returns the nearest keyframe, measured up to 2.5 seconds away from the requested instant on this title, and Collage must show the frame at the group's intersection midpoint. Trading a correct frame for roughly 70 ms is not a trade worth making.

Behaviour is unchanged apart from one recorded difference: after step 2 the collage was byte-identical to the pre-change build; after step 3 it differs by at most 4 of 255 in a single channel, from converting 10-bit to 8-bit once instead of through a 16-bit intermediate. The step 3 record carries the detail.
