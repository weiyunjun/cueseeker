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

Current M1 structure:

```text
Native titlebar
Sidebar navigation
Main content area
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

Current shell direction:

- Traffic lights, sidebar toggle, and the current section title belong to the titlebar.
- The sidebar toggle should stay in a fixed titlebar position near the traffic lights.
- The current section title should remain centered in the titlebar.
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

Current M1 search presentation:

- The search field is a custom SwiftUI control with a leading magnifying-glass icon and a taller input height.
- Search results are shown as a list.
- Selecting a search result navigates to a dedicated playback page instead of keeping a split detail panel open.
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

## 6. Playback Area

The playback area appears after the user selects a result.

Current M1 layout:

- Selecting a result opens a dedicated playback page.
- The playback page contains, in order: a top action row, embedded video, subtitle text, start time, video path, and subtitle path.
- The top action row currently contains the back action.
- Returning from the playback page stops playback.
- Clicking the embedded video toggles play/pause.

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
