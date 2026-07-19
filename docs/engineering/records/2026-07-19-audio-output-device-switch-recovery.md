# Audio Output Device Switch Recovery

Date: 2026-07-19

Human-owned requirement:

- `docs/human/requirements/20260719-Bug-Audio Output Device Switch Recovery.md`

## Scope

Restore native macOS audio playback when the system output device changes while
video playback is active. Keep the recovery inside the native playback
execution layer and preserve the current media position, bounded segment,
pause state, volume, and playback rate.

## Root Cause

The native session created and started one `AVAudioEngine` when opening media.
It did not observe audio-engine configuration changes. When disconnecting a
Bluetooth output changed the hardware sample rate or channel configuration,
AVFAudio stopped and uninitialized the engine, while CueSeeker's synthetic
media clock and video decode continued advancing.

The stopped `AVAudioPlayerNode` could also release scheduled buffers through
their completion handlers. Without invalidating the old playback generation,
those callbacks could be mistaken for audio that reached the output device.

## Implementation

- Registered an `AVAudioEngineConfigurationChangeNotification` observer for
  each active native audio engine and removed it before intentional teardown.
- Kept the notification callback non-destructive. It immediately marks audio
  reset in progress, invalidates the old playback generation, stops further PCM
  feeding, and schedules recovery through the player control path.
- Coalesced recovery requests on the main control path so repeated hardware
  notifications cannot create overlapping session mutations.
- Extended the existing in-session seek reset with an audio-output rebuild
  option. Recovery stops and recreates the engine, player node, time-pitch node,
  format, connections, and observer, then flushes decoder state and resumes
  from the current media timestamp.
- Preserved the active segment endpoint, Auto Pause behavior, pause state,
  volume, and playback rate. A failed audio-engine restart leaves playback
  paused and reports the underlying error instead of continuing silently.
- Added a recovery counter and a test-only request entry point. The regression
  test verifies that rebuilding does not open a new native session or count as
  a user seek, old PCM completion does not register an unexpected drain, and
  played-back audio buffers continue increasing after recovery.

## Rejected Candidate

An intermediate defensive check queried `AVAudioEngine.isRunning` from the
`AVAudioPlayerNode` buffer completion handler. Stress verification showed that
`AVAudioPlayerNode.stop()` can wait for that completion while the query waits
for the same AVFAudio internal lock. The resulting deadlock was captured with a
process sample, and the candidate check was removed. Final recovery relies on
the documented engine-configuration notification and generation invalidation.

## Verification

- `swift build --package-path apps/macos-native`: passed.
- Focused `nativePlaybackRebuildsAudioOutputAndContinuesInCurrentSession`:
  passed.
- `swift test --package-path apps/macos-native --filter CueSeekerPlaybackTests.native`:
  passed all 6 native playback tests, including recovery, common timeline,
  natural audio drain, Auto Pause resume, rapid seeks, and presentation
  transitions.
- Full `swift test --package-path apps/macos-native --skip-build`: 792 of 795
  tests passed. Under full-suite parallel load, the new recovery test and two
  existing native audio timing tests exceeded their polling deadlines; the
  same six native tests pass together with the scoped filter above.
- Automated recovery kept `nativeSessionOpenCount` and
  `nativeInSessionSeekCount` unchanged, added one successful recovery, produced
  additional played-back PCM buffers, and added no unexpected audio drain.
- Physical Bluetooth disconnect and switching to built-in or another external
  output remain pending human end-to-end listening verification.

## Outcome

Automated verification supports the requested behavior: the native playback
session can rebuild its output graph and continue audio from the current media
position without reopening the video. Final acceptance requires reproducing
the original Bluetooth sequence on hardware.
