# 版本
main

# 需求描述
几乎所有前端交互操作都会导致刷新完整界面，这导致了非常多的bug和性能问题。基于这个现状，应该建立全局的刷新影响范围契约，以及精确到组件的刷新影响范围契约，从而大幅度减少类似问题。
详细改动见# UI文档改动。

# UI文档改动
**1. 在 `3.13 Player Progress Scrubber Layout` 后新增全局契约**

修改前

```md
#### Cursor
Track Region: pointer
Progress Time Capsule: default, no hit testing
```

修改后

```md
#### Cursor
Track Region: pointer
Progress Time Capsule: default, no hit testing

## 4. Refresh Scope Contract

### 4.1 Global Rule

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

**2. `3.7 Search / Shiori Table Layout`**

修改前

```md
#### Cursor
Inherited from child components
```

修改后

```md
#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori table surface.
- Table document, header, scrollbar, selection, and menu subregions own their own local rendering.

Allowed invalidation:
- Search or Shiori row snapshot changes may update table rows and table summary.
- Column visibility changes may update header, column layout, visible rows, and cursor rects.
- Filter or submitted search changes may reload the owning table data.
- Visible-row changes may request additional rows only for the owning table.
- Row action menus may update only the active row, active menu, and menu overlay.

Forbidden invalidation:
- Table hover, cursor, focus, menu-open, and scrollbar interactions must not invalidate SearchView, App Sidebar, App Topbar, Playback Page, or Playback render host.
- Search table updates must not invalidate Shiori or Library surfaces.
- Shiori table updates must not invalidate Search or Library surfaces.
- Background row hydration must not run while the owning table surface is not allowed to respond to interaction.
```

**3. `2.17 Table Row`**

修改前

```md
#### Cursor
Not specified in image
```

修改后

```md
#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table document row layer.

Allowed invalidation:
- Row hover may redraw only the previous row and the current row.
- Cell hover may redraw only the current row.
- Cell action menu open / close may redraw only the triggering row and the previously active row.
- Selection change may redraw the changed row and update the selection header state.
- Keyboard focus movement may redraw only the previous focused row and the current focused row.

Forbidden invalidation:
- Row hover must not invalidate the full table document.
- Row hover must not trigger row data reload, table snapshot rebuild, SearchView refresh, or Playback refresh.
- Row-local visual state must not be stored in SearchStore, ShioriStore, LibraryStore, or PlaybackStore.
```

**4. `2.18 Sortable Header Cell`**

修改前

```md
#### Cursor
Not specified in image
```

修改后

```md
#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table header layer.

Allowed invalidation:
- Header hover may update only the hovered header trigger.
- Header menu open / close may update only the header host, active menu, and menu overlay.
- Sort changes may update table row ordering only for the owning table.

Forbidden invalidation:
- Header hover must not redraw table rows.
- Header menu state must not invalidate Playback, Library, or unrelated workbench surfaces.
- Sorting must not rewrite source data outside the owning table snapshot.
```

**5. `2.21 Table Scrollbar`**

修改前

```md
#### Cursor
Not specified in image
```

修改后

```md
#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table scrollbar overlay.

Allowed invalidation:
- Scrollbar hover and dragging may redraw only the scrollbar dirty region.
- Scroll position changes may update visible row range, scrollbar metrics, cursor rects, and horizontal header offset when needed.

Forbidden invalidation:
- Scrollbar hover must not redraw table rows.
- Scrollbar dragging must not rebuild row data.
- Scrolling must not invalidate Playback render host or unrelated workbench surfaces.
```

**6. `3.5 Search Filter Bar Layout`**

修改前

```md
#### Cursor
Inherited from child components
```

修改后

```md
#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori filter bar and the owning table query state.

Allowed invalidation:
- Typing may update only the input draft.
- Submit may update the owning query or filter snapshot and then reload the owning table.
- Opening filter controls may update only the filter popover and trigger state.
- Editing filter rules may update only the filter builder and owning filter draft until applied.

Forbidden invalidation:
- Typing without submit must not reload table rows.
- Filter popover hover/open state must not invalidate table rows, Playback, Library, App Sidebar, or App Topbar.
- Search filter changes must not update Shiori table state unless the active surface is Shiori.
```

**7. `3.6 Search / Shiori Utility Bar Layout`**

修改前

```md
#### Cursor
Inherited from child components
```

修改后

```md
#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori utility bar.

Allowed invalidation:
- Row count changes may update Count Summary.
- Selection changes may update Count Summary and Batch Actions visibility.
- View menu changes may update the owning table column layout.
- Batch action button hover may update only the button itself.

Forbidden invalidation:
- Count Summary updates must not redraw table rows.
- Batch action hover must not update row selection or table data.
- View menu open state must not invalidate Playback or unrelated workbench surfaces.
```

**8. `3.12 Player Bottom Control Bar Layout`**

修改前

```md
#### Cursor
Player Circle Button: pointer
Player Capsule Button: pointer
Player Circle Button Group Background: default
```

修改后

```md
#### Cursor
Player Circle Button: pointer
Player Capsule Button: pointer
Player Circle Button Group Background: default

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

**9. `3.13 Player Progress Scrubber Layout`**

修改前

```md
#### Cursor
Track Region: pointer
Progress Time Capsule: default, no hit testing
```

修改后

```md
#### Cursor
Track Region: pointer
Progress Time Capsule: default, no hit testing

#### Refresh Scope
Owner:
- Player progress scrubber.

Allowed invalidation:
- Pointer hover may update hover preview track, thumb visibility, and time capsule.
- Pointer move may update hover preview width and time capsule position/text.
- Drag may update scrub target time, played-track preview, thumb, time capsule, and seek command.
- Drag start/end may update timeline scrubbing state.

Forbidden invalidation:
- Progress hover and drag must not invalidate workbench surfaces.
- Progress hover and drag must not trigger table row hydration, Search/Shiori/Library refresh, or Playback render host layout unless video geometry changes.
```

**10. `3.9 App Topbar Layout`**

修改前

```md
#### Playback
When playback page is visible:
  Hide App Topbar Layout
  Playback page owns its own topbar / chrome behavior
```

修改后

```md
#### Playback
When playback page is visible:
  Hide App Topbar Layout
  Playback page owns its own topbar / chrome behavior

#### Refresh Scope
Owner:
- App topbar layout.

Allowed invalidation:
- Sidebar expanded / collapsed state may update topbar layout and title leading position.
- Playback page visibility may hide or show the app topbar.
- Window width changes may update compact sidebar behavior.

Forbidden invalidation:
- App topbar hover, drag, double-click, and visibility changes must not reload Search, Shiori, Library, or Playback data.
- App topbar state must not invalidate playback render host.
```
