# ADR-0004: Sandbox and File Access

Status: Accepted

## Background

SubFinderX must scan user-selected local subtitle folders and open matching local video files. Persistent local file access is central to the M1 workflow.

The early native rewrite is a personal local macOS app. Public distribution, Mac App Store release, and enterprise deployment are out of scope.

Sandboxing affects:

- Folder selection.
- Recursive file scanning.
- Persistent access after restart.
- Playback engine access to local video files.
- Signing and release packaging.

## Decision

The M1 native macOS app will run without App Sandbox for local development and personal builds.

File access rules:

- The app must use native macOS folder selection for adding subtitle folders.
- The app must scan only user-selected folders.
- Selected folder paths may be persisted as local configuration for M1.
- Security-scoped bookmarks are not required for M1 while App Sandbox is disabled.
- Missing, moved, unreadable, or permission-denied folders must be reported clearly.
- The app must not silently scan unrelated folders.

If public distribution, Mac App Store distribution, or sandboxed release builds become a goal, sandboxing and security-scoped bookmarks must be revisited through a new or superseding ADR.

## Rationale

Disabling App Sandbox for M1 reduces complexity while the project proves the local subtitle search and playback loop.

This decision is consistent with the current product direction:

- Personal macOS usage.
- Local-first workflow.
- No public release polish in early milestones.
- No remote services or credential storage in M1.

It also reduces early integration risk with embedded `libmpv`, recursive folder scanning, and local video file access.

## Tradeoffs

Benefits:

- Simpler local folder scanning.
- Simpler local video playback.
- No early security-scoped bookmark implementation.
- Lower risk for M1 playback integration.
- Faster path to validating the core product loop.

Costs:

- Not suitable for Mac App Store distribution.
- Weaker macOS privacy and containment guarantees.
- Future sandbox adoption may require migration from persisted paths to security-scoped bookmarks.
- Release behavior must be documented carefully so sandbox settings do not change accidentally.

## Alternatives Considered

### Enable App Sandbox for M1

This would align better with future distributable builds and force early security-scoped bookmark handling.

It was not selected because M1 is a personal local build and the added complexity would slow validation of the core subtitle search and playback loop.

### Disable App Sandbox for M1

This keeps file access and playback integration simple while retaining explicit user folder selection.

This option was selected.

### Support Both Sandboxed and Unsandboxed Builds Immediately

Supporting both modes would expose release risks early.

It was not selected because it would increase test and packaging complexity before the native app shell exists.

## Consequences

- M1 does not need security-scoped bookmark storage.
- M1 folder persistence may store selected local paths.
- File access tests must verify selected-folder scanning and clear errors for unavailable folders.
- Release rules must continue to treat sandboxing as a release-critical setting.
- A future sandboxed release requires a new ADR, migration plan, and tests for persistent folder access.

