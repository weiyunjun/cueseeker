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

Recommended structure:

```text
Sidebar
Main content area
Optional playback area
```

The main window should support:

- Resizing.
- Reasonable minimum size.
- Restoring previous size if practical.
- Native toolbar or sidebar behavior where appropriate.

## 3. Sidebar

The sidebar should provide high-level navigation.

Initial sections:

- Search.
- Settings.

Future sections:

- Favorites.

The sidebar should remain visually quiet and should not compete with search results or playback.

## 4. Search View

The search view is the primary screen.

Required elements:

- Search input.
- Indexing status when relevant.
- Search result list.
- Empty state when no query or no results exist.
- Error state when search or database access fails.

The search input should stay easy to access.

## 5. Search Result Row

Each result row should be compact and scannable.

Recommended content:

- Subtitle text as the primary content.
- Video name.
- Timestamp.
- Optional source context.

Rows should have stable height or predictable dynamic height. Long subtitle text should not break the layout.

## 6. Playback Area

The playback area appears after the user selects a result.

Initial layout options:

- Split view with search results on the left and video on the right.
- Inline playback panel below or beside the result list.

The selected approach should preserve the ability to continue searching while video is visible.

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

