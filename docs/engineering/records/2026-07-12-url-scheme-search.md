# URL Scheme Search

Date: 2026-07-12

## Requirement

- `docs/human/requirements/20260712-Feature-URL Scheme.md`

## Scope

Add the first CueSeeker URL Scheme command for opening an unfiltered search,
including final application identity, AppKit event delivery, navigation, tests,
packaging verification, and an installable acceptance build.

## Steps

1. Defined the URL grammar, invalid-input behavior, cold and running delivery,
   search-state transition, and packaging gates in
   `docs/engineering/10_url_scheme.md`.
2. Changed the packaged and runtime bundle identifier to `com.cueseeker.app`,
   registered the `cueseeker` URL scheme, and added both values to recursive app
   bundle verification.
3. Added a strict, independently tested URL command parser for the version 1
   search grammar and invalid-input no-op boundary.
4. Registered the AppKit Get URL Apple Event handler before launch completion,
   retained a cold-start command until the window existed, and routed running
   commands immediately.
5. Reused the existing playback shutdown and non-debounced search submission
   paths while clearing active filters and cue-context state, selecting Search,
   displaying the keyword, and activating the main window.

## Verification

- Pending implementation.

## Outcome

Pending implementation and end-to-end acceptance.

## Follow-ups

- Confirmation prompts and additional commands remain outside version 1.
