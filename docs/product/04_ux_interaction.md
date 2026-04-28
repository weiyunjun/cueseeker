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
Playback Inspector opens or updates
Video plays at matching timestamp
Collapse Playback Inspector when not needed
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

Search focus behavior:

- User-initiated app commands should clear Search field focus.
- Selecting a search result should clear Search field focus.
- Clicking App-owned expand or collapse buttons should clear Search field focus.
- Future App-owned feature buttons should clear Search field focus by default.
- Selecting another sidebar section should clear Search field focus.
- Clicking anywhere in the Playback Inspector should clear Search field focus.
- System-level app switching should not intentionally clear Search field focus.
- Returning to the app after backgrounding should preserve the Search field focus state when AppKit preserves the first responder.
- Double-clicking the titlebar to resize the window should not intentionally clear Search field focus.
- Clicking native traffic light controls should not intentionally clear Search field focus.

## 4. Result Selection

When the user selects a result:

- The selected row visually turns into a solid accent color (e.g., blue) with white text, overriding the default separator lines.
- The app should remain in Search and open or update the Playback Inspector.
- The Playback Inspector should expand automatically if it is collapsed.
- Playback should start at or near the matching timestamp.
- If the same video is already open, the app should seek instead of reopening when practical.
- If the video file is missing, the app should show a clear error.
- Selecting a different result should switch video or seek within the current video and auto-play.

## 5. Visual Feedback and Hover

- **Sidebar**: The selected sidebar item uses a solid accent background with white text. Sidebar items do not have hover effects.
- **Titlebar Buttons**: Toolbar toggle buttons use a subtle gray background on hover to indicate interactivity.
- **Search Results**: Interactive result rows emphasize the selection state over hover, relying on progressive padding and a strong blue selection card.

## 5. Playback Interaction

M1 playback interaction should be minimal.

Required interactions:

- Auto-play after selecting a result.
- Toggle play/pause by clicking the embedded video.
- Seek.
- Jump from search result to timestamp.
- Pause playback when the Playback Inspector is collapsed.
- Pause playback when switching from Search to Settings or another top-level section.
- Preserve the current selected result when the Playback Inspector is collapsed.
- Do not automatically resume playback when the Playback Inspector is reopened.

Keyboard interactions should not interfere with text input.

Accepted M1 behavior:

- Selecting a result calls playback immediately.
- Re-selecting a timestamp in the same video should use seek rather than reloading the file.
- The embedded video view is always inside the app window.
- Normal result preview should use the Playback Inspector instead of dedicated playback-page navigation.
- External player windows are not acceptable for the core workflow.

M2 playback interaction model:

- Playback should expose explicit controls for the actions the user can perform from the video area.
- Playback should include progress and seek interaction suitable for reviewing subtitle context.
- Playback actions should provide clear visual feedback, such as a lightweight operation HUD or animation when the user plays, pauses, seeks, or triggers another command.
- Playback buttons, progress controls, click interactions, and keyboard shortcuts should dispatch through the same underlying playback command model.
- Playback fullscreen should fullscreen the video experience itself, not the full app shell.
- Playback fullscreen should use an independent theater-style fullscreen window and return the embedded video to the Playback Inspector when closed.
- Entering or exiting playback fullscreen must not create a second playback render container or duplicate backend render state.
- Entering playback fullscreen should immediately hide the playback operation controls and mouse cursor once, regardless of whether the controls were visible before fullscreen.
- In playback fullscreen, the playback operation controls and mouse cursor should hide after 3 seconds without mouse or click activity.
- In playback fullscreen, only mouse or click activity should reveal the playback operation controls and cursor; keyboard playback shortcuts should not reveal them.
- Theater Mode should hide while the app is inactive so the visible UI matches the active foreground app.
- Theater Mode should stay below system switchers and overlays such as Cmd-Tab.
- The progress bar and its enlarged hit area are named the `Timeline Zone`.
- The button row below the progress bar is named the `Transport Controls Zone`.
- Together, the `Timeline Zone` and `Transport Controls Zone` form the `Playback Operation Zone`.
- Mouse clicks in the `Playback Operation Zone` should control only the targeted playback control and must not fall through to video-surface play or pause toggling.
- Hovering or dragging the `Timeline Zone` should not change the vertical position of the `Playback Operation Zone`.
- Playback speed selection should use an app-drawn upward menu that stays within the playback controls surface.
- The speed menu should appear from hover over the speed control instead of requiring an arrow button.
- The speed menu should not have a separate show or hide animation.
- The speed button's hover area and click area should be identical and should match the speed menu width.
- The speed menu should appear only when hovering over the speed button area.
- The speed menu should disappear only after the pointer leaves the combined rectangular region whose top edge is the speed menu top edge and whose bottom edge is the speed button bottom edge.
- Keyboard shortcuts in fullscreen should not reveal the playback operation controls.
- The subtitle button should toggle the current player's subtitle visibility when the playback engine exposes a subtitle track or subtitle display state.
- Playback interaction design should remain focused on subtitle context review, not a full media-player feature set.

Current M2 implementation:

- Playback fullscreen uses a Theater Mode window and returns the same playback render container to the Playback Inspector when closed.
- Fullscreen playback hides the controls and cursor immediately on entry and again after 3 seconds of inactivity.
- Fullscreen playback reveals controls and cursor from mouse or click activity, not from keyboard shortcuts.
- Theater Mode suspends during app deactivation and restores on app activation without recreating the playback render context.
- The Theater Mode window level allows Cmd-Tab and other system overlays to remain visible above playback fullscreen.
- Playback controls and keyboard shortcuts share the same playback command state through the playback view model.
- Shortcut and control actions show transient feedback overlays for subtitle visibility, play/pause, relative seek, volume, and speed.
- The visible playback speed menu offers `0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `1.75x`, and `2.0x`.
- The speed button hover area, speed button click area, and speed menu width are aligned to the same horizontal bounds.
- Keyboard shortcuts adjust speed in `0.25x` steps and are clamped to the same `0.5x` through `2.0x` range as the playback controls.
- The previous Flutter shortcut model was used as a reference, but the native M2 map intentionally changes subtitles to `C`, removes the bottom-mask shortcut, and changes speed adjustment to `Shift+,` and `Shift+.`.

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

M2 keyboard shortcut model:

- The shortcut model should define commands, default key bindings, focus scope, and conflict rules before implementation.
- Search text editing must keep standard macOS editing behavior.
- Playback shortcuts should trigger the same playback commands used by visible playback controls.
- Shortcut handling should not duplicate playback state transitions separately from the playback interaction model.
- The native menu bar should expose relevant commands so keyboard shortcuts are discoverable through standard macOS menus where practical.
- Playback shortcuts should be active only when a playback result is selected, the playback interface is visible, and editable text input is not focused.
- Read-only selectable text in playback metadata should not suppress playback shortcuts.
- `C` should show or hide subtitles.
- `F` should enter or exit playback fullscreen.
- `Space` should toggle play or pause.
- `Left Arrow` and `Right Arrow` should seek backward or forward by 5 seconds.
- `Up Arrow` and `Down Arrow` should adjust volume by 5 percentage points.
- `Shift+,` and `Shift+.` should decrease or increase playback speed by 0.25x.
- Playback shortcut commands should show lightweight feedback overlays for subtitle visibility, play or pause, relative seek, volume, and speed changes.

## 9. Persistence

The app should remember:

- Configured local folders.
- Window size and maximized state.
- Last selected app section if practical.
- Sidebar collapsed or expanded state.
- Playback Inspector width and visibility.

The app should not surprise the user by losing local configuration after restart. The structural layout (Sidebar, Inspector) persistence is globally bound to the AppShell, natively supporting future modules like Favorites.
