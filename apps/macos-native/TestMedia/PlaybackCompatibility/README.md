# Playback Compatibility Test Media

This directory contains small generated media files used for native playback
compatibility checks.

Each media file has a same-basename `.srt` subtitle file with the same sentinel
phrase:

```text
SubFinderX hardware compatibility sentinel phrase 2026-05-01
```

Add this directory in the app's folder settings, index it, then search for the
sentinel phrase to show all compatibility samples in one result set.

The files are intentionally small generated fixtures. They are not production
benchmark assets and should be replaced or expanded when stricter playback
performance testing is introduced.
