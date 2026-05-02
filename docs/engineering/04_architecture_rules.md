# Architecture Rules

Status: Draft

## 1. Purpose

This document defines architecture rules for the native macOS rewrite of CueSeeker.

It is an engineering rule document, not a product requirements document. Product behavior belongs in `docs/product/`.

## 2. Architecture Principles

The native rewrite must prioritize a small, reliable local workflow before broader features.

Core principles:

- Keep the M1 implementation focused on the local subtitle search and playback loop.
- Prefer native macOS capabilities when they satisfy the product requirement.
- Keep persistent data local unless a future proposal explicitly changes that rule.
- Make hard-to-reverse technical decisions through ADRs before production implementation depends on them.
- Keep modules isolated enough that indexing, search, persistence, and playback can be tested independently.
- Avoid introducing remote services, sync layers, or cross-platform abstractions during the early native rewrite.

## 3. Target Platform

Primary platform:

- macOS.

Minimum supported version:

- macOS 13.0 Ventura, provisional.

Rules:

- The app must not depend on Flutter for active native implementation.
- The active native app must live under `apps/macos-native/`.
- Raising the minimum macOS version requires updating product and engineering documentation.
- If a newer minimum version is required by a playback, sandboxing, or UI decision, that decision must be recorded before implementation depends on it.

## 4. Application Stack

The initial native rewrite should use native macOS development tools.

Required stack decisions before implementation:

- UI framework choice.
- Application architecture pattern.
- SQLite access strategy.
- Playback engine strategy.
- Dependency management strategy.
- Sandbox and file-access strategy.
- Packaging and distribution expectations.

Default assumptions until a more specific document or ADR replaces them:

- UI should use native macOS frameworks.
- Persistent search data should use SQLite with FTS5.
- Remote services are out of scope.
- Local file access is central to the app and must be designed explicitly.

Accepted ADRs:

- ADR-0002 selects Swift, SwiftUI, AppKit bridges, Swift Package Manager, SQLite with FTS5, and a project-owned persistence layer for M1.
- ADR-0007 supersedes ADR-0006 and ADR-0003 and selects native-only playback.
- ADR-0004 disables App Sandbox for M1 local development and personal builds.

## 5. Module Boundaries

The native app should be organized around clear engineering responsibilities.

Expected responsibility areas:

- App shell and window lifecycle.
- Folder selection and file access.
- Subtitle scanning.
- Subtitle parsing.
- Video matching.
- Database persistence and migrations.
- Full-text search.
- Playback.
- Settings and local configuration.
- Error reporting and logging.

Rules:

- Subtitle parsing must not depend on UI state.
- Database persistence must not depend on playback UI state.
- Search must read from the database/index layer, not directly from arbitrary subtitle files.
- Playback must receive a resolved local video path and timestamp, not perform subtitle parsing itself.
- UI state may coordinate workflows, but it must not be the only place where indexing or database rules are enforced.

## 6. Data Flow

The M1 local loop should follow this conceptual flow:

```text
Selected folders
Scan supported external subtitle files
Parse subtitle cue groups and cue lines
Match local video files
Persist metadata, cue groups, and cue lines
Update FTS index
Search indexed text
Open matched video at start_ms
```

Rules:

- Source subtitle files remain the source of truth for indexed subtitle content.
- The SQLite database is an indexed local cache plus local app state, not a replacement for the source files.
- The first M2 ASS support step should add ASS indexing, grouped cue search
  results, grouped result display, and click-to-playback behavior.
- SRT blocks should map to cue groups with one cue line.
- ASS `Dialogue` events should map to cue groups and cue lines.
- ASS cue grouping must use exact subtitle file, `start_ms`, and `end_ms`
  equality. Timestamp tolerance grouping is out of scope for the first ASS step.
- Search may use cue group aggregate text for recall, but returned groups must
  satisfy line-level query semantics so terms split only across different cue
  lines do not create a match.
- Reindexing must be able to remove stale entries when source subtitle files disappear.
- Indexed content must be reconciled with the currently selected folders so rows
  from removed folders do not remain visible.
- Search must be scoped to the currently selected folders.
- Search result playback must be based on persisted subtitle timing and matched video path.

## 7. UI Architecture

The UI must support the product's native macOS workflow without forcing future remote or cross-platform assumptions.

Rules:

- The first usable screen should support search and local folder management paths.
- M1 may expose only the settings surface required to manage folders and indexing.
- Broader settings polish belongs to M2.
- Search, indexing status, and playback state should be represented explicitly in UI state.
- Keyboard behavior must preserve standard macOS text editing behavior.
- UI errors should be concise and actionable, with technical detail reserved for logs.
- The M1 app shell may combine SwiftUI content with AppKit titlebar controls when SwiftUI-only layout cannot match native macOS titlebar behavior.
- AppKit titlebar controls should coordinate through shared app state rather than duplicating sidebar state.
- The current M1 shell uses a fixed titlebar toggle and centered title.
- To achieve custom offsets for native traffic light buttons, the app uses a Proxy View reparenting pattern to extract buttons from the system's `_NSTitlebarContainerView` rather than fighting the private AppKit layout engine with frame or bounds overrides.
- Window dragging must be handled explicitly by the custom titlebar (`performDrag(with:)`) with `window.isMovableByWindowBackground` set to `false`. Relying on window background dragging causes conflicts with SwiftUI drag gestures on transparent views.
- Resizable dividers must use a custom `NSView` overlay to natively handle `resetCursorRects`, `NSTrackingArea`, and drag events (`mouseDown`/`mouseDragged`). SwiftUI's `.onHover` with `NSCursor.push()` is unreliable due to AppKit's continuous cursor rect evaluation, and SwiftUI's `DragGesture` can conflict with window event routing.
- Playback keyboard shortcuts are handled through a local AppKit key-down monitor and must not intercept keys while native text input is focused.
- Playback shortcut handling should route through shared playback state instead of duplicating command behavior in individual views.
- Further visual polish should remain incremental.

## 8. File Access and Sandboxing

Local subtitle and video file access is a core product requirement.

Rules:

- Folder selection must use native macOS folder selection behavior.
- Native file and Finder interactions may temporarily create AppKit,
  QuickLook, or Finder-related helper services. This is an acceptable cost for
  explicit low-frequency actions such as adding folders or future commands that
  reveal the current video in Finder.
- Helper-service optimization should focus on avoiding unnecessary helper
  creation during app launch, Search, Settings navigation, and playback, and on
  preventing helper-service accumulation after the app exits. The app should
  not replace standard macOS file panels or force-terminate system helper
  services only to reduce Activity Monitor process counts.
- Persistent access to selected folders must be designed before relying on it across launches.
- ADR-0004 disables App Sandbox for M1 local development and personal builds.
- Security-scoped bookmark handling is not required for M1 while App Sandbox is disabled.
- If sandboxing is later enabled, security-scoped bookmark handling must be documented and tested.
- The app must not silently scan folders that the user has not selected or otherwise authorized.

The final sandboxing and persistent file-access strategy may require an ADR.

## 9. Playback Architecture

Playback is a high-risk component.

Rules:

- M1 requires local file playback and timestamp seek only.
- ADR-0007 selects native-only playback.
- Playback code must not assume remote streams, local HTTP proxying, cache layers, or advanced subtitle rendering.
- Playback errors must be propagated in a form that the UI can present clearly.
- M1 playback must be embedded in the native app window.
- The first M2 ASS support step must allow an ASS search result to open the
  matched video and seek to the cue group's `start_ms` even before source ASS
  subtitle rendering exists.
- Search result previews are database-owned cue group projections. Playback
  subtitle rendering is source-file-owned when source subtitle rendering is
  implemented.
- The database cue projection must not be treated as a replacement ASS renderer.
- Source ASS subtitle rendering is deferred beyond the first ASS support step.
- Selecting or bundling a dedicated ASS renderer dependency must be documented
  before implementation because it can affect native dependencies, packaging,
  signing, and font behavior.
- The current playback route must always use the project-owned native backend.
- The active native macOS app must not link against, initialize, or fall back to `libmpv`.
- The native backend uses FFmpeg demuxing, user-selectable hardware, software,
  or automatic video decode mode, native display, FFmpeg audio decode, and
  `AVAudioEngine` output.
- Hardware decode uses VideoToolbox.
- Software decode uses FFmpeg software decoders and initially converts decoded
  frames to BGRA with `libswscale` before display.
- Software decode may automatically recycle the initial software playback
  session once after the first target frame has been displayed. This is a
  targeted mitigation for first-session dirty allocator pressure observed with
  high-resolution software AV1 decode.
- Automatic software session recycling must preserve the user's selected
  software decoder parallelism, must not use Metal YUV as the primary mitigation
  for this issue, must not recurse, and must not publish a transient pause or
  `0` timestamp to the UI.
- Automatic decode should prefer VideoToolbox and may fall back to software
  decode when hardware setup is unavailable.
- The next Metal YUV iteration should be scoped to software-decoded frame
  compatibility. The VideoToolbox hardware decode display path must remain on
  the existing hardware path unless a separate decision expands that scope.
- The app should query current-device VideoToolbox hardware decode support once at startup or before folder scanning, because codec support differs across Apple Silicon generations such as M1 and M4.
- Folder scanning should perform fast media-file native compatibility inspection using only stream presence, codec names, and current-device hardware decode support. Scanning must not decode frames, start a player, or perform heavy disk reads for compatibility inspection.
- The initial video codec candidates for fast native compatibility inspection are H.264, HEVC, VP9, and AV1, filtered by current-device VideoToolbox hardware decode support.
- Fast video compatibility inspection should use video codec support first. If no video stream exists but an audio stream exists, the same media-file profile model should allow native audio-only candidates as audio playback support evolves.
- Native compatibility metadata is a media-file property. It must not depend on `srt_path` as a unique key or on exact subtitle-to-video filename matching.
- If a native media file fails during real playback, the app should surface the native failure and may update the media-file profile so the failure reason is available for diagnostics.
- Full playback verification may still inspect actual decoder output when debugging the native backend, but that verification is not part of the fast folder-scan preselection path.
- The native display path should move toward a shared Metal YUV renderer for both hardware `CVPixelBuffer` frames and software-decoded FFmpeg `AVFrame` planes.
- Unsupported color layouts, bit depths, ranges, chroma layouts, or frame strides must produce explicit native failure reasons rather than silent incorrect rendering.
- Native timestamp seek should first try the selected video stream and then fall back to a global seek before treating seek setup as a native failure.
- Native seek state updates must not publish a transient `0` timestamp while a target seek is being prepared.
- The playback UI hosts a singleton render container owned by the playback player; fullscreen must move that same container rather than creating an independent render view.
- Playback fullscreen uses a borderless Theater Mode window and must not call the app window's system Full Screen transition.
- The Theater Mode window must use an app-level window level and must not use `screenSaver` or other system-overlay window levels that can cover the Cmd-Tab app switcher.
- Closing fullscreen, hiding the Playback Inspector, switching away from Search, closing the main window, or terminating the app must clean up the fullscreen window.
- Playback controls in the inspector and fullscreen overlay should share the same playback view model and feedback overlay model.
- Fullscreen chrome visibility and cursor hiding are owned by the fullscreen manager, not by individual SwiftUI playback control views.
- Entering fullscreen must suppress the initial hover event generated by the newly displayed fullscreen window so controls and the cursor remain hidden until real user activity occurs.
- Cursor hide and unhide calls must remain balanced when entering, exiting, or cleaning up fullscreen.
- If the app resigns active while playback fullscreen is active, Theater Mode must be suspended by hiding the fullscreen window and restoring the previous presentation options.
- If the app becomes active after such a suspension, Theater Mode should be restored using the existing singleton render container rather than recreating backend render state.

## 10. Dependency Management

Dependencies should be introduced conservatively.

Rules:

- Prefer platform APIs and small focused dependencies over broad frameworks.
- Any dependency that affects playback, database access, sandboxing, packaging, or signing must be documented before adoption.
- Dependencies that require bundled native binaries, special signing, or notarization handling require explicit review.
- Package manager and build tooling choices must be documented in or alongside the native app project.

## 11. Logging and Diagnostics

Logging should support debugging without exposing unnecessary personal data.

Rules:

- Logs may include technical diagnostics for indexing, parsing, database, search, playback, and UI errors.
- Logs must not include credentials, tokens, or authentication headers.
- Logs should avoid dumping full user file trees.
- User paths may be logged when necessary to debug local file behavior, but broad recursive listings should be avoided.
- User-facing errors should be shorter and less technical than diagnostic logs.

Recommended error categories:

- File access.
- Subtitle parsing.
- Video matching.
- Database.
- Search.
- Playback.
- UI state.

## 12. Credential and Secret Handling

The early native rewrite should not require stored credentials.

Rules:

- Do not introduce credential storage for M1.
- Do not store passwords, tokens, API keys, or authentication headers in plain text.
- If future features need credentials, prefer macOS Keychain.
- Credential handling requires documentation before implementation.
- Secrets must not be written to Git-tracked files or logs.

## 13. Configuration

Local configuration should remain minimal in M1.

Expected M1 configuration:

- Selected local subtitle folders.
- Indexing state needed to support refresh behavior.
- Window or section persistence only if practical.

Rules:

- Configuration must be local to the user's machine.
- Configuration storage format must be documented before it becomes hard to migrate.
- Configuration should not duplicate large indexed subtitle content outside the database.

## 14. Legacy Flutter Reference

The archived Flutter implementation may be used as a reference, but it is not active code.

Rules:

- Do not import active Flutter dependencies into the native app.
- Do not assume archived database compatibility without a documented database strategy.
- Useful behavior from the archived implementation should be translated into native architecture deliberately.

## 15. ADR Requirements

The following decisions require ADRs before production implementation depends on them:

- Final playback engine.
- Sandboxing and persistent folder access strategy, if non-trivial.
- Direct compatibility with or migration from the archived Flutter database.
- Any destructive or hard-to-reverse schema change.
- Any remote service, sync, or network-backed storage feature.
- Raising the minimum supported macOS version.
