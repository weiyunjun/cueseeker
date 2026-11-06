# Video Stream Selection, Duration Probing, and Audio Track Fallback

## Summary

- Requirement: `docs/human/requirements/20261106-Bug-Video Stream Selection Duration Probing And Audio Track Fallback.md`
- Unified primary video stream selection across metadata inspection, cover sampling, scrub preview decoding, and native playback (`SFXSelectPrimaryVideoStreamIndex` in `SFXVideoToolboxSupport.m`, `SFXMediaMetadataInspector.m`, `SFXKeyframeScrubPreviewDecoder.m`, and `SFXNativePlaybackSession.m`):
  - Excluded streams marked with `AV_DISPOSITION_ATTACHED_PIC`, `AV_DISPOSITION_STILL_IMAGE`, or `AV_DISPOSITION_TIMED_THUMBNAILS`, and deprioritized leading static-image cover codecs (`mjpeg`, `png`, `bmp`, `webp`, etc.) when a motion video stream is present in the container, falling back to attached-pic streams only when no motion video stream exists.
- Added tail packet timestamp duration fallback probing (`SFXResolveMediaDurationSeconds` in `SFXVideoToolboxSupport.m`):
  - When both `AVFormatContext.duration` and non-attached-pic `AVStream.duration` values are missing or zero, sought near the end of seekable containers to read the trailing audio/video packet timestamps, subtracted `timelineOriginSeconds`, restored the demuxer position to the start of the stream, and exposed the probed duration across metadata indexing, cover generation, `File Detail` duration/bitrate calculation, and player timeline duration.
  - Updated `IndexingDatabase.pendingVideoMetadataPaths` and `AppCoordinator+Indexing.swift` so re-indexing a folder refreshes videos with missing/zero duration or invalid ghost audio tracks and includes updated video paths in `LibraryCoverIndexer.indexCovers`.
- Filtered invalid `0ch / 0Hz` ghost audio streams and added automatic audio track fallback / silent degradation (`SFXIsAudioStreamValid`, `SFXMediaMetadataInspector.m`, `SFXNativePlaybackSession.m`, `LibraryDatabaseModels.swift`, `LibraryDatabase.swift`, and `LibraryDatabase+FileDetail.swift`):
  - Excluded audio streams with `channels <= 0` or `sample_rate <= 0` during metadata inspection, `File Detail` audio track display, `More -> Audio Track` menu listing, and playback audio track indexing.
  - Updated `SFXNativePlaybackSession.prepareWithError:` to try remaining valid audio tracks in order when the requested/default audio track fails to initialize, and to degrade cleanly to video-only playback (`_audioStreamIndex = -1`, `_audioTrackIndex = -1`, `_audioPrimed = YES`, `_audioOutputDrained = YES`) when no audio track can be decoded.
- Added readable codec display names in `MediaDetailFormatter` (`LibraryDatabase+FileDetail.swift`):
  - Mapped `h263` / `h263p` / `h263i` to `H.263`, `flv1` to `Sorenson Spark (FLV1)`, `cook` to `RealAudio Cook`, and `speex` to `Speex`.

## Verification

- `swift test --package-path apps/macos-native --filter "FileDetailDialogTests|PlaybackVideoMetadataIndexerTests|LibraryDatabaseTests"`
