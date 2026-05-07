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
- ADR-0010 supersedes the old borderless Theater Mode fullscreen mechanism and
  selects a dedicated playback `NSWindow` using AppKit Full Screen Space for
  playback fullscreen.
- ADR-0004 disables App Sandbox for M1 local development and personal builds.
- ADR-0009 selects `libass` as the only active ASS playback renderer and
  removes the previous native ASS renderer direction from production playback.

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
- The current M2 ASS support step adds ASS indexing, grouped cue search results,
  grouped result display, and click-to-playback behavior.
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
- M1 may expose only the settings surface required to manage folders, indexing,
  and decode mode.
- Broader settings polish belongs to M2.
- Search, indexing status, and playback state should be represented explicitly in UI state.
- The workbench must preserve separate invalidation domains for the Left
  Content Panel, central Playback Area, and Right Learning Panel. A state change
  in one domain must not require expensive derived state in another domain to be
  recomputed.
- A single broad observable object may coordinate workflows, but large SwiftUI
  views must not subscribe to unrelated high-frequency or high-cardinality state
  when a smaller store, value model, or binding can express the same UI
  responsibility.
- The workbench container should own layout coordination only. Library,
  Playback, and Search presentation views should receive scoped state so Search
  focus, Search results, playback clock updates, and side-panel resize gestures
  do not invalidate unrelated panels.
- Library presentation rows are derived indexed-resource state. They should be
  cached and rebuilt only when Library videos, Library grouping rules, Library
  collapse state, or Library ordering inputs change.
- Search presentation rows are derived query state. They should be cached and
  rebuilt only when the query, loaded search page, Search result grouping state,
  Search collapse state, or Search ordering inputs change.
- Side-panel collapse or expand must not destroy and recreate large list state.
  Prefer stable panel shells whose layout width, visibility, opacity, or hit
  testing changes without discarding the panel's current presentation model.
- If SwiftUI lazy stacks are used for large grouped lists, row models should be
  flattened when necessary so lazy rendering applies to individual headers and
  rows rather than to a single large group view that eagerly builds all children
  inside the group.
- Search field focus should be owned by the Search Panel presentation layer
  unless another documented command needs to coordinate focus. Focus changes
  must not be treated as Library or Playback state changes.
- Playback time exposed to SwiftUI controls should be rate-limited separately
  from the native playback clock so progress text and controls do not invalidate
  unrelated workbench UI at video-frame cadence.
- The embedded Playback Area's black video background, native video view,
  `AVSampleBufferDisplayLayer`, and source-faithful ASS overlay should be owned
  and laid out by the native playback render container. SwiftUI may size and
  clip the overall playback card, but it should not provide a separate black
  backing layer whose layout can get ahead of the native video layer.
- Native playback layout updates during workbench side-panel animations should
  disable implicit CALayer frame animations and synchronously lay out attached
  AppKit subviews where necessary so the video frame and black background remain
  visually locked together.
- Workbench actions that animate the video's available size must be serialized
  while the animation is active. This includes Library/Search panel toggles,
  titlebar double-click zoom, playback fullscreen enter/exit, the `F`
  fullscreen shortcut, and Escape-driven fullscreen exit. Direct divider drags
  remain a live resize interaction and are not part of this serialized command
  gate.
- Playback fullscreen and titlebar zoom transition gates must use AppKit's
  current resize-animation duration for the actual source and target window
  frames, such as `NSWindow.animationResizeTime(_:)`. They must not use a fixed
  guessed delay for fullscreen or window-zoom animation length.
- The main window should use `CueSeeker` as its top-level workbench identity.
  The old standalone `Search` AppShell label should be removed; Search is a
  right-side learning panel workflow.
- Settings belongs to the macOS app menu and an independent Settings window.
  Opening or focusing Settings must not mutate CueSeeker workbench pane state,
  selected result identity, or playback state.
- The Settings window may share app state for configured folders, indexing
  commands, indexing status, and decode mode, but its presentation state should
  not be stored inside Search Panel state.
- The CueSeeker workbench uses a player-first layout: Library on the left when
  expanded, embedded playback in the center, and a collapsible Search Panel on
  the right.
- The Search Panel is the collapsible auxiliary pane. Playback must not be
  treated as the collapsible auxiliary pane in the CueSeeker workbench.
- Collapsing the Search Panel must preserve playback state, selected result
  identity, and search context.
- Future side-panel work should preserve distinct responsibilities around
  playback: the Left Content Panel owns Library, Timeline, and Favorites-style
  known-content navigation, while the Right Learning Panel owns Search, Queue,
  and Learning Session-style active learning workflows.
- Library should be modeled as a Left Content Panel mode, not as AppShell
  navigation and not as Settings folder management.
- The fixed left titlebar control should collapse or expand Library, not a
  standalone AppShell sidebar.
- Library width should be resizable, with its first default width equal to its
  minimum width of `310pt`, `50pt` narrower than the previous fixed `360pt`
  Library width. User-adjusted Library width should persist as UI preference
  state.
- The first Library implementation should derive flat one-level folder groups
  from indexed playable video metadata. It should use Finder-like natural
  comparison for folder and video ordering, derive row display titles from the
  video's parent folder and sibling rank, and use indexed duration metadata for
  the right-side row duration.
- Library startup state must be hydrated from persisted indexed video metadata
  before the first visible main-window render when the local database is
  available. Asynchronous Library refreshes may reconcile or update existing
  rows, but they must not make a previously indexed Library appear empty or
  visibly loading after restart.
- Library folder collapse or expand state is current-session presentation state.
  It should not persist across app restarts. App startup, Library data refresh,
  and reindex completion should all present Library folder groups as collapsed.
- Clicking a Library video row should dispatch through the same playback open
  path used by Search-result playback, but should resolve its start timestamp
  from Library-only resume history before falling back to `0`.
- Library resume history is durable user state keyed by video identity. It
  should be read and written only for playback sessions opened from Library.
  Search-result playback must not read, write, or overwrite Library resume
  history.
- Reindexing a folder should invalidate Library and Search presentation for
  resources under that folder. After reindex completion, Library should be
  refreshed with all folder groups collapsed, and any active Search query should
  be rerun against the rebuilt index.
- If current playback is using a media file under a folder being reindexed, the
  app should stop or clear that playback before the reindex begins. This keeps
  playback state from referencing resource identities that are actively being
  rebuilt.
- Derived local index rows may be deleted, rebuilt, or marked stale, but
  durable user state that references those resources must remain separate.
  History, future favorites, queues, and learning-session records should show
  unavailable or unbound resource states when their current index binding is
  missing rather than being silently deleted.
- Queue and Learning Session state must not be hidden inside playback UI state
  alone if it becomes durable or cross-view behavior.
- Learning Session playback rules require product documentation before
  implementation because they affect playback state, keyboard behavior,
  persistence, and test coverage.
- Keyboard behavior must preserve standard macOS text editing behavior.
- UI errors should be concise and actionable, with technical detail reserved for logs.
- The M1 app shell may combine SwiftUI content with AppKit titlebar controls when SwiftUI-only layout cannot match native macOS titlebar behavior.
- AppKit titlebar controls should coordinate through shared app state rather
  than duplicating side-panel visibility state.
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
  creation during app launch, Search, opening or focusing Settings, and
  playback, and on preventing helper-service accumulation after the app exits.
  The app should not replace standard macOS file panels or force-terminate
  system helper services only to reduce Activity Monitor process counts.
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
- Playback code must not assume remote streams, local HTTP proxying, cache
  layers, or complete ASS subtitle renderer compatibility.
- Playback errors must be propagated in a form that the UI can present clearly.
- M1 playback must be embedded in the native app window.
- ASS playback rendering must use the `libass` source-faithful overlay. The
  native ASS renderer and ASS Lite fallback must not be reachable from the
  active playback route.
- Settings must not expose an ASS renderer selector while CueSeeker has a
  single supported ASS renderer.
- Search result previews are database-owned cue group projections. Playback
  subtitle rendering is source-file-owned.
- The database cue projection must not be treated as a replacement ASS renderer.
- Search projection may omit non-searchable visual-effect details from FTS, but
  playback rendering must preserve timed source ASS events, including
  `Effect=fx`, `\p` vector drawing, clipping, karaoke, blur, alpha, transforms,
  and short-duration effects.
- ASS parsing and renderer preparation must not run synchronously on the search
  result click path.
- Video open, video seek, selected-row UI state, and playback controls must not
  wait for ASS parsing or rendering.
- ASS rendering should be coordinated through an asynchronous render coordinator
  with cancellation and cache invalidation keyed by source file identity.
- The `libass` render source must carry explicit font-resource context. A
  selected ASS subtitle is not enough by itself: the playback path must also
  preserve the matched video identity and any discovered renderer font
  directory or cache directory needed by the `libass` session.
- `libass` must receive the same font-resource context for both full-source ASS
  loading and indexed render-segment loading. Segment optimization must not
  drop access to fonts that would have been available when rendering the full
  source file.
- CueSeeker must not assume that `libass` can read fonts from the matched video
  container automatically. Matroska or other container font attachments must be
  extracted or otherwise materialized into a renderer-owned font resource
  directory before they can be passed to `libass`.
- Adjacent external font folders are part of the ASS playback resource model.
  Discovery must be explicit and bounded to the selected subtitle and matched
  video location, such as conventional sibling font directories, and must not
  become a broad recursive scan of unrelated user folders.
- External ASS font-resource preparation is an indexing-stage responsibility.
  Playback may read a prepared manifest and pass an existing font directory to
  `libass`, but it must not inspect media containers, copy font folders, extract
  attachments, or mutate the active font directory after subtitle loading has
  started.
- The prepared ASS font-resource manifest is the single source of truth for
  external font resources on a playback click. If the manifest is absent or
  failed, playback must not start background font preparation that can later
  change the rendered font during the same subtitle load.
- ASS `[Fonts]` embedded resources remain source-file-owned and should continue
  to rely on `libass` embedded-font extraction. External font folders and video
  attachments are additional renderer inputs, not a replacement for source ASS
  content.
- Source-faithful ASS rendering must avoid rebuilding presentation payloads when
  the renderer reports an unchanged visual frame. Static subtitle intervals
  should reuse the previous cropped subtitle surface and layer contents instead
  of repeatedly compositing RGBA data or replacing `CALayer.contents`.
- Database cue timing is consistent with the source ASS event timing and may be
  used to identify the selected cue window and nearby cue windows before ASS
  render preparation finishes.
- Source ASS lookup remains required for exact render payload, including style,
  override-tag, vector drawing, `Effect`, and other formatting details.
- Time-windowed or segmented ASS preparation is the preferred future
  optimization for large ASS files. Full-file preparation may remain a fallback,
  but it should not be the only long-term render preparation path.
- Large ASS render segmentation must be done during indexing, not on the
  result-selection or playback-render path. The playback path may query a
  precomputed render segment by source identity and timestamp.
- ASS render segmentation should be enabled for `.ass` files at or above
  256 KB. Segments should use complexity-aware windows: low-complexity regions
  may be widened up to 60 seconds, while dense effect regions should shrink
  toward 5-10 second windows according to dialogue count, byte count, override
  tags, animation, vector drawing, clipping, and peak active render cost.
- Complexity-aware segmentation must be a conservative source-preserving
  optimization. The segmenter may change only which overlapping source events
  are packaged into each indexed render script; it must not rewrite event
  timing, style names, override tags, drawing commands, layer values, margins,
  or source order to reduce cost.
- The segmentation budget should optimize for stable playback memory and
  click-to-subtitle latency, not for the smallest possible number of database
  rows. Small ASS files below the threshold should keep the full-file path to
  avoid segment-switch overhead and lost renderer cache locality.
- Large ASS render segments stored in SQLite must preserve complete render
  context for the segment: script metadata, styles, event format, original event
  timestamps, original event text, layer values, and source order for every
  event overlapping that segment.
- Large ASS render segments are a derived cache. They must be rebuilt when the
  source subtitle file size or modified time changes, and stale segment rows
  must be removed with the owning subtitle file.
- The ASS render-segment cache must carry an algorithm version so segmentation
  strategy changes invalidate older derived rows instead of reusing stale
  windows for unchanged subtitle files.
- The dedicated ASS renderer must be separate from the SQLite search layer and
  from the native video decoder. It should receive playback clock updates and
  present overlay output through the playback render container.
- ASS timing-source consolidation is deferred until the workbench invalidation
  boundaries are stable. Any future change to ASS playback timing must preserve
  immediate selected-row updates, immediate video open or seek, and prompt
  subtitle source loading after Search result selection.
- Bundling and updating `libass` remains an explicit playback dependency
  concern because it affects packaging, signing, license review, font discovery,
  and font fallback behavior.
- Font-resource extraction or discovery caches are derived playback resources.
  They must be invalidated when the matched video, subtitle source, or extracted
  attachment set changes, and they must not become the source of truth for
  subtitle search or cue grouping.
- The current playback route must always use the project-owned native backend.
- The active native macOS app must not link against, initialize, or fall back to `libmpv`.
- The native backend uses FFmpeg demuxing, user-selectable hardware, software,
  or automatic video decode mode, native display, FFmpeg audio decode, and
  `AVAudioEngine` output.
- The native backend must use the same bounded read-ahead behavior for all
  path-based media sources. Local files, mounted NAS volumes, and future
  WebDAV-style file access must not be split into separate playback quality
  classes just because macOS presents mounted network storage as a local path.
- Native read-ahead is session-scoped and must be cleared on open, close, and
  seek/session replacement. It must not copy or stage whole media files into a
  temporary local directory.
- Native read-ahead should queue compressed FFmpeg packets, not decoded video
  frames or decoded audio frames, unless a later design explicitly changes the
  memory model.
- Native read-ahead starts playback immediately with a 0 second startup packet
  waterline, targets 10 seconds of queued packet media time during steady
  playback, and caps queued compressed packet data at 64 MB.
- Native read-ahead should remain a simple fixed-watermark policy until field
  evidence justifies adaptive behavior. It must not automatically raise startup
  waterlines after repeated rebuffer events without a documented design update.
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
- Playback fullscreen should use a dedicated playback `NSWindow` that enters
  and exits AppKit Full Screen Space with `toggleFullScreen(_:)`. The main
  CueSeeker workbench window must not enter fullscreen for the playback
  fullscreen command.
- Playback fullscreen should move the singleton native render container into
  the dedicated playback window before entering fullscreen, then return that
  same container to the embedded Playback Area after exiting fullscreen.
- AppKit should own the fullscreen Space transition, including Dock, menu bar,
  desktop, wallpaper, Mission Control, app switching, and system overlay
  behavior. CueSeeker must not manually emulate standard playback fullscreen
  with an always-on-top borderless overlay window.
- Playback fullscreen state should be coordinated through AppKit fullscreen
  lifecycle callbacks rather than fixed guessed transition delays. If custom
  fullscreen animation is later required, use AppKit's custom fullscreen
  delegate callbacks and the system-provided duration.
- Closing fullscreen, hiding the CueSeeker workbench, switching to another
  future top-level workspace, closing the main window, or terminating the app
  must clean up the fullscreen window.
- Playback controls in the embedded Playback Area and fullscreen overlay should
  share the same playback view model and feedback overlay model.
- Fullscreen chrome visibility and cursor hiding are owned by the fullscreen manager, not by individual SwiftUI playback control views.
- Entering fullscreen must suppress the initial hover event generated by the newly displayed fullscreen window so controls and the cursor remain hidden until real user activity occurs.
- Cursor hide and unhide calls must remain balanced when entering, exiting, or cleaning up fullscreen.
- App switching while playback fullscreen is active should rely on AppKit Space
  behavior and must not leave a custom overlay window visually covering other
  applications.

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
