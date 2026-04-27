# UI Design

Status: Draft

## 1. Design Direction

SubFinderX should feel like a focused native macOS desktop tool.

The interface should prioritize:

- Fast search.
- Dense but readable result lists.
- Clear local folder management.
- Immediate video context after selecting a result.
- Native macOS interaction patterns.

The app should avoid marketing-style layouts, decorative hero sections, and unnecessary visual complexity.

## 2. Main Window

The main window should be a persistent work surface.

Accepted M1 structure:

```text
Native titlebar
Sidebar navigation
Search Results Pane
Playback Inspector
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights, sidebar toggle, and the current section title belong to the titlebar.
- The sidebar toggle should stay in a fixed titlebar position near the traffic lights.
- The Playback Inspector Toggle should stay in a fixed titlebar position on the right side.
- The current section title should remain centered in the titlebar.
- Traffic lights are shifted 12pt to the right and vertically centered within the custom titlebar. To achieve this without fighting AppKit's native layout engine during window resizing, the standard window buttons (`.closeButton`, `.miniaturizeButton`, `.zoomButton`) are reparented (extracted from their system container and placed into a custom transparent `NSView` proxy). This preserves native hover effects and accurate hit testing.
- The native `NSWindow` title visibility is hidden in windowed mode but temporarily restored during full-screen transitions, ensuring the system drop-down title bar is fully functional.
- The `NSWindow` title dynamically tracks the active sidebar section to ensure correct contextual labeling in the full-screen drop-down title bar.
- To prevent UI artifacts when exiting full-screen mode, the native title visibility is hidden in the `windowWillExitFullScreen` delegate callback before the transition animation begins.
- The titlebar should use a slightly darker gray than the main content background.
- A thin gray divider should separate the titlebar from the content below.
- The titlebar should visually sit above the sidebar.
- The sidebar should use a quiet background and a right-side divider, not a heavy shadow.
- The current titlebar/sidebar implementation is an M1 iteration, not final polish.

## 3. Sidebar

The sidebar should provide high-level navigation.

Initial sections:

- Search.
- Settings.

Future sections:

- Favorites.

The sidebar should remain visually quiet and should not compete with search results or playback.

Current M1 behavior:

- The sidebar can be expanded or collapsed through the titlebar toggle.
- When expanded, the sidebar is a single visual navigation region under the titlebar.
- When collapsed, the main content receives a left inset so content does not start underneath the traffic lights and titlebar toggle.
- Sidebar edge treatment should remain subtle. A gray divider is preferred over a drop shadow for the current M1 shell.

## 4. Search View

The search view is the primary screen.

Required elements:

- Search input.
- Indexing status when relevant.
- Search result list.
- Empty state when no query or no results exist.
- Error state when search or database access fails.

The search input should stay easy to access.

Accepted M1 search presentation:

- The search field is a custom SwiftUI control with a leading magnifying-glass icon and a taller input height.
- Search results are shown as a list.
- Selecting a search result opens or updates the Playback Inspector without leaving Search.
- Search results currently use larger text and highlight query matches with a yellow background.
- Search result visual polish is still incomplete and subject to further iteration.

## 5. Search Result Row

Each result row should be compact and scannable.

Current M1 row content:

- Subtitle text as the primary content.
- Query match highlighting.
- Subtitle file name.

Rows should have stable height or predictable dynamic height. Long subtitle text should not break the layout.

The row should remain fully clickable. Video file name and timestamp are not currently shown in the search result row.

## 6. Playback Inspector

The Playback Inspector is the right-side playback and result-detail panel in the Search workspace.

Required content:

- Embedded video.
- Subtitle text.
- Start time.
- Video path.
- Subtitle path.

Behavior:

- Selecting a result opens or updates the Playback Inspector.
- Selecting a result expands the Playback Inspector when it is collapsed.
- Clicking the embedded video toggles play/pause.
- Collapsing the Playback Inspector pauses playback and hides the panel.
- Collapsing the Playback Inspector does not clear the current selected result.
- Reopening the Playback Inspector does not automatically resume playback.
- Switching from Search to Settings or another top-level section pauses playback without stopping it.

Layout:

- The Playback Inspector appears on the right side of the Search workspace.
- The Playback Inspector is resizable by dragging its left edge.
- The sidebar width remains fixed according to the current shell behavior.
- The Search Results Pane width changes dynamically as the Playback Inspector width changes.
- The Search Results Pane must keep a usable minimum width.

Initial sizing guidance:

- Search Results Pane minimum width: `480pt`.
- Playback Inspector default width: `520pt`.
- Playback Inspector minimum width: `380pt`.
- Playback Inspector maximum width: available content width minus the Search Results Pane minimum width.

The Playback Inspector Toggle belongs in the titlebar at a fixed right-side position. It should conceptually match the sidebar toggle pattern while controlling the right-side inspector.

M1 does not require advanced visual effects.

## 7. Settings View

The settings view should allow local folder management.

Required elements:

- List of indexed folders.
- Add folder action.
- Remove folder action.
- Reindex action.
- Indexing status.

Settings should be functional and clear before they are visually refined.

## 8. Visual Style

Initial visual style should be restrained.

Preferred characteristics:

- Native macOS controls where practical.
- Clear spacing.
- Good text hierarchy.
- Minimal color dependence.
- Accessible contrast.
- No decorative gradients or unnecessary cards.
