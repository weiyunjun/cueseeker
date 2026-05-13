# ADR 0012: Search Thumbnail Cache Policy

## Status
Accepted

## Context
When displaying search results, we want to generate 160x90 AVIF thumbnails for the cue midpoint. Generating these thumbnails via ffmpeg is computationally expensive, especially with 100 results per page. We need a caching mechanism to ensure that thumbnails are generated only once and persisted across app restarts, avoiding redundant CPU/IO usage and ensuring UI responsiveness.

## Decision
We will implement a disk-based caching strategy for search result thumbnails.

### Cache Location
- The cache will be stored in `~/Library/Caches/com.cueseeker.macos-native/Thumbnails`.
- As App Sandbox is currently disabled for local development (see ADR-0004), direct access to `~/Library/Caches` is acceptable.

### Cache Key Format
To ensure uniqueness and freshness, the cache key must be a stable hash (e.g., SHA256) of:
1. Video file path.
2. Video file size or modification time (to detect changes to the source video).
3. Timestamp in milliseconds (the midpoint of the cue).
4. `160x90` and `avif` to specify the layout properties.
5. Thumbnail generator version `v1`.

### Concurrency and Resource Isolation
- Thumbnail generation tasks are spawned concurrently with a maximum limit of 20 active ffmpeg processes.
- The processes will run with low-priority quality of service (QoS) and `nice` adjustments to ensure video playback backend and UI threads are not starved.
- If a query changes or results are unmounted, pending generation tasks should be canceled.

## Consequences
- **Positive:** Improved UI scroll performance and reduced CPU spikes on recurring searches.
- **Negative:** Increased disk usage over time. A cleanup strategy (TTL or LRU size-based eviction) will be needed in the future to manage cache growth.
