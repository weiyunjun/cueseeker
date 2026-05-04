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

## Initial Native Implementation

The first implementation uses the medium warm-up level for committed search
results only.

Rules:

- Eligibility is based on configured remote media sources, not host topology.
  AList and generic WebDAV sources are eligible even when their URL points to a
  LAN address. Local folders and mounted NAS paths are not eligible.
- Search publishes candidates only after Return commits a query and results are
  materialized. Typing draft text must not start warm-up.
- Search candidates collapse by stable remote media identity and keep the first
  result timestamp for each video in the visible result ordering.
- The coordinator accepts at most three distinct videos from a search result
  list and runs one warm-up at a time after a short debounce.
- Medium warm-up builds the normal remote playback request, resolves AList or
  generic WebDAV playback material through the local stream proxy, opens a
  muted background native player at the warm point, primes briefly, then pauses
  the session.
- Background warm-up does not attach ASS subtitle rendering state. If the user
  selects a warmed result, the warm session is promoted to active playback and
  the subtitle source is attached during promotion.
- Warm sessions expire after a short idle period. New searches cancel obsolete
  queued work and release warm sessions that no longer match the current
  candidate set.
- Warm-up stores no whole video files, signed URLs, provider headers, tokens, or
  packet cache data on disk.

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

## Remote Byte-Range Cache Direction

The preferred long-term acceleration path is a disk-backed remote byte-range
cache below playback, not temporary clip files. Playback should continue to see
one logical remote media resource while the cache satisfies known byte ranges
locally and fetches missing ranges from the provider.

Cache scope:

- Eligible sources: configured AList and generic WebDAV remote media sources.
- Non-eligible sources: local folders, mounted NAS paths, and whole-video
  temporary downloads.
- Cache unit: a remote media identity plus one or more byte ranges needed for a
  keyframe-aware playback window.

Keyframe window policy:

- For a subtitle result or future favorite timestamp, the cache target has a
  desired playback window.
- The cache start must be the nearest video keyframe at or before the desired
  window start. This is required because video decode cannot reliably begin from
  arbitrary inter frames.
- The cache end must be the nearest video keyframe at or after the desired
  window end. This gives playback enough complete GOP coverage to continue
  beyond the searched line without immediately falling back to remote reads.
- Audio ranges should cover the same effective playback interval so a cached
  video window does not start with missing audio.
- If keyframe metadata is not yet available, the cache may use a conservative
  fallback window, but precise keyframe windows are the target behavior.

Cache limits:

- Maximum cached range-window entries: 1,000.
- Maximum total cache size: 16 GB.
- Maximum per-video cache size: 64 MB.
- Per committed search prefetch cap during testing: 20 remote cache windows.
- These limits are storage and prefetch caps. They do not imply warming every
  search result, favorite, or distinct video.

Lifecycle and invalidation:

- The cache should use LRU eviction, biased toward current search results,
  current playback, recent clicks, and future favorites.
- Cached ranges must be invalidated when source identity or metadata changes.
  Useful validation inputs include provider id, source id, source-relative path,
  size, modification time, ETag, and content hash when available.
- App shutdown may keep the cache within the configured disk limits. Explicit
  source removal must remove cache entries derived from that source.
- The cache must not persist AList tokens, signed raw URLs, provider headers,
  Basic auth headers, or whole videos.

Scheduler implication:

Search, favorites, and future result surfaces should publish cache candidates to
the centralized scheduler. The scheduler decides which candidates become cache
prefetch work, which become light provider warm-up, and which are upgraded to
active playback warm sessions. A search page may expose many results, but the
testing policy starts with at most 20 cache prefetch windows per committed
search.

First implementation note:

- The first implementation lives under the local stream proxy rather than a
  custom FFmpeg AVIO layer.
- It prefetches header and tail ranges, then estimates target byte windows from
  subtitle timestamps until keyframe metadata is available.
- It captures small byte ranges requested by FFmpeg during remote playback so
  repeated opens and nearby seeks can hit disk even before precise keyframe
  indexing exists.
- It is an evaluation step for the cache direction, not the final keyframe-exact
  range planner described above.

## Durable Data Policy

Warm-up can justify durable storage only when the durable data removes a
remote-only cost that local files do not pay.

Suitable durable data may include:

- Stable media identity.
- Duration and stream metadata.
- Codec names, stream indexes, time bases, and seekability.
- Future bounded container seek-index summaries.
- Keyframe index summaries needed to map subtitle timestamps to cacheable
  decode windows.
- Bounded remote byte-range cache metadata and cached range payloads under the
  configured cache limits.
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
