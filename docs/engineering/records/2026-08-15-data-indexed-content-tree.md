# Requirement

- `docs/human/requirements/20260815-Feature-Data Indexed Content Management.md`
- `docs/human/design/UI Design System.md`

# Scope

Add the first Data Workbench surface for presenting real indexed content as a
macOS-style tree. This stage includes database loading and transient
expand/collapse interaction only; editing and context menus remain excluded.

# Architecture

- Product data semantics stay in `CueSeekerCore`. The read-only Data reader
  calls the existing Library presentation query for the authoritative folder,
  object, and ordering snapshot, then resolves stable folder IDs and expands
  each Library object with its active subtitle relationships.
- Platform presentation stays in SwiftUI through an explicit four-level Data
  layout, shared row and object-group components, and existing Workbench tokens
  and scrollbar infrastructure.
- Data expansion state belongs to the mounted page. Returning from another page
  reloads the default state, while selecting the already-active Data route is a
  no-op.
- No second folder eligibility rule, folder sorting path, Rust boundary,
  recursive tree engine, UI sorting, persistence layer, edit command, or empty
  context menu was added.

# Steps

1. Added the indexed-content tree reader for configured, available roots. Its
   folders, objects, and order come directly from the persisted Library
   presentation; Data-specific loading only resolves stable folder identity and
   all active subtitles for those Library objects.
2. Added Data routing between Library and Shiori and excluded Data from Back and
   playback-return destinations.
3. Added the token-driven Data page, explicit hierarchy composition, wrapped
   names, per-level icons, row Hover, object Dividers, and shared vertical
   scrollbar.
4. Added database grouping and ordering coverage plus route persistence,
   active-route no-op, and Back-state coverage.
5. Added the user-visible milestone to the changelog without changing the
   owner-controlled requirement or UI Design System documents.
6. Corrected the initial implementation so raw `library_folders` and unstable
   `folder_order` values no longer form an independent Data projection, and
   normalized root labels without leading or trailing separators.

# Verification

- `swift test --filter IndexedContentDatabase` passes 1 test, including a
  conflicting `folder_order`, an empty folder, a video-only folder, exact
  equality with the Library folder snapshot, and root separator normalization.
- `swift test --filter workbenchLayoutState` passes 9 tests.
- `swift test --filter workbenchRouteEnablesBackOnlyForSecondaryPages` passes 1
  test.
- `swift build -c release --product CueSeeker` passes.
- The established nonparallel full-suite command completed 1004 tests with the
  two previously recorded Shiori refresh timing issues in
  `showCueGroupInvalidationIsScopedToMountedShiori` and
  `shioriTableStartsAtTopAfterPanelRemount`; each issue reproduces when run
  alone, while all Data coverage passes.
- A real Debug E2E launch at `1429 × 821` loaded the current CueSeeker database,
  omitted the seven raw folders absent from Library, displayed the two K-On!
  seasons adjacently in Library order, and rendered the root label as
  `Volumes/Samsung/影视` without a trailing separator.
- Debug E2E captures confirmed that clicking active Data leaves the expanded
  frame byte-identical, while leaving and returning restores the default frame
  byte-identically.
- Side-by-side visual comparison against the approved direction confirmed the
  hierarchy, density, wrapping surface, Divider origin, Hover surface, and
  far-right scrollbar alignment.

# Outcome

Data now presents the Library's authoritative folder and object snapshot with
the approved hierarchy and transient interaction model. It retains stable IDs
and all active subtitle relationships for later context-menu editing without
introducing that future behavior now.

# Follow-ups

- After owner visual acceptance, the owner will record finalized Data rules in
  `docs/human/design/UI Design System.md`.
- Context-menu editing requires its own approved requirement scope.
