# URL Scheme

Status: Active

## Identity

- The final macOS bundle identifier is `com.cueseeker.app`.
- The application URL scheme is `cueseeker`.
- The preferences suite remains `com.cueseeker.shared`; changing the bundle
  identifier must not split or reset local application state.

## Version 1 Contract

The only supported command is:

```text
cueseeker://search?q={{keyword}}
```

Rules:

- The scheme and host are compared case-insensitively.
- The host must be `search`; the path must be empty or `/`.
- Exactly one `q` query item is required.
- `URLComponents` performs percent decoding. The decoded keyword is trimmed of
  surrounding whitespace and newlines and must remain non-empty.
- User information, a port, fragments, unknown parameters, duplicate `q`
  parameters, malformed percent encoding, and unsupported hosts are rejected.
- Invalid URLs are ignored without changing application state or presenting an
  error in version 1.

Non-ASCII keywords should be percent-encoded when links are constructed. macOS
may deliver a decoded URL object, but the parser must not depend on raw Unicode
being accepted by every external launcher.

## Delivery

The AppKit delegate registers an Apple Event handler for
`kInternetEventClass` / `kAEGetURL` before application launch completes. A
valid command received before the main window exists is retained and consumed
after the window is created. A valid command received while running is handled
immediately on the main actor.

Only the most recently received pending command is retained during startup.
Every running-state command is processed once.

## Search Behavior

Handling a valid search command must:

1. Leave fullscreen and stop active playback, preserving the existing playback
   history behavior.
2. Select the Search workbench panel.
3. Clear the active search filter set and any cue-context search state.
4. Put the decoded keyword in the visible search field.
5. Submit through the existing non-debounced search pipeline.
6. Make the main window key and activate CueSeeker.

The URL handler must not duplicate database search logic.

## Packaging and Verification

The packaged `Info.plist` must declare the final bundle identifier and one URL
type containing the `cueseeker` scheme. Bundle verification must fail when
either value is missing or different.

Parser behavior, search-state transitions, and invalid-input no-op behavior
require automated tests. Final acceptance additionally requires both cold and
running-state launches through macOS Launch Services.
