# ASS Subtitle Load Stall Navigation

## Human-Owned Source

- `docs/human/requirements/20260708-Bug-ASS Subtitle Load Stall During Search Result Navigation.md`

## Scope

Fix ASS subtitle renderer stalls when navigating playback results in the same
video. Search, Shiori, Library, playback history restore, quick-search result
opening, and context-result playback all route through the shared playback
source/request helpers and should initialize source-faithful ASS rendering at
the newly requested timestamp without being blocked by stale renderer work.

## Changes

- Added an explicit initial ASS render timestamp to `PlaybackSubtitleSource`.
- Filled subtitle source defaults from `PlaybackRequest.startMilliseconds` so
  callers that only pass a request start time still seed ASS rendering with the
  target timestamp.
- Added preparation-window clamp and containment helpers plus a short-lived ASS
  render-time gate that holds the intended timestamp until native playback time
  reaches the prepared window.
- Retargeted the gate for explicit seek, scrub, and subtitle-hold writes inside
  the prepared window, preserving same-video `loadSubtitleSource` then `seek`
  result navigation.
- Passed the target timestamp through the shared macOS ASS subtitle source
  helper used by Search, Shiori, Library, and context-derived playback.
- Replaced and invalidated the source-faithful ASS renderer worker whenever the
  overlay reloads a source, so old queued render work cannot block the new
  subtitle source load.
- Added regression coverage for request timestamp defaults, time-window clamp
  and containment, render-time gate hold/retarget behavior, and renderer worker
  replacement on source changes.

## Verification

- `git diff --check`
- `swift test --filter playbackSubtitleRenderTimeGateRetargetsExplicitTimestampInsideWindow`
- `swift test --filter sourceFaithfulASSSubtitleOverlayReplacesRendererWorkerWhenSourceChanges`
- `swift test --filter PlaybackRequest` (30 Swift Testing tests passed)
- `swift test --filter Playback` (110 Swift Testing tests passed)

## Outcome

ASS subtitle source handoff now uses the requested playback target timestamp,
keeps stale native player time from pulling the renderer outside the prepared
window during handoff, and isolates new source loads from old renderer queues.
The remaining Library playback history disk I/O messages observed during
`swift test --filter Playback` are pre-existing log output; the filtered test
run passed.
