# Remote Playback Warm-Up State Machine

Status: Draft

Date: 2026-05-04

## Context

Remote WebDAV and AList playback has a higher cold-start cost than local file
playback. Local playback can usually open, inspect, seek, and read target bytes
with low latency. Remote playback may pay extra cost for provider resolution,
HTTP byte-range reads, container probing, decoder setup, and first-frame packet
fetching.

Search-result warm-up can reduce cold-start latency for likely next selections.
The same problem will appear in future favorites, filtered search views, sorted
result lists, recommendations, and other surfaces that expose playable subtitle
moments. Warm-up should therefore be centralized rather than implemented
separately by each feature.

## Goals

- Provide one global coordinator for remote playback warm-up.
- Let search, favorites, and future result surfaces publish prioritized warm-up
  candidates without owning playback sessions directly.
- Bound provider API calls, remote range requests, memory, CPU, and warm session
  count.
- Reuse warm sessions when a user selects a prepared video.
- Keep warm-up optional: click-to-playback must still work when no warm session
  exists or warm-up is incomplete.
- Make warm-up observable enough to evaluate provider politeness and user-visible
  latency improvements.

## Non-Goals

- Do not implement whole-video temporary downloads.
- Do not persist AList tokens, signed raw URLs, provider headers, or Basic auth
  headers.
- Do not make a byte-range disk cache part of the first warm-up implementation.
- Do not let result-row count directly determine remote warm-up count.

## Core Model

### Warm Candidate

A warm candidate is a feature-owned request to prepare a specific media file.

Fields:

- Stable media identity: source id, provider type, source-relative media path,
  size, and modified time when available.
- Source surface: search, favorites, future recommendations, or another feature.
- Surface generation: an identifier that changes when the result list, filter,
  sort order, or visible range changes.
- Priority score.
- Warm point in milliseconds.
- Candidate reason, such as first visible result, hover, keyboard selection,
  recent playback, or top search result.
- Visibility hint, such as visible, near visible, offscreen, or background.
- Created time and last updated time.

### Warm Task

A warm task is scheduler-owned work derived from one or more candidates for the
same stable media identity.

Rules:

- Multiple candidates for the same video collapse into one task.
- The task chooses one active warm point. For ordered search results, the initial
  warm point is the first result for that video in the current ordering. For
  favorites, the warm point is the favorite timestamp.
- When sorting, filtering, or viewport state changes, the task may update its
  warm point, priority, or cancellation generation.

### Warm Session

A warm session is a memory-owned native playback preparation resource.

It may hold:

- Provider-resolved playback material in memory.
- Local proxy target state.
- FFmpeg format context and stream inspection state.
- Decoder setup state.
- Optional medium warm-up state at the warm point.
- Optional bounded compressed packet data only after a separate resource policy.

It must not hold on disk:

- Provider tokens.
- Signed URLs.
- Provider playback headers.
- Whole video files.

## Warm Levels

### Light Warm-Up

Light warm-up resolves provider playback material and prepares native open or
probe state. It targets the provider-resolution and container-probe portion of
cold-start latency.

Expected cost:

- Up to one provider file-resolution request per warmed video when the raw URL
  cache misses.
- One or more remote HTTP requests from native open and probe.
- Minimal disk use.
- Memory for the native open/probe state.

### Medium Warm-Up

Medium warm-up extends light warm-up by seeking to the warm point and decoding
enough to make first-frame readiness cheaper.

Expected cost:

- Light warm-up cost.
- Additional remote range reads near the warm point.
- A short CPU spike for decode-to-first-frame work.
- More memory than light warm-up, but still bounded by warm session limits.

### Heavy Warm-Up

Heavy warm-up retains compressed packet data near the warm point.

This is not part of the first implementation. It needs a separate policy for
memory caps, disk cache caps if any, expiry, invalidation, user controls, and
provider politeness.

## State Machine

Warm coordinator states:

```text
idle
  -> debounce
  -> queued
  -> resolving
  -> opening
  -> priming
  -> warm
  -> promoted

Any active state may transition to cancelled.
resolving, opening, and priming may transition to failed.
warm may transition to expired.
failed may transition to cooling_down and later queued.
```

State definitions:

- `idle`: no candidates or no eligible work.
- `debounce`: candidates have changed and the coordinator waits briefly before
  scheduling remote work.
- `queued`: a task is eligible but not running because of global limits or a
  higher-priority task.
- `resolving`: provider playback material is being resolved in memory.
- `opening`: native playback open and probe work is being prepared.
- `priming`: optional medium warm-up seeks to the warm point and decodes enough
  to reduce first-frame wait.
- `warm`: a warm session is available for promotion.
- `promoted`: a user selected this media, so the warm session becomes active
  playback.
- `expired`: the warm session exceeded its idle lifetime and was released.
- `cancelled`: the candidate generation changed, the surface disappeared, or
  the task lost eligibility.
- `failed`: warm-up failed with a recorded reason.
- `cooling_down`: a failed task waits before it can be retried.

## Scheduler Policy

Initial policy:

- Maximum warm sessions: 2 or 3 distinct videos.
- Remote warm-up concurrency: 1.
- Candidate debounce: 500 to 1000 ms after result-list changes.
- Warm session idle lifetime: 2 to 5 minutes.
- First implementation level: light or medium warm-up only.
- Candidate ordering: visible and top-ranked items first, then hover or keyboard
  selection, then recent playback or recent favorites.
- Search behavior: collapse result rows by video identity and use the first
  result for each video in current sort order as the warm point.
- Favorites behavior: prioritize visible favorite rows and use each favorite's
  timestamp as its warm point.
- Cancellation: any surface generation change can cancel queued or active
  warm-up work that no longer matches current candidates.
- Provider politeness: do not launch warm-up for every distinct video in a large
  list; do not run parallel remote warm-up by default.

## Favorites Implication

A favorites list may contain many remote videos. For example, 100 favorites may
map to 100 different Baidu Netdisk media files. Opening the favorites list must
not warm all 100 files.

The favorites surface should publish candidates only for likely next actions:

- Visible rows.
- Near-visible rows if scrolling is stable.
- Hovered row.
- Keyboard-selected row.
- Recently used favorites.

The coordinator should still apply the same global caps used by search results.
Favorites are not a special playback path; they are another producer of warm
candidates.

## Durable Data Policy

Warm-up can justify durable storage only when the durable data removes a
remote-only cost that local files do not pay.

Suitable durable data may include:

- Stable media identity.
- Duration and stream metadata.
- Codec names, stream indexes, time bases, and seekability.
- Future bounded container seek-index summaries.
- Existing subtitle playback caches.

Unsuitable durable data:

- AList tokens.
- Signed raw URLs.
- Provider playback headers.
- Basic auth headers.
- Whole video files.

Future byte-range disk caching requires a separate design covering size caps,
expiry, source metadata validation, deletion, privacy, and user controls.

## Observability

Warm-up diagnostics should record:

- Result rows received.
- Distinct media candidates.
- Candidates accepted and skipped by policy.
- Warm-up state transitions.
- Provider API calls.
- Proxy requests and remote range requests triggered by warm-up.
- Warm-up duration by state.
- Memory footprint by warm session.
- Warm hit, warm miss, cancelled, expired, and failed counts.
- Click-to-first-frame latency for warm hits and misses.

Logs must not include tokens, signed URLs, provider headers, or credentials.

## Open Questions

- Whether the first implementation should stop at light warm-up or include
  medium warm-up.
- Whether warm sessions should be allowed while active playback is already using
  high CPU or high memory.
- Whether favorites should use viewport-only priority or also factor in recent
  playback history.
- Whether future byte-range cache work belongs in the same coordinator or in a
  lower-level media IO cache.
