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

- `swift test` passed all 7 XCTest tests and 554 Swift Testing tests.
- URL parser tests covered encoded Unicode, trimming, case-insensitive routing,
  empty and duplicate parameters, unknown parameters, unsupported routes, and
  malformed percent encoding.
- Search routing tests confirmed the command selects Search, displays the
  keyword, clears the active filter set, and clears cue-context state.
- `scripts/package_macos_app.sh` produced and recursively verified a
  self-contained, ad-hoc-signed ARM64 app with bundle identifier
  `com.cueseeker.app` and the `cueseeker` URL scheme.
- Replaced `/Applications/CueSeeker.app` and forced Launch Services
  registration for the final bundle.
- A cold Launch Services invocation for encoded keyword `大丈夫` started the
  installed app and the search E2E log recorded completed results for that exact
  query.
- A second invocation while the same process was running replaced the query
  with `確認`; the search E2E log recorded completed results, proving running
  Apple Event delivery.

## Outcome

Implementation and automated verification match the requirement. The installed
build is ready for human end-to-end acceptance, including the required
playback-to-search transition.

## Follow-ups

- Confirmation prompts and additional commands remain outside version 1.
