# Playback Clock Alignment, Timestamp Discontinuity, Audio Layout, and Scrub Preview

## Summary

- Requirement: `docs/human/requirements/20261106-Bug-Playback Clock Alignment Timestamp Discontinuity Audio Layout And Scrub Preview.md`
- Preserved natural timeline offsets for zero-based containers while normalizing non-zero origins on discontinuous broadcast streams (`SFXMediaTimelineOriginSeconds` in `SFXVideoToolboxSupport.m`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`):
  - Restricted positive `start_time` subtraction in `SFXMediaTimelineOriginSeconds` to containers marked with `AVFMT_TS_DISCONT` (such as `.ts` / `.m2ts` / `.vob`) and negative start offsets, keeping zero-based containers (such as `.mkv` / `.mp4` where media starts at `10.0s`) on their natural timeline so subtitles starting at `0s` and playback progress up to the end of the file remain aligned.
  - Gated initial audio drain (`requestAudioDrain`) until the first post-seek/open video frame is decoded (`_firstVideoFrameDecodedForSeek`), and advanced `_seekSeconds` to the first decoded video frame timestamp when it starts more than `0.25s` after `_seekSeconds` (such as `.ts` streams whose first video keyframe is ~`1.12s` after early audio frames or `.mkv` files whose streams start at `10.0s`), preventing pre-video audio packets from anchoring the clock early and freezing the first video frame.
- Added mid-stream timestamp discontinuity detection and clock re-anchoring (`SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`):
  - Restricted `SFXFrameBeforeSeekTarget` frame dropping strictly to pre-seek frames (`!_firstVideoFrameDecodedForSeek` / `!_firstAudioFrameDecodedForSeek`) so post-seek frames after a mid-stream timestamp wrap-around (`36.45s -> 0.00s`) are never discarded.
  - Detected backward jumps (`< -1.0s`) and large forward jumps (`> 10.0s`) in `paceVideoFrame:`, re-anchoring `_videoFirstMediaSeconds`, `_audioFirstMediaSeconds`, and `_currentTime` to the new media timestamp at current host time (`CACurrentMediaTime()`).
  - Updated `packetQueueBufferedSecondsForHeadLocked:tail:` to sum contiguous positive inter-packet deltas when queue timestamps contain a wrap-around or >10s jump so read-ahead buffering never stalls, and guarded `requestAudioPlaybackStartIfReadyForGeneration:` so `playAtTime:` is not scheduled hundreds of seconds in the future across a forward timestamp jump.
- Retained VideoToolbox hardware decode and fast first-frame presentation on Blu-ray `.m2ts` / `.ts` streams (`SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`):
  - Skipped redundant initial `SFXSeekToStartPosition` when opening at `0s` (`_seekSeconds <= 0.001`).
  - Skipped leading non-keyframe video packets (`!_seenVideoKeyframePacketSinceFlush && !isKeyframePacket`, up to 180 packets) after open/seek flush before feeding the decoder, and restricted Gate 2 first-packet software fallback to actual keyframe packets prior to presenting any video frame (`isKeyframePacket && _presentedVideoFrameCount == 0`).
- Normalized unspecified audio channel layouts before resampling (`SFXEnsureValidChannelLayout` in `SFXVideoToolboxSupport.m`, `SFXNativePlaybackSession.m`, `SFXNativePlaybackSession+AudioAndDecode.m`):
  - Normalized `AVChannelLayout` structs with `AV_CHANNEL_ORDER_UNSPEC` or invalid layout checks to `av_channel_layout_default(layout, channels)` across audio decoder initialization, packet handling, and `swr_alloc_set_opts2` resampler creation so `pcm_s24le` / `pcm_s16le` tracks with unspecified channel layouts resample and play normally.
- Fixed `.rmvb` and `.ts` / `.m2ts` / `.vob` scrub preview thumbnail decoding (`SFXKeyframeScrubPreviewDecoder.m`, `SFXNativePlaybackSession.m`):
  - In `SFXKeyframeScrubPreviewDecoder`, kept non-reference frames (`AVDISCARD_BIDIR`) and loop filtering (`AVDISCARD_DEFAULT`) enabled for RealVideo (`RV10/20/30/40`), skipped leading non-keyframe packets after seek, and continued feeding consecutive packets for RealVideo instead of flushing with `NULL` after the first keyframe packet so multi-slice `.rmvb` keyframes assemble and decode into preview thumbnails.
  - In `populateKeyframeStreamTimestamps`, discarded incomplete container keyframe index tables (fewer than 2 entries or spanning less than 50% of media duration for videos >4s) so `.ts` / `.m2ts` / `.vob` streams fall back to target-timestamp scrub preview decoding across the full timeline.

## Verification

- `swift test --package-path apps/macos-native --filter CueSeekerPlaybackTests`
