# 版本
main

# 需求描述
几乎所有前端交互操作都会导致刷新完整界面，这导致了非常多的bug和性能问题。基于这个现状，应该建立全局的刷新影响范围契约，以及精确到组件的刷新影响范围契约，从而大幅度减少类似问题。
详细改动见# UI文档改动。

# UI文档改动
**1. `### 2.16 Row Action Menu` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Not specified in image

### 2.17 Table Row
```

修改后

```md
#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Row action menu overlay.

Allowed invalidation:
- Menu open / close may update only the active row, active cell trigger, menu overlay, and menu dismiss monitor.
- Menu item hover may update only the hovered menu item.
- Menu item click may execute only the explicit command selected by the user.

Forbidden invalidation:
- Right click and menu hover must not change row selection.
- Right click and menu hover must not reload table rows, rebuild table snapshots, or start background row hydration.
- Row action menu state must not invalidate SearchView, ShioriView, Library, Playback Page, or Playback render host.

### 2.17 Table Row
```

**2. `### 2.19 Row Selection Checkbox` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Not specified in image

### 2.20 Interactive Text Cell
```

修改后

```md
#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table selection layer.

Allowed invalidation:
- Row checkbox toggle may redraw only the changed row checkbox state, changed row selection state, header checkbox state, Count Summary, and batch action visibility.
- Header checkbox toggle may redraw only rows whose selection state changed and the selection summary region.

Forbidden invalidation:
- Checkbox toggle must not rebuild row data, reload table snapshots, run continuous row loading, or refresh Search/Shiori/Library data.
- Checkbox hover, focus, and pressed state must not invalidate Playback, App Sidebar, App Topbar, or unrelated workbench surfaces.

### 2.20 Interactive Text Cell
```

**3. `### 2.29 Library Card Context Menu` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Menu Items: pointer

### 2.30 Empty Hint
```

修改后

```md
#### Cursor
Menu Items: pointer

#### Refresh Scope
Owner:
- Library card context menu overlay.

Allowed invalidation:
- Right click may update only the triggering card open state, menu overlay, menu position, and menu dismiss monitor.
- Menu item hover may update only the hovered menu item.
- Confirmed menu commands may update only the affected library item, folder, or watch-state summary.

Forbidden invalidation:
- Right click and menu hover must not trigger card left click, playback open, library snapshot reload, or playback render invalidation.
- Menu measurement and clamp positioning must not rebuild the Library grid or refresh Search/Shiori/table surfaces.

### 2.30 Empty Hint
```

**4. `### 3.1 Recent Watching Card Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.2 Library Folder Card Layout
```

修改后

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Recent Watching card.

Allowed invalidation:
- Hover and pressed state may update only the current card.
- Cover image loading may update only the current card cover region.
- Left click may hand off explicitly to Playback route owner.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Card hover, cover image loading, and right click must not rebuild the recent watching grid or refresh Search/Shiori/table surfaces.
- Opening playback from a card must not synchronously rebuild hidden Library surfaces unless the command explicitly requires a batched data update.

### 3.2 Library Folder Card Layout
```

**5. `### 3.2 Library Folder Card Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.3 Library Episode Grid and Card Layout
```

修改后

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Library folder card.

Allowed invalidation:
- Hover and pressed state may update only the current folder card.
- Cover badge/count changes may update only the current card.
- Left click may update Library Folder Detail route.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Folder card hover and right click must not rebuild the full Library grid, refresh table data, or invalidate Playback.
- Folder route changes must not reload unrelated Search/Shiori surfaces.

### 3.3 Library Episode Grid and Card Layout
```

**6. `### 3.3 Library Episode Grid and Card Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.4 Library Folder Detail Header Layout
```

修改后

```md
#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Library episode row and cover region.

Allowed invalidation:
- Cover hover, pressed state, and cover cursor may update only the current episode cover region.
- Cover image loading may update only the current episode cover.
- Left click may hand off explicitly to Playback route owner.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Info Region hover must not trigger playback hover state, menu state, or cover redraw.
- Episode hover, cover loading, and right click must not rebuild the full episode grid or refresh Search/Shiori/table surfaces.
- Opening playback from an episode must not synchronously rebuild hidden Library surfaces unless the command explicitly requires a batched data update.

### 3.4 Library Folder Detail Header Layout
```

**7. `### 3.8 App Sidebar Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Persistence
Sidebar Expanded State:
  Persist across app restarts

### 3.9 App Topbar Layout
```

修改后

```md
#### Persistence
Sidebar Expanded State:
  Persist across app restarts

#### Refresh Scope
Owner:
- App sidebar layout.

Allowed invalidation:
- Sidebar item hover may update only the hovered sidebar item.
- Sidebar expand / collapse may update sidebar width, app topbar leading layout, and current workbench surface frame.
- Navigation item click may update the active workbench route and mount the selected surface.

Forbidden invalidation:
- Sidebar hover, cursor, and expand / collapse must not reload Search, Shiori, Library, or Playback data.
- Window width changes and compact sidebar behavior must not rebuild table snapshots or playback render host.
- Hidden workbench surfaces must not start background loading only because sidebar state changed.

### 3.9 App Topbar Layout
```

**8. `### 3.10 Confirmation Dialog Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Interaction
Default Focus: Cancel Action Button
Cancel Action: close dialog without changes
Remove Action: remove the Shiori row, close dialog, refresh Shiori table and selection state
Escape Key: same as Cancel
Return Key: activate default focused action
Click Outside: no action, dialog remains open

### 3.11 Player Topbar Layout
```

修改后

```md
#### Interaction
Default Focus: Cancel Action Button
Cancel Action: close dialog without changes
Remove Action: remove the Shiori row, close dialog, refresh Shiori table and selection state
Escape Key: same as Cancel
Return Key: activate default focused action
Click Outside: no action, dialog remains open

#### Refresh Scope
Owner:
- Confirmation dialog overlay.

Allowed invalidation:
- Dialog open / close may update only the dialog overlay, focus state, and the command target state.
- Cancel, Escape, and click outside may close or retain only the dialog state.
- Confirmed destructive action may update only the affected data owner and its declared selection state.

Forbidden invalidation:
- Dialog hover, focus, and open state must not reload table rows, rebuild Library grids, or invalidate Playback.
- Dialog measurement and focus changes must not update Search/Shiori/Library data before the user confirms the action.

### 3.11 Player Topbar Layout
```

**9. `### 3.11 Player Topbar Layout` 新增 `#### Refresh Scope`**

修改前

```md
#### Cursor
Window Control Button: pointer
Title: default
Empty Titlebar Area: default

### 3.12 Player Bottom Control Bar Layout
```

修改后

```md
#### Cursor
Window Control Button: pointer
Title: default
Empty Titlebar Area: default

#### Refresh Scope
Owner:
- Player topbar layer.

Allowed invalidation:
- Window control cluster hover may update only the window control glyph visibility.
- Player UI visible / hidden state may update only player topbar visibility and player chrome visibility.
- Player title changes may update only Player Topbar Title and playback chrome title surfaces.

Forbidden invalidation:
- Player topbar hover, drag, double-click, and window-control hover must not invalidate Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
- Player topbar visibility changes must not resize, recreate, or reattach the playback render host.

### 3.12 Player Bottom Control Bar Layout
```

**10. `### 3.12 Player Bottom Control Bar Layout` 修改已有 `#### Refresh Scope`**

修改前

```md
#### Refresh Scope
Owner:
- Playback chrome layer.

Allowed invalidation:
- Player button hover / pressed states may update only the corresponding control.
- Playback time updates may update progress, time labels, and current subtitle overlay.
- Speed menu state may update only the speed button, speed menu, and menu dismiss monitor.
- Volume hover and dragging may update only the volume control and volume value.
- Timeline scrubbing may update progress preview, scrub time, and seek pipeline.

Forbidden invalidation:
- Playback chrome hover, speed menu, volume changes, and time ticks must not invalidate Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
- Non-geometry chrome updates must not resize, recreate, or reattach the playback render host.
```

修改后

```md
#### Refresh Scope
Owner:
- Playback chrome layer.
- High-frequency playback time state is owned by progress, time label, and subtitle overlay subregions, not by the whole chrome shell.

Allowed invalidation:
- Player button hover / pressed states may update only the corresponding control.
- Playback time updates may update only progress, time labels, and current subtitle overlay.
- Speed menu state may update only the speed button, speed menu, menu anchor measurement, and menu dismiss monitor.
- Volume hover and dragging may update only the volume control and volume value.
- Timeline scrubbing may update progress preview, scrub time, and seek pipeline.
- Quick playback commands may update playback state and the corresponding command feedback surface.

Forbidden invalidation:
- Playback chrome hover, speed menu, volume changes, time ticks, subtitle visibility toggles, and button hover must not invalidate Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
- High-frequency playback time updates must not re-evaluate the whole chrome shell when only progress, time label, or current subtitle changed.
- Non-geometry chrome updates must not resize, recreate, or reattach the playback render host.
```

**11. `### 4.1 Global Rule` 修改已有 `#### Contract`**

修改前

```md
#### Contract
Every UI interaction must define a rendering owner and must stay inside its allowed invalidation scope.

Allowed state changes:
- The owning component may update its own local visual state.
- The owning data surface may update its own stable snapshot.
- Cross-surface actions may update another surface only through an explicit owner handoff.

Forbidden state changes:
- Local hover, focus, pressed, cursor, drag, and menu-open states must not be written into global stores.
- A component must not subscribe to a store or observable object unless it renders that state directly.
- Background loading must not invalidate unrelated visible surfaces.
- Playback video rendering must not be invalidated by non-playback interactions.
- NSViewRepresentable updates must diff meaningful inputs and must not redraw their full content when only callbacks, cursor state, or unrelated parent state changed.

Required implementation checks:
- Each new interaction must identify Owner, Allowed Invalidation, Forbidden Invalidation, and Probe / verification point before implementation.
```

修改后

```md
#### Contract
Every UI interaction must define a rendering owner and must stay inside its allowed invalidation scope.

Allowed state changes:
- The owning component may update its own local visual state.
- The owning data surface may update its own stable snapshot.
- Cross-surface actions may update another surface only through an explicit owner handoff.
- Layout changes may update geometry and visibility for declared layout owners only.
- Background loading may update only the visible or explicitly active data owner that requested it.

Forbidden state changes:
- Local hover, focus, pressed, cursor, drag, right-click, checkbox, and menu-open states must not be written into global stores.
- A component must not subscribe to a store or observable object unless it renders that state directly.
- Background loading must not invalidate unrelated visible surfaces.
- Playback video rendering must not be invalidated by non-playback interactions.
- NSViewRepresentable updates must diff meaningful inputs and must not redraw their full content when only callbacks, cursor state, or unrelated parent state changed.
- Hidden or playback-covered surfaces must not respond to routine hover, menu, selection, scroll, or background loading events.

Required implementation checks:
- Each new interaction must identify Owner, Allowed Invalidation, Forbidden Invalidation, and Probe / verification point before implementation.
- Each new store subscription must identify the exact rendered fields and prove that unrelated field changes do not invalidate the component.
```

**12. `## 4` 新增 `### 4.2` 到 `### 4.5`**

修改前

```md
Required implementation checks:
- Each new interaction must identify Owner, Allowed Invalidation, Forbidden Invalidation, and Probe / verification point before implementation.
```

修改后

```md
Required implementation checks:
- Each new interaction must identify Owner, Allowed Invalidation, Forbidden Invalidation, and Probe / verification point before implementation.
- Each new store subscription must identify the exact rendered fields and prove that unrelated field changes do not invalidate the component.

### 4.2 Invalidation Source Categories

#### Contract
Each UI update source must be classified before implementation.

Categories:
- Visual-local: hover, focus, pressed, cursor, menu item hover.
- Selection-local: checkbox toggle, row selection, batch action visibility.
- Overlay-local: popover, context menu, dialog, tooltip, measurement, dismiss monitor.
- Layout-local: window width, sidebar collapse, topbar visibility, route frame.
- Data-local: search results, shiori rows, library cards, watch state, cover image.
- Cross-surface command: open playback, open folder, copy, export, mark watched.
- High-frequency playback: time tick, progress hover, scrub drag, subtitle text.
- Background loading: hydrate, continuous load, image load, detail load, count load.

Rule:
- Each category must declare its owner, allowed invalidation, forbidden invalidation, and probe.

### 4.3 Store Subscription Boundary

#### Contract
Components must subscribe only to state they render directly.

Required behavior:
- Large stores must be split by view boundary, projected into stable snapshots, or passed as value props before reaching high-frequency or large-list components.
- Local interaction state must remain local unless another owner explicitly renders it.
- Store writes should be batched or deduplicated when a command updates multiple related fields.

Forbidden behavior:
- A top-level workbench component must not observe a large store only to pass callbacks.
- A list row, card, table bridge, or playback control must not observe a global store for command access when stable closures are sufficient.
- High-frequency playback state must not be stored in a way that invalidates non-time chrome controls.

### 4.4 Visibility and Activity Gate

#### Contract
A surface may respond only when it is visible, active, or explicitly declared as a background owner.

Required behavior:
- Playback-covered workbench surfaces must suppress routine hover, menu, selection, scroll, and background loading responses.
- Hidden Search, Shiori, and Library surfaces may defer data refresh until they become visible.
- Background tasks must check the current owner generation before publishing results.

Forbidden behavior:
- Hidden surfaces must not rebuild snapshots only because another surface changed route, layout, menu, or playback state.
- Playback entry must not synchronously refresh unrelated table or library presentations.

### 4.5 Probe and Verification

#### Contract
Refresh scope changes must be measurable.

Required probes:
- Log the user action name.
- Count the expected owner body/render/update.
- Count forbidden surfaces that must remain unchanged.
- Record table snapshot rebuilds, row hydration, library snapshot rebuilds, playback render host updates, and high-frequency playback chrome updates.

Acceptance:
- A change passes only when the expected owner updates and forbidden surfaces do not update for the tested interaction.
```
