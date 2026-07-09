# 版本
main

# 需求描述
1. 新增功能：字幕焦点窗口。替换之前的quick search功能。
2. 播放视频时，按下Enter键呼出字幕焦点窗口。视频暂停（不论按下前是否处于暂停状态）。按Esc可以退出字幕焦点，视频播放状态恢复到按下Enter键前。
3. 字幕焦点窗口，默认焦点位于当前字幕（如果不存在当前字幕，则位于当前时间戳之前的最近一个字幕）。除了焦点字幕，还会显示焦点字幕之前几条字幕和之后几条字幕。焦点字幕要尽量居中。
4. 焦点窗口是深色底，焦点字幕是比较亮的白色，其它字母是比较暗的白色。具体UI内容见# UI文档改动。
5. 焦点窗口的滚动条，参考Search界面列表的滚动条，要保持常驻，作为进度的提示，不然用户打开字幕焦点窗口看不到下面的滚动条，它怎么知道现在是什么时候了
6. 按方向键上下键，滚轮滚动，或者鼠标拖动滚动条，焦点位置不变。除非已经是第一条且往上滚动或已经是最后一条字幕且往下滚动，否则焦点字幕会变。
7. 焦点字幕变动时，需要有一种卷轴的感觉（即中间位置适中保持焦点，给人的感觉是歌词是一个卷轴在滚动）。
8. 鼠标点击非焦点字幕，不要滚动，而是立即将焦点转移到这条字幕上，并且弹出菜单。
9. 焦点窗口打开时，按下Enter键会弹出纵向菜单，有3个选择：Shiori，Copy Cue Text，Play From This Cue。可以用方向键上下键选择选项，按下Enter键执行操作并关闭焦点窗口，按下Esc键退出菜单且保留焦点窗口。如果该字幕已经收藏，菜单项中的Shiori变为Shiori Already Saved，并且该选项变为disabled。
10. 字幕采用懒加载的方式，默认只加载一共10条的内容，焦点字幕位于第7个；距边界2条时预加载；每批 10 条；缓存最多 30 条；快速拖动停留 100ms 才预览，松手立即加载最终位置，所有异步结果采用 latest-wins。当切换视频时，释放缓存。
11. 移除旧的quick search界面及相关UI代码。前端不保留/back和/forward入口，后端保留相关代码。

# UI文档改动

## Core Tokens

### 新增 `#### Subtitle Focus`

插入位置：现有 `#### Player Chrome` 后、`### 1.2 尺寸、圆角、间距` 前。

修改前：不存在该 `####` Block。

修改后：

```text
#### Subtitle Focus
--color-subtitle-focus-overlay-bg:
  Light: #242426
  Dark: #242426
--color-subtitle-focus-cue-selected:
  Light: rgba(255,255,255,0.94)
  Dark: rgba(255,255,255,0.94)
--color-subtitle-focus-cue-hover:
  Light: rgba(255,255,255,0.62)
  Dark: rgba(255,255,255,0.62)
--color-subtitle-focus-cue-unselected:
  Light: rgba(255,255,255,0.34)
  Dark: rgba(255,255,255,0.34)
```

### `#### Height`

修改前：

```text
#### Height
--height-filter-bar-control: 40px
--height-control: 40px
--height-field: 40px
--height-table-utility-bar: 40px
--height-table-header: 40px
--height-table-row: 64px
--height-action-menu-item: 40px
--height-select-menu-item: 40px
--height-app-sidebar-item: 32px
--height-app-topbar: 45px
--height-player-topbar: 46px
--height-player-bottom-control-bar: 98px
--height-player-bottom-controls-row: 52px
--height-player-capsule-button: 40px
--height-player-speed-menu: 234px
--height-player-speed-menu-item: 30px
--height-player-progress-hit-area: 18px
--height-player-progress-track: 3px
--height-player-progress-track-hover: 6px
--height-player-progress-time-capsule: 22px
```

修改后：

```text
#### Height
--height-filter-bar-control: 40px
--height-control: 40px
--height-field: 40px
--height-table-utility-bar: 40px
--height-table-header: 40px
--height-table-row: 64px
--height-action-menu-item: 40px
--height-select-menu-item: 40px
--height-app-sidebar-item: 32px
--height-app-topbar: 45px
--height-player-topbar: 46px
--height-player-bottom-control-bar: 98px
--height-player-bottom-controls-row: 52px
--height-player-capsule-button: 40px
--height-player-speed-menu: 234px
--height-player-speed-menu-item: 30px
--height-player-progress-hit-area: 18px
--height-player-progress-track: 3px
--height-player-progress-track-hover: 6px
--height-player-progress-time-capsule: 22px
--height-subtitle-focus-cue-slot: 104px
```

### 修改 `#### Size`

修改前：

```text
#### Size
--size-checkbox: 16px
--size-inline-clear-button: 24px
--size-inline-clear-icon: 16px
--size-inline-clear-symbol-font-size-macos: 11pt
--size-inline-add-symbol-font-size-macos: 16pt
--size-menu-item-symbol-font-size-macos: 14pt
--size-select-indicator: 12pt
--size-button-icon: 14px
--size-control-icon: 16px
--size-icon-button: 32px
--size-row-action-button: 36px
--scrollbar-size: 8px
--width-app-sidebar: 240px
--size-app-sidebar-item-icon: 18px
--size-player-circle-button: 40px
--size-player-circle-button-icon: 18px
--width-player-speed-button: 54px
--width-player-speed-menu: 172px
--size-player-progress-thumb: 12px
--size-player-window-control-button: 13px
--size-player-window-control-glyph: 7px
--width-player-topbar-title-max: 520px
```

修改后：

```text
#### Size
--size-checkbox: 16px
--size-inline-clear-button: 24px
--size-inline-clear-icon: 16px
--size-inline-clear-symbol-font-size-macos: 11pt
--size-inline-add-symbol-font-size-macos: 16pt
--size-menu-item-symbol-font-size-macos: 14pt
--size-select-indicator: 12pt
--size-button-icon: 14px
--size-control-icon: 16px
--size-icon-button: 32px
--size-row-action-button: 36px
--scrollbar-size: 8px
--width-app-sidebar: 240px
--size-app-sidebar-item-icon: 18px
--size-player-circle-button: 40px
--size-player-circle-button-icon: 18px
--width-player-speed-button: 54px
--width-player-speed-menu: 172px
--size-player-progress-thumb: 12px
--size-player-window-control-button: 13px
--size-player-window-control-glyph: 7px
--width-player-topbar-title-max: 520px
--width-subtitle-focus-content-max: 960px
```

### 修改 `#### Typography`

修改前：

```text
#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 14px
--font-weight-control: 500
--weight-select-indicator: semibold
--weight-button-icon: medium
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px

--font-size-player-time: 12px
--font-size-player-progress-time: 10px
--font-size-player-speed-menu-check: 11px
--font-size-player-speed-menu-item: 13px
--font-size-player-topbar-title: 13px
```

修改后：

```text
#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 14px
--font-weight-control: 500
--weight-select-indicator: semibold
--weight-button-icon: medium
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px

--font-size-player-time: 12px
--font-size-player-progress-time: 10px
--font-size-player-speed-menu-check: 11px
--font-size-player-speed-menu-item: 13px
--font-size-player-topbar-title: 13px

--font-size-subtitle-focus-cue: 40px
--line-height-subtitle-focus-cue: 1.30
--font-weight-subtitle-focus-cue: 600
```

### 新增 `#### Subtitle Focus Motion`

插入位置：`#### Typography` 后、`#### Shadow` 前。

修改前：不存在该 `####` Block。

修改后：

```text
#### Subtitle Focus Motion
--duration-subtitle-focus-scroll: 0.22s
--easing-subtitle-focus-scroll: cubic-bezier(0.22, 1, 0.36, 1)
```

## Components

插入位置：`### 2.43 Tag Composer Field` 后、`## 3. Layout` 前。

### 新增 `### 2.44 Subtitle Focus Cue`

修改前：不存在该 Component。

修改后：

```text
### 2.44 Subtitle Focus Cue

#### Container
Display: block
Width: 100%
Height: --height-subtitle-focus-cue-slot
Background: transparent
Border: none
Overflow: hidden
Clip: cue text at fixed slot bounds
Visual Alignment: top-leading
Hit Testing: visible cue text union bounds inside the fixed slot
Layout Stability: every cue uses identical fixed geometry regardless of line count, selection, hover, or menu state

#### Content
Text: one complete cue group
Multi-line Cue: preserve source line order and line breaks before visual clipping
Wrapping: wrap within Playback Subtitle Focus Overlay content width
Text Alignment: top-leading
First Line Origin: fixed relative to the cue slot top edge
Visible Line Capacity: two complete lines at the declared font size and line height
Overflow Content: clip at the cue slot bounds without expanding the slot
Truncation Indicator: none
Full Cue Group Value: retain complete unclipped text for Shiori, Copy Cue Text, and Play From This Cue
Font Family: --font-family-base
Font Size: --font-size-subtitle-focus-cue
Line Height: --line-height-subtitle-focus-cue
Font Weight: --font-weight-subtitle-focus-cue
Selected Text Color: --color-subtitle-focus-cue-selected
Hover Text Color: --color-subtitle-focus-cue-hover
Unselected Text Color: --color-subtitle-focus-cue-unselected
Background / Border / Shadow: none in every state

#### Status
Unselected
Unselected Hover
Selected

#### Interaction
Pointer Enter on Unselected Cue:
  Apply Hover text color only
  Do not change the selected cue
  Do not move the cue reel

Pointer Exit:
  Restore Unselected text color

Pointer Click on Unselected Cue:
  Select the clicked cue
  Move the focus anchor to the clicked cue's current screen-space position
  Do not scroll, recenter, or animate the cue reel
  Open Subtitle Focus Action Menu for the clicked cue

Pointer Click on Selected Cue:
  Keep the current selection and focus anchor
  Open Subtitle Focus Action Menu for the selected cue

Action Menu Open / Close:
  Keep the selected cue identity, text color, typography, and position unchanged

Selection Change from Keyboard / Wheel / Scrollbar:
  Update only the previous and next selected cue visual states
  The enclosing layout owns cue reel movement and lazy loading

#### Cursor
Cue Text: pointer
Non-text Area: default

#### Refresh Scope
Owner:
- Individual Subtitle Focus Cue visual state.

Allowed invalidation:
- Cue hover may redraw only the hovered cue text.
- Cue selection changes may redraw only the previous selected cue and the new selected cue.
- Text replacement may redraw only the affected fixed cue slot.

Forbidden invalidation:
- Cue text line count, wrapping, and clipping must not change cue slot height or cue reel geometry.
- Cue text line count must not move the selected cue first-line origin or Focus Anchor.
- Opening or closing the action menu must not invalidate the selected cue visual state.
- Cue hover must not update playback state, selected cue identity, scrollbar metrics, or loaded cue data.
- Cue selection must not seek playback or resume playback.
- Cue hover and selection must not invalidate Playback render host, playback chrome, Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
```

### 新增 `### 2.45 Subtitle Focus Action Menu Item`

修改前：不存在该 Component。

修改后：

```text
### 2.45 Subtitle Focus Action Menu Item

#### Container
Display: flex
Align Items: center
Width: 100%
Height: --height-player-speed-menu-item
Radius: --radius-player-speed-menu-item
Padding X: --padding-player-speed-menu-item-x
Gap: --spacing-2
Background Default: transparent
Background Hover / Keyboard Selected: --color-player-menu-item-hover-bg
Background Disabled: transparent

#### Content
Leading Icon Slot: fixed action icon
Leading Icon Size: --size-control-icon
Label: action label
Font Family: --font-family-base
Font Size: --font-size-player-speed-menu-item
Text Color Default: --color-player-text-primary
Text Color Disabled: --color-player-text-tertiary
Icon Color Default: --color-player-text-primary
Icon Color Disabled: --color-player-text-tertiary
Trailing Checkmark: none

Shiori:
  Icon: bookmark
  Label: Shiori

Shiori Already Saved:
  Icon: bookmark.fill
  Label: Shiori Already Saved
  State: Disabled

Copy Cue Text:
  Icon: copy
  Label: Copy Cue Text

Play From This Cue:
  Icon: play.fill
  Label: Play From This Cue

#### Status
Default
Hover
Keyboard Selected
Pressed
Disabled

#### Interaction
Pointer Enter:
  Apply Hover background when enabled
  Move menu keyboard selection to this item

Pointer Click:
  Execute the item action when enabled
  Ignore the interaction when disabled

Keyboard Selection:
  Up / Down moves between enabled items
  Disabled items are skipped

Keyboard Enter:
  Execute the selected enabled item

#### Cursor
Enabled: pointer
Disabled: default

#### Refresh Scope
Owner:
- Individual Subtitle Focus Action Menu Item visual state.

Allowed invalidation:
- Pointer hover and keyboard selection may redraw only the previous and next active menu items.
- Disabled-state resolution may update only the Shiori item label, icon, color, and keyboard eligibility.

Forbidden invalidation:
- Menu item hover and keyboard selection must not update cue selection, cue reel position, scrollbar state, playback time, or loaded cue data.
- Disabled item interaction must not issue a Shiori command.
- Menu item visual state must not invalidate Playback render host, playback chrome, Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
```

### 新增 `### 2.46 Subtitle Focus Action Menu`

修改前：不存在该 Component。

修改后：

```text
### 2.46 Subtitle Focus Action Menu

#### Container
Width: --width-player-speed-menu
Height: intrinsic content height
Radius: --radius-player-speed-menu
Padding: --padding-player-speed-menu
Background: --color-player-menu-bg
Border: --color-player-text-tertiary
Shadow: --shadow-player-overlay
Appearance: use the Player Speed Menu dark overlay visual in both Light and Dark app appearances
Orientation: vertical
System Popover Arrow: none

#### Content
Items:
  Subtitle Focus Action Menu Item: Shiori or Shiori Already Saved
  Subtitle Focus Action Menu Item: Copy Cue Text
  Subtitle Focus Action Menu Item: Play From This Cue

Item Height: --height-player-speed-menu-item
Item Radius: --radius-player-speed-menu-item
Item Padding X: --padding-player-speed-menu-item-x
Item Background Hover / Keyboard Selected: --color-player-menu-item-hover-bg
Item Text Size: --font-size-player-speed-menu-item
Item Text Color: --color-player-text-primary
Item Disabled Color: --color-player-text-tertiary
Item Icon Size: --size-control-icon
Item Icon / Text Gap: --spacing-2
Divider: none

#### Anchor
Anchor: selected Subtitle Focus Cue bounds
Preferred Position: below the selected cue
Gap from Cue: --spacing-3
Edge Handling: clamp to the Subtitle Focus Overlay bounds; flip above the cue when there is insufficient space below
Cue Layout: menu positioning must not move, resize, or reflow the selected cue or cue reel

#### Status
Closed
Open
Item Default
Item Hover
Item Keyboard Selected
Shiori Available
Shiori Already Saved / Disabled
Interaction Suppressed

#### Interaction
Open from Keyboard:
  Enter in cue-selection state opens the menu for the selected cue

Open from Pointer:
  Clicking a cue opens the menu for that cue

Selected Cue Appearance:
  Opening and closing the menu do not change the selected cue text color, typography, or position

Initial Keyboard Selection:
  Select the first enabled item
  If Shiori Already Saved is disabled, select Copy Cue Text

Up / Down:
  Move selection between enabled menu items
  Do not navigate the cue reel while the menu is open

Enter:
  Execute the selected enabled item
  Close the Subtitle Focus Overlay after execution

Pointer Hover:
  Move menu selection to the hovered enabled item

Pointer Click:
  Execute the clicked enabled item
  Close the Subtitle Focus Overlay after execution

Escape:
  Close only the action menu
  Keep the Subtitle Focus Overlay open
  Keep the selected cue and focus anchor unchanged

Click Outside Menu:
  Close only the action menu
  Keep the Subtitle Focus Overlay open
  Keep the selected cue and focus anchor unchanged

Disabled Item:
  Ignore pointer click and Enter
  Skip during keyboard navigation

#### Cursor
Enabled Menu Item: pointer
Disabled Menu Item: default
Menu Background: default

#### Refresh Scope
Owner:
- Subtitle Focus Action Menu overlay.
- Menu-local keyboard selection and dismiss monitor.

Allowed invalidation:
- Menu open / close may update only the menu overlay, menu anchor measurement, and dismiss monitor.
- Menu item hover and keyboard selection may update only the affected menu items.
- Shiori existence lookup completion may update only the first menu item.
- Shiori execution may update only Shiori persistence and the affected cue's saved state before the overlay closes.
- Copy Cue Text may write only the selected cue group's full text to the system pasteboard.
- Play From This Cue may hand off the selected cue start time to the playback seek-and-play command.

Forbidden invalidation:
- Menu open / close must not invalidate the selected Subtitle Focus Cue visual state.
- Menu open, close, hover, keyboard navigation, measurement, and dismissal must not reload cue text or move the cue reel.
- Menu-local state must not be written into a global playback or workbench store.
- Shiori execution must not rebuild a hidden Shiori presentation.
- Copy Cue Text must not change playback state or cue selection.
- Menu interaction must not invalidate Playback render host, playback chrome, Search, Library, table surfaces, App Sidebar, or App Topbar.
```

## Layout

插入位置：`### 3.14 Shiori Tag Popover Layout` 后、`## 4. Refresh Scope Contract` 前。

### 新增 `### 3.15 Playback Subtitle Focus Overlay Layout`

修改前：不存在该 Layout。

修改后：

```text
### 3.15 Playback Subtitle Focus Overlay Layout

#### Structure
Container: full-stage overlay inside Playback Page
Presentation: overlay, not a separate native window
Position: fill the complete playback stage
Z Order: above video content and playback chrome
Background: --color-subtitle-focus-overlay-bg
Appearance: fixed dark appearance in both Light and Dark app appearances
Content Insets: --spacing-8
Clipping: clip cue reel and action menu to overlay bounds
Playback Render Host: remain attached and geometrically unchanged behind the overlay

#### Regions
Subtitle Focus Cue Reel:
  Position: centered within the overlay
  Width: min(available inset width, --width-subtitle-focus-content-max)
  Orientation: vertical
  Cue Slot Height: --height-subtitle-focus-cue-slot
  Cue Gap: --spacing-8
  Cue Slot Pitch: --height-subtitle-focus-cue-slot + --spacing-8 = 136px
  Cue Geometry: every cue group occupies one fixed-height slot
  Cue Overflow: clip text at the fixed slot bounds
  Viewport Edge Behavior: partially visible leading and trailing cue slots are allowed
  Text Alignment: top-leading
  Contains: Subtitle Focus Cue
  Visible Decoration: none

Focus Anchor:
  Type: logical screen-space first-line origin anchor; no visible line, indicator, background, or marker
  Initial Position: place the default selected cue first-line origin as close to the vertical center as available cue boundaries allow
  Geometry Independence: cue line count and clipping must not move the Focus Anchor
  Navigation Behavior: remain fixed while keyboard, wheel, or scrollbar navigation moves the cue reel by fixed Cue Slot Pitch increments
  Pointer Selection Behavior: move to the clicked cue's current first-line origin without moving the cue reel

Subtitle Focus Scrollbar Region:
  Position: trailing edge of the overlay
  Height: Subtitle Focus Cue Reel viewport height
  Contains: Table Scrollbar
  Orientation: vertical
  Visibility: persistent when cue groups exist

Subtitle Focus Action Menu Region:
  Position: overlay-local floating layer anchored to the selected cue
  Contains: Subtitle Focus Action Menu
  Layout Effect: none; must not alter cue reel geometry or Focus Anchor position

#### Content
Overlay Background:
  Color: --color-subtitle-focus-overlay-bg
  Image / Blur / Gradient / Texture: none

Cue Text:
  Selected: --color-subtitle-focus-cue-selected
  Unselected Hover: --color-subtitle-focus-cue-hover
  Unselected: --color-subtitle-focus-cue-unselected
  Typography: identical across visual states
  Cue Group Integrity: render and act on one complete cue group as one item

Action Menu:
  Style: Player Speed Menu visual with leading action icons
  Items: Shiori / Copy Cue Text / Play From This Cue
  Saved State: replace Shiori with disabled Shiori Already Saved

Excluded Front-end Content:
  Old Quick Search input, command rows, result rows, AI chunk rows, /back, and /forward
  Player topbar and bottom playback chrome while the overlay is visible
  Playback progress bar, extra toolbar, cards, cue backgrounds, borders, and visible focus marker
  Loading progress bar and loading spinner

#### State Model
Closed:
  Subtitle Focus Overlay is not rendered
  Subtitle Focus content cache and pending requests do not exist
  Playback owns normal keyboard and pointer interaction

Opening:
  Playback state, playback source identity, subtitle source identity, and current timestamp are captured
  Playback is paused immediately
  Initial cue-window loading runs outside the main thread
  The paused video frame remains visible
  Subtitle Focus Overlay is not rendered until the initial cue window is ready
  Escape may cancel Opening and restore the captured playback state

Cue Selection:
  Overlay is visible
  Playback is paused
  Cue reel navigation is enabled
  Selected cue uses --color-subtitle-focus-cue-selected
  Action menu is closed

Target Window Loading:
  Overlay remains visible
  Playback remains paused
  The last valid cue window remains visible
  Scrollbar preview position may change
  Action menu opening is suppressed
  Escape remains available

Action Menu Open:
  Overlay remains visible
  Playback remains paused
  Selected cue identity, position, and visual style remain unchanged
  Selected cue continues to use --color-subtitle-focus-cue-selected
  Cue reel keyboard, wheel, scrollbar, and cue-pointer navigation is suppressed
  Action menu owns Up, Down, Enter, Escape, Hover, Click, and outside-click dismissal

#### Initial Selection
Preload Before Open Trigger: none
Open Trigger: Enter while Playback Page is active
Playback Snapshot: capture playback state, playback source identity, subtitle source identity, and current timestamp
Playback Command: pause immediately after capturing the playback snapshot
Session Generation: create a new Subtitle Focus Session generation
Initial Loading: begin only after Enter and run outside the main thread
Overlay Presentation: publish the complete initial cue-window snapshot once; do not progressively insert individual cues

Default Cue:
  Select the cue group active at the captured playback timestamp
  If no cue group is active, select the nearest cue group whose start time is before the captured timestamp

Initial Position:
  Align the default selected cue first-line origin with the initial Focus Anchor
  Keep the Focus Anchor as close to the vertical center as first / last cue boundaries permit
  Do not derive position from cue text height or line count

Initial Lazy-loaded Window:
  Cue Group Count: exactly 10 total when at least 10 cue groups exist; otherwise load all available cue groups
  Preferred Distribution: 6 cue groups before the selected cue, the selected cue, and 3 cue groups after it
  Selected Cue Position: seventh item when at least 6 preceding cue groups exist
  Boundary Distribution: when either boundary lacks enough cue groups, fill the remaining slots from the opposite side
  Cue Geometry: every loaded cue occupies one fixed 104px slot
  Viewport Clipping: clip the fixed ten-slot reel to the available viewport; partial leading and trailing slots are allowed
  Selection Stability: identify the selected cue by stable cue group identity and stable ordinal, not transient loaded-window index

#### Cue Navigation
Fixed Navigation Step:
  Distance: --height-subtitle-focus-cue-slot + --spacing-8 = 136px
  Cue text line count must not change this distance

Up:
  Select the immediately preceding cue group
  Keep the Focus Anchor fixed
  Animate the cue reel upward or downward by exactly one Fixed Navigation Step until the new selected cue first-line origin aligns with the Focus Anchor
  If the first cue is already selected, do nothing

Down:
  Select the immediately following cue group
  Keep the Focus Anchor fixed
  Animate the cue reel upward or downward by exactly one Fixed Navigation Step until the new selected cue first-line origin aligns with the Focus Anchor
  If the last cue is already selected, do nothing

Pointer Wheel / Trackpad Scroll:
  Move the fixed-height cue slots through the Focus Anchor
  Update selection when another fixed cue slot crosses the Focus Anchor
  On scroll end, settle the nearest cue slot first-line origin onto the Focus Anchor
  Do not seek or update playback time

Sequential Prefetch:
  Trigger only after the user navigates toward a loaded-window boundary
  When two loaded cue slots remain in that direction, request the next ten cue groups
  Do not trigger only because the initial selected cue has three following cue groups

Scrollbar Drag:
  Keep the Focus Anchor fixed
  Map the scrollbar position to a cue group ordinal in the complete subtitle
  Use cached targets immediately
  For uncached targets, use the Fast Scrollbar Drag behavior defined in Lazy Loading
  Commit and align only the latest loaded target cue
  Do not seek or update playback time

Pointer Hover on Unselected Cue:
  Apply --color-subtitle-focus-cue-hover
  Do not change selection or move the cue reel

Pointer Click on Unselected Cue:
  Do not scroll, recenter, or animate the cue reel
  Move the Focus Anchor to the clicked cue's current first-line origin
  Select the clicked cue
  Open Subtitle Focus Action Menu immediately

Pointer Click on Selected Cue:
  Keep the selected cue and Focus Anchor unchanged
  Open Subtitle Focus Action Menu immediately

#### Action Menu Interaction
Enter in Cue Selection:
  Open Subtitle Focus Action Menu for the selected cue
  Keep the selected cue visual style unchanged

Up / Down in Action Menu:
  Move between enabled menu items
  Skip Shiori Already Saved when disabled

Enter or Pointer Click on Shiori:
  Save the exact selected cue group
  Close the Subtitle Focus Overlay
  Restore the playback state captured when the overlay opened

Enter or Pointer Click on Copy Cue Text:
  Copy the exact selected cue group's full text, preserving line order
  Close the Subtitle Focus Overlay
  Restore the playback state captured when the overlay opened

Enter or Pointer Click on Play From This Cue:
  Seek to the selected cue group's start time
  Close the Subtitle Focus Overlay
  Begin continuous playback from that time regardless of the captured playback state

Escape in Action Menu:
  Close only the menu
  Return to Cue Selection
  Keep playback paused
  Keep the selected cue, Focus Anchor, and selected cue visual style unchanged

Click Outside Action Menu:
  Same behavior as Escape in Action Menu

#### Overlay Dismissal
Escape During Opening:
  Cancel the pending initial cue-window request
  Invalidate the current Subtitle Focus Session generation
  Restore the playback state captured before Opening
  Keep the Subtitle Focus Overlay closed

Escape in Cue Selection:
  Close the Subtitle Focus Overlay
  Cancel pending prefetch and scrollbar target requests
  Release the Subtitle Focus cue-text cache and layout state
  Restore the playback state captured when the overlay opened
  Restore normal Playback Page keyboard and pointer interaction

Dismissal After Action:
  Complete the selected action handoff using the exact selected cue data required by the action
  Close the Subtitle Focus Overlay
  Cancel remaining Subtitle Focus requests
  Release the Subtitle Focus cue-text cache and layout state

Dismissal Stability:
  Closing the overlay must not perform an implicit seek
  Closing the overlay must not resolve a new cue from current playback time
  A dismissed or superseded Subtitle Focus Session must reject all late results
  The captured playback state is discarded only after dismissal or action handoff completes

#### Lazy Loading
Activation:
  Do not create Subtitle Focus requests, content caches, cue views, or layout measurements during normal video playback
  Begin Subtitle Focus loading only after the user presses Enter
  Run database reads outside the main thread
  Publish loaded cue content as one stable snapshot

Initial Text Load:
  Load exactly 10 cue groups around the default selected cue when at least 10 cue groups exist
  Load all available cue groups when the subtitle contains fewer than 10 cue groups
  Prefer 6 preceding cue groups and 3 following cue groups
  Place the selected cue seventh when available
  Fill missing boundary slots from the opposite side
  Give every cue one fixed --height-subtitle-focus-cue-slot slot

Sequential Prefetch:
  Trigger only after user navigation
  When two loaded cue slots remain in the navigation direction, request the next ten cue groups
  Append the new batch without replacing or moving the current cue reel
  Deduplicate equivalent pending range requests
  Keyboard and ordinary wheel prefetch do not use the scrollbar drag debounce

Text Cache:
  Default Initial Count: 10 cue groups
  Batch Size: 10 cue groups
  Maximum Retained Count: 30 cue groups
  Forward Navigation Eviction: when adding a new batch would exceed Maximum Retained Count, release the earliest and farthest ten cue groups in the same cache update
  Backward Navigation Eviction: when adding a new batch would exceed Maximum Retained Count, release the latest and farthest ten cue groups in the same cache update
  Far Scrollbar Jump: after the target window commits, release all cue-text cache entries belonging only to the old distant position
  Eviction Safety: never release the current visible cue window or cue slots required by an active reel animation

Fast Scrollbar Drag:
  Update the preview cue ordinal continuously without querying every crossed cue
  If the preview target is cached, commit it immediately
  If the preview target is not cached, request it only after the target remains stable for 100ms
  On drag end, immediately request the final target without waiting for the 100ms delay
  Load the final target using 6 preceding cue groups, the target cue group, and 3 following cue groups
  Keep the last valid cue window visible until the latest target commits
  Suppress action-menu opening until the final target commits

Request Coordination:
  Allow at most one active Subtitle Focus database window read
  Track one latest pending target
  Assign every request a Subtitle Focus Session generation
  Publish only results matching the current playback source, subtitle source, session generation, and latest target
  Ignore stale results even when the underlying database operation cannot be cancelled immediately

Complete-document Metadata:
  Load only the total cue group count and stable ordinal information required by the scrollbar after Enter
  Do not load the complete cue-text collection for Subtitle Focus
  Cue text remains lazy-loaded

Loading Presentation:
  Do not show a progress bar or spinner
  During initial loading, keep the paused video frame visible until the complete initial snapshot is ready
  During subsequent loading, keep the current valid cue window visible
  On target-window failure, keep the previous cue window and restore the last committed scrollbar position

Lifecycle:
  Scope every Subtitle Focus cache and request to one playback session, video source, subtitle source, and overlay lifetime
  On overlay close, release all Subtitle Focus cue text, measurements, ordinals, targets, and request state
  On video change, subtitle change, playback close, or playback-session replacement, cancel pending requests and release all Subtitle Focus state before the new source becomes active
  Late results from a released or superseded lifecycle must not publish

#### Motion
Cue Reel Transition Duration: --duration-subtitle-focus-scroll
Cue Reel Transition Easing: --easing-subtitle-focus-scroll
Cue Reel Step Distance: --height-subtitle-focus-cue-slot + --spacing-8 = 136px
Cue Reel Geometry: line count and clipping must not alter transition distance
Pointer Click Focus Transfer: immediate; no cue reel animation
Scrollbar Far Jump: animate only the final fixed-slot target alignment, not every skipped cue
Reduce Motion: align immediately while preserving focus and selection semantics

#### Cursor
Cue Text: pointer
Cue Reel Empty Area: default
Scrollbar Thumb: pointer
Action Menu Enabled Item: pointer
Action Menu Disabled Item: default
Overlay Background: default

#### Refresh Scope
Owner:
- Playback Subtitle Focus Overlay presentation and local interaction state.
- Subtitle Focus Cue Reel fixed-slot geometry and lazy-loaded text window.
- Table Scrollbar presentation and overlay-local preview and committed target state.
- Subtitle Focus Action Menu.
- Captured pre-overlay playback state for the lifetime of the overlay.
- Subtitle Focus Session generation and lifecycle cleanup.

Allowed invalidation:
- Enter may capture playback state, pause playback, and start one background initial-window request.
- Initial-window completion may publish one complete overlay cue snapshot.
- Opening and closing may update only overlay visibility, playback pause / resume command state, playback chrome visibility, keyboard focus, and dismiss monitors.
- Cue hover may update only the hovered cue.
- Cue selection may update only the previous cue, new cue, fixed-step cue reel transform, and scrollbar thumb.
- Cue reel animation may update only the cue reel compositing layer.
- A sequential prefetch completion may append one ten-cue batch and evict the farthest retained batch.
- The latest scrollbar target completion may replace only the overlay cue-window snapshot, committed target, and scrollbar state.
- Menu open / close may update only the menu overlay and menu dismiss monitor.
- Menu item hover and keyboard selection may update only the affected menu items.
- Shiori may update only persistence for the selected cue and its local saved-state result.
- Copy Cue Text may update only the system pasteboard.
- Play From This Cue may update only playback seek / play state and overlay dismissal.
- Overlay close or playback-source replacement may cancel requests and release only Subtitle Focus state.

Forbidden invalidation:
- Normal playback before Enter must not create Subtitle Focus queries, caches, cue views, measurements, or observable subscriptions.
- Subtitle Focus database reads must not execute on the main thread.
- Cue text line count, wrapping, and clipping must not change the fixed 104px slot height, 136px navigation step, or Focus Anchor position.
- Menu open / close must not invalidate the selected cue text color, typography, geometry, or position.
- Overlay opening, closing, cue navigation, hover, scrollbar interaction, menu interaction, and lazy loading must not resize, recreate, redraw, detach, or reattach Playback render host.
- Cue navigation and scrollbar interaction must not seek playback or write high-frequency playback time state.
- Overlay-local selection, anchor, scroll, hover, menu, cache, and loading state must not be stored in SearchStore, ShioriStore, LibraryStore, or an unrelated global playback presentation store.
- Lazy loading must not materialize or render the complete cue-text collection.
- More than 30 cue groups must not remain in the Subtitle Focus text cache after a cache update commits.
- A stale request generation, old video source, old subtitle source, dismissed overlay, or superseded target must not publish.
- Overlay interaction must not rebuild Search, Shiori, Library, tables, App Sidebar, App Topbar, normal playback chrome, or hidden workbench surfaces.

Probe / verification:
- Before the first Enter press, Subtitle Focus request count and retained cue count remain 0.
- When subtitle boundaries allow, the initial snapshot contains 10 cue groups with the selected cue as the seventh item (zero-based index 6).
- Every cue slot remains 104px high regardless of whether its text contains 1, 2, or more lines.
- Every one-cue keyboard navigation moves the cue reel by exactly 136px.
- Cue text beyond two visible lines is clipped without changing cue reel geometry.
- Retained Subtitle Focus cue-text count remains at or below 30 after each committed cache update.
- Overlay close and playback-source replacement reduce retained Subtitle Focus cue-text count to 0.
- Stale request publish count remains 0 during rapid scrollbar dragging and rapid Search video switching.
```
