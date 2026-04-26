# UX Interaction

Status: Draft

## 1. Core Workflow

The primary workflow is:

```text
Open app
Add or confirm local subtitle folder
Index subtitles
Search text
Review results
Click result
Playback page opens
Video plays at matching timestamp
Return to search when done
```

## 2. First Launch

On first launch, if no folders are configured:

- The app should make it obvious that a local subtitle folder must be added.
- The user should be able to add a folder without navigating through unnecessary screens.
- The app should explain indexing status only when needed.

## 3. Search Interaction

Search should feel immediate.

Expected behavior:

- Typing updates results after a short debounce.
- Empty search shows an empty or guidance state.
- Invalid search syntax should not crash the app.
- Search results should not flicker unnecessarily.
- Repeating the same query should not trigger expensive work without reason.

## 4. Result Selection

When the user selects a result:

- The app should navigate from the search results page to a dedicated playback page.
- Playback should start at or near the matching timestamp.
- If the same video is already open, the app should seek instead of reopening when practical.
- If the video file is missing, the app should show a clear error.
- Returning from the playback page should stop playback and return to the current search results.

## 5. Playback Interaction

M1 playback interaction should be minimal.

Required interactions:

- Auto-play after selecting a result.
- Toggle play/pause by clicking the embedded video.
- Seek.
- Jump from search result to timestamp.
- Return from playback to search.
- Stop playback when returning to search.

Keyboard interactions should not interfere with text input.

Current M1 behavior:

- Selecting a result calls playback immediately.
- Re-selecting a timestamp in the same video should use seek rather than reloading the file.
- The embedded video view is always inside the app window.
- External player windows are not acceptable for the core workflow.

## 6. Indexing Interaction

Indexing should communicate progress without blocking the whole app unnecessarily.

Expected behavior:

- Show indexing state.
- Show completion state.
- Show errors for unreadable folders or files.
- Allow the user to continue using existing indexed data when possible.

## 7. Error Handling

Errors should be understandable and actionable.

Error messages should answer:

- What failed?
- What can the user do?
- Is the rest of the app still usable?

Technical details may be available in logs, but should not overwhelm the main UI.

## 8. Keyboard Behavior

Keyboard behavior should follow native macOS expectations.

Initial expectations:

- Standard text editing shortcuts work in search fields.
- Escape should dismiss transient UI or unfocus search when appropriate.
- Playback shortcuts should apply only when playback focus or context makes sense.
- Global shortcuts should be documented before implementation.

## 9. Persistence

The app should remember:

- Configured local folders.
- Window size if practical.
- Last selected app section if practical.
- Sidebar collapsed or expanded state if practical.

The app should not surprise the user by losing local configuration after restart.
