# ADR-0005: Playback Fullscreen Lifecycle and RenderView Architecture

Status: Accepted, generalized by ADR-0006

ADR-0006 keeps the Theater Mode fullscreen rule but generalizes the concrete
render ownership from an `MPVRenderView` singleton to a playback render
container owned by the playback facade. The `libmpv`-specific crash analysis
below remains historical context for why fullscreen must move a stable backend
view instead of creating or destroying backend render state during fullscreen
transitions.

## Background

As part of the Playback Interaction Model implementation, we attempted to add True Fullscreen functionality to the embedded `libmpv` player. The requirement was to provide an independent fullscreen video experience (similar to professional players like IINA), rather than maximizing the entire App shell.

During implementation, we encountered severe, consistent application crashes (`Bad pointer dereference`, `IMKCFRunLoopWakeUpReliable`, and `_Block_release`) when entering or exiting the fullscreen state. 

Investigation revealed two deeply interconnected root causes:
1. **OpenGL Context Exclusivity vs. SwiftUI View Lifecycle**: `libmpv` strictly allows only one OpenGL render context per player. When moving the video view between the main window and a fullscreen window, SwiftUI's unpredictable layout passes would often destroy the `NSViewRepresentable`'s underlying `MPVRenderView`.
2. **Dangling Pointers in C-Callbacks**: When the view was destroyed, `libmpv`'s background rendering thread would occasionally fire an asynchronous UI update (`mpv_render_update_fn`). This callback captured the now-dead `MPVRenderView` pointer, leading to an immediate fatal crash on the Main Queue.
3. **Space Transition Conflicts**: Calling macOS's native `window.toggleFullScreen(nil)` on a throwaway window and then destroying it mid-animation (which takes ~0.8s) caused the Window Server and Input Method Kit (IMK) to crash due to conflicting state changes.

## Decision

To achieve a 100% crash-free and instant fullscreen experience, we adopt a dual-strategy architecture: **Singleton RenderView** and **Theater Mode**.

### 1. Singleton RenderView
We decouple the lifecycle of the OpenGL render view from SwiftUI.
- The `MPVPlayer` instance will **permanently own and retain** its `MPVRenderView` as a lazy property (`player.renderView`).
- `MPVRenderView` will never be deallocated as long as the player is alive.
- `NSViewRepresentable` wrappers in SwiftUI will merely *borrow* this singleton view by returning `player.renderView` in `makeNSView`.
- This guarantees that `libmpv`'s background threads will never encounter a dangling pointer, physically eliminating the `_Block_release` crashes.

### 2. Theater Mode (Instant Fullscreen)
We abandon the buggy macOS native `toggleFullScreen` animations for the video player.
- The `FullscreenVideoManager` will create a pure-black, borderless `NSWindow` matching the screen's exact dimensions.
- The manager will instantly display this window over the entire screen and programmatically hide the Menu Bar and Dock using `NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]`.
- The Theater Mode window must stay below system overlays, including the Cmd-Tab app switcher.
- Exiting fullscreen simply involves closing the window and restoring the presentation options.
- This bypasses all Space Transition animations, providing a 0-delay, native-feeling fullscreen experience that cannot crash the Window Server.

## Rationale

Attempting to synchronize the teardown of a C-based OpenGL context with SwiftUI's highly abstracted and lazy view garbage collection proved practically impossible and highly unstable. By making the render view immortal (Singleton) relative to the player, we eliminate the root cause of the memory access violations.

Furthermore, leveraging Theater Mode aligns with how professional macOS video players operate internally, offering a significantly faster and more stable user experience than standard Space transitions.

## Consequences

- The `MPVRenderView` must now hold an `unowned` reference to `MPVPlayer` to prevent retain cycles.
- SwiftUI's `PlaybackVideoView` must conditionally hide the `MPVRenderViewWrapper` when fullscreen is active to prevent SwiftUI from attempting to steal the view back from the fullscreen window.
- The `prepareOpenGL` method in `MPVRenderView` must be guarded (`guard !renderContextCreated`) to ensure the OpenGL context is initialized only once, even as the view moves between windows.
- Any future fullscreen controls must be implemented as a separate SwiftUI overlay (`PlaybackControlsOverlay`) hosted in the fullscreen window, floating above the native video view.
- Theater Mode must suspend when the app resigns active by hiding the fullscreen window and restoring presentation options, then restore the same fullscreen window and singleton render view when the app becomes active again.

Current implementation note after ADR-0006:

- The production app now moves a playback render container owned by the playback
  facade. That container may host either the native backend view or the `libmpv`
  fallback view.
- The fullscreen invariant remains the same: Theater Mode must move the existing
  backend view/container and must not create duplicate render state.
