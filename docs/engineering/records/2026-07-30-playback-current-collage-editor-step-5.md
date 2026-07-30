# Playback Current Collage Editor Step 5

## Requirement

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`
- `docs/human/design/UI.md`

## Scope

Implement Step 5 Copy Collage and Export Collage actions using the current live
preview result. The actions must not start another Collage render, and Export
must reuse the table Collage save panel configuration and file naming rule.

## Steps

1. Bound each committed preview image to its selection plan and exposed it to
   actions only when it matches the latest requested plan.
2. Enabled both preview actions only while the current generation has a
   completed image, preventing an older visible image from being copied or
   exported during a newer render.
3. Connected Copy Collage to the existing playback PNG encoder and pasteboard
   writer without adding another image conversion path.
4. Extracted the existing table Collage save panel configuration for reuse by
   Playback and kept the same PNG content type and panel behavior.
5. Centralized the Collage filename fields so table items and the Playback
   selection plan produce the same display-title, timeline-bound, and cue-count
   format.
6. Added direct export of an already composed Collage image so Export writes
   the preview result instead of rendering it again.

## Verification

- Ran 145 related Playback Current, virtual Reel, Collage preview, filename,
  PNG export, and pasteboard tests: all passed.
- Verified that action availability rejects incomplete and obsolete preview
  generations and accepts only the latest committed plan and image.
- Verified that the Playback filename overload matches the existing table
  Collage naming result.
- Verified that an already composed Collage image is written as non-empty PNG
  data.
- Ran `git diff --check`: passed.
- Confirmed the user-owned `docs/human/design/UI.md` change remains unstaged and
  is not part of this implementation.

## Outcome

Copy Collage and Export Collage now consume the exact current live-preview
image. Copy publishes PNG data to the pasteboard, while Export opens the shared
Collage save panel and writes that same composed image with the existing table
filename rule.

## Follow-ups

- Complete the refresh-scope and integrated UI review in Step 6.
