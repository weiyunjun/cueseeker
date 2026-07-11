# 版本
main

# 需求描述
1. 以Cue，而非Cue Group作为基础单位，涉及多处前端和后端的调整。
2. Search界面，默认只显示命中的Cue，而非完整Cue Group。
3. Shiori界面，当前已经收藏的内容，全部为包含了日语+中文的Cue Group，数据迁移后只保留日语的部分。后续Shiori收藏的内容也不是Cue Group，而是单个Cue。tag也需要挂在对应的Cue上（目前我已经删除所有tag）。
4. Context界面，默认显示Cue，而非完整Cue Group。
5. 导出Anki，导出Screenshot，导出Collage，均针对单个或多个Cue，而非单个或多个Cue Group。Collage，需要选中的Cue位于一个字幕文件中的限制仍然成立。Copy Cue Text，是复制单个Cue的文本。回到Context的选项，回到的是对应的Cue而非Cue Group。
6. 需要在Settings - Search中，Search Scope下面提供Show Cue Group的选项，该选项默认关闭。Cue Group多出的内容，字体大小要调小，颜色也要更次级一些，与默认的Cue形成差异。
7. Search界面，Shiori界面，Context界面，高度改为动态高度，需要强制显示所有字幕内容。Cue Group多出的内容，应该显示在默认文字的上面（不要觉得奇怪，几乎所有国家的双语字幕，都是原语言显示在下面的）。
8. 播放器内的字幕焦点窗口的UI需要做额外调整：1. 显示单位从Cue Group改为Cue。2. 默认焦点选择的是当前时间戳所在Cue Group中最下面一条字幕。如果当前时间戳不位于任何字幕时间戳中，焦点选择之前的最近一条Cue。如果之前没有任何Cue，默认选中第一条Cue。3. 所有交互的对象，从Cue Group调整为Cue，例如收藏，复制文本，播放等。4. 允许焦点包含多行字幕，例如焦点字幕本身很长，或者自带换行等。5. 需要尽量保持焦点字幕在中间，类似笔记软件的打字机模式。6. 需要强制显示所有字幕内容。
9. UI详细改动见# UI文档改动

# UI文档改动

## 1. Table Row 高度 Token

修改前

```text
--height-table-header: 40px
--height-table-row: 64px
--height-action-menu-item: 40px
```

修改后

```text
--height-table-header: 40px
--min-height-table-row: 40px
--height-action-menu-item: 40px
```

## 2. 删除 Subtitle Focus 固定高度 Token

修改前

```text
--height-player-progress-time-capsule: 22px
--height-subtitle-focus-cue-slot: 104px

#### Size
```

修改后

```text
--height-player-progress-time-capsule: 22px

#### Size
```

## 3. 新增动态间距和 Padding Token

修改前

```text
--spacing-8: 32px
--gap-app-topbar-title-after-toggle: 12px
```

修改后

```text
--spacing-8: 32px
--gap-subtitle-focus-cue: 8px
--gap-app-topbar-title-after-toggle: 12px
```

修改前

```text
--padding-table-cell-hover-x: 12px
--padding-table-cell-hover-y: 6px
--padding-app-sidebar-x: 12px
```

修改后

```text
--padding-table-cell-hover-x: 12px
--padding-table-cell-hover-y: 6px
--padding-table-row-y: 8px
--padding-table-cell-leading: 12px
--padding-table-cell-trailing: 14px
--padding-subtitle-focus-cue-y: 12px
--padding-app-sidebar-x: 12px
```

## 4. 新增表格行高并明确 Focus 行高

修改前

```text
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px
```

修改后

```text
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--line-height-table-cue-primary: 24px
--line-height-table-cue-secondary: 20px
--font-size-app-sidebar-item: 13px
```

修改前

```text
--font-size-subtitle-focus-cue: 40px
--line-height-subtitle-focus-cue: 1.30
--font-weight-subtitle-focus-cue: 600
```

修改后

```text
--font-size-subtitle-focus-cue: 40px
--line-height-subtitle-focus-cue: 52px
--font-weight-subtitle-focus-cue: 600
```

## 5. 替换 Table Row 组件规则

修改前

```text
### 2.17 Table Row

#### Container
Row Height: --height-table-row
Header Height: --height-table-header
Row Hover Bg: none
Row Selected Bg: none
Header Hover Bg: none
Trigger Surface Bg: --color-bg-hover
Cell Content Hover Bg: --color-bg-hover
Cell Content Hover Radius: --radius-table-cell-hover
Cell Content Hover Padding X: --padding-table-cell-hover-x
Cell Content Hover Padding Y: --padding-table-cell-hover-y
Cell Content Hover Scope: one rounded rectangle around the union bounds of visible text / content
Interactive Cell Region: same bounds as Cell Content Hover Scope
Cell Content Hit Testing: hover, pointer, left-click action, and right-click menu only apply inside Interactive Cell Region
Non-interactive Cell Area: no cell hover, no pointer, no cell action; left click can toggle row checkbox selection
Divider Horizontal: --color-border-control
Divider Width: 1px

#### Content
Header Text Color: --color-text-primary
Header Font Size: --font-size-table-header
Header Font Weight: 500
Primary Text Color: --color-text-secondary
Primary Text Font Weight: 500
Primary Text Hover Color: --color-text-primary
Secondary Text Color: --color-text-secondary
Secondary Text Font Weight: 500
Metadata Text Color: --color-text-secondary
Metadata Text Font Weight: 500
Metadata Numeric Variant: tabular-nums
Interactive Text Color: --color-text-primary
Interactive Text Font Weight: 500
Columns: defined by each table layout
Tags: Chip / Tag
```

修改后

```text
### 2.17 Table Row

#### Container
Row Height: content-driven
Minimum Row Height: --min-height-table-row
Subtitle Row Height Formula: (2 × --padding-table-row-y) + (P × --line-height-table-cue-primary) + (S × --line-height-table-cue-secondary) = 16 + 24P + 20S
Primary Cue Visual Line Count P: the complete primary Cue visual line count; P >= 1
Extra Cue Visual Line Count S: the complete visual line count of all additional Cues displayed above the primary Cue; S >= 0
Visual Line Definition: count both source line breaks and automatic wrapping at the current Cues column width
Complete Subtitle Content: render every visual line without clipping, truncation, ellipsis, maximum line count, or character limit
Row Vertical Padding: --padding-table-row-y
Cell Leading Padding: --padding-table-cell-leading
Cell Trailing Padding: --padding-table-cell-trailing
Row Margin: 0
Header Height: --height-table-header
Row Hover Bg: none
Row Selected Bg: none
Header Hover Bg: none
Trigger Surface Bg: --color-bg-hover
Cell Content Hover Bg: --color-bg-hover
Cell Content Hover Radius: --radius-table-cell-hover
Cell Content Hover Padding X: --padding-table-cell-hover-x
Cell Content Hover Padding Y: --padding-table-cell-hover-y
Cell Content Hover Scope: one rounded rectangle around the union bounds of the interactive primary content
Interactive Cell Region: same bounds as Cell Content Hover Scope
Cell Content Hit Testing: hover, pointer, left-click action, and right-click menu only apply inside Interactive Cell Region
Non-interactive Cell Area: no cell hover, no pointer, no cell action; left click can toggle row checkbox selection
Divider Horizontal: --color-border-control
Divider Width: 1px
Divider Geometry: draw inside the resolved row height; do not add height

#### Content
Header Text Color: --color-text-primary
Header Font Size: --font-size-table-header
Header Font Weight: 500
Primary Cue Text Color: --color-text-secondary
Primary Cue Text Font Size: --font-size-table
Primary Cue Text Line Height: --line-height-table-cue-primary
Primary Cue Text Font Weight: 500
Primary Cue Text Hover Color: --color-text-primary
Extra Cue Text Color: --color-text-muted
Extra Cue Text Font Size: --font-size-caption
Extra Cue Text Line Height: --line-height-table-cue-secondary
Extra Cue Text Font Weight: 400
Extra Cue Placement: above the primary Cue
Extra Cue Ordering: preserve stable source display order among the additional Cues
Extra Cue Interaction: noninteractive context only
Primary Cue Top: Row Top + --padding-table-row-y + (S × --line-height-table-cue-secondary)
Metadata Alignment: align Display Title, Time, Date Added, Checkbox, and the first Tags row to the primary Cue's first visual line instead of the complete row center
Metadata Text Color: --color-text-secondary
Metadata Text Font Weight: 500
Metadata Numeric Variant: tabular-nums
Interactive Text Color: --color-text-primary
Interactive Text Font Weight: 500
Columns: defined by each table layout
Tags: Chip / Tag
```

## 6. 扩展 Table Row 的动态布局刷新规则

修改前

```text
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

修改后

```text
Allowed invalidation:
- Row hover may redraw only the previous row and the current row.
- Cell hover may redraw only the current row.
- Cell action menu open / close may redraw only the triggering row and the previously active row.
- Selection change may redraw the changed row and update the selection header state.
- Keyboard focus movement may redraw only the previous focused row and the current focused row.
- Cues column width changes may remeasure visible rows plus overscan and update their resolved dynamic heights.
- Show Cue Group changes may remeasure visible rows plus overscan without rebuilding the table query or row identity snapshot.
- Dynamic height changes may update the table height index, scrollbar geometry, visible row range, hover geometry, cursor rects, and menu anchors.
- Dynamic reflow must preserve a stable scroll anchor formed from the primary Cue identity and its first visual line's screen-space position.

Forbidden invalidation:
- Row hover must not invalidate the full table document.
- Row hover must not trigger row data reload, table snapshot rebuild, SearchView refresh, or Playback refresh.
- Dynamic measurement must not clip, truncate, omit, or impose a maximum line count on subtitle content.
- Width-dependent reflow and Show Cue Group changes must not change row count, result count, sorting, selection identity, primary Cue identity, or action targets.
- Dynamic reflow must not preserve only the raw scroll offset when doing so would move the anchored primary Cue on screen.
- Row-local visual state must not be stored in SearchStore, ShioriStore, LibraryStore, or PlaybackStore.
```

## 7. 扩展 Search / Shiori / Context 表格结构

修改前

```text
### 3.7 Search / Shiori Table Layout

#### Structure
Container: table region
Orientation: vertical
```

修改后

```text
### 3.7 Search / Shiori / Context Table Layout

#### Structure
Container: table region
Orientation: vertical
Applies To: Search, Shiori, and Search-hosted Context mode
Context Table: reuse Search columns, dynamic row geometry, Cue presentation, interaction rules, and scroll-anchor behavior
```

修改前

```text
Search Columns:
  Selection
  Display Title
  Cues
  Time

Shiori Columns:
```

修改后

```text
Search / Context Columns:
  Selection
  Display Title
  Cues
  Time

Shiori Columns:
```

修改前

```text
Scrollbar: Table Scrollbar
Empty State: Empty Hint
```

修改后

```text
Scrollbar: Table Scrollbar
Empty State: Empty Hint

Show Cue Group Preference:
  Location: Settings / Search, immediately below Search Scope
  Control: native macOS switch
  Label: Show Cue Group
  Default: Off
  Persistence: persist across App launches
  Applies To: Search, Shiori, and Context
  Presentation Only: changing the preference must not rerun Search, rebuild Context scope, change Shiori data, or change result count
  Off: render only the primary Cue
  On: render every additional Cue from the primary Cue's Cue Group above the primary Cue
  Primary Cue Identity: unchanged by the preference
  Selection and Action Identity: always use the primary Cue
```

## 8. 替换 Cues 列的视觉和交互规则

修改前

```text
Column Visual Priority:
  Cues:
    Role: primary content
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Hover Text Color: --color-text-primary
    Font Weight: 500

  Display Title:
    Role: secondary context
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 500

  Date Added:
    Role: metadata
    Applies To: Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums

  Tags:
    Role: user tag metadata
    Applies To: Shiori
    Cell Content: Chip / Tag

  Time:
    Role: metadata
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums
```

修改后

```text
Column Visual Priority:
  Cues / Primary Cue:
    Role: primary content
    Applies To: Search / Shiori / Context
    Text Color: --color-text-secondary
    Hover Text Color: --color-text-primary
    Font Size: --font-size-table
    Line Height: --line-height-table-cue-primary
    Font Weight: 500

  Cues / Extra Cues:
    Role: optional secondary Cue Group context
    Applies To: Search / Shiori / Context when Show Cue Group is On
    Text Color: --color-text-muted
    Font Size: --font-size-caption
    Line Height: --line-height-table-cue-secondary
    Font Weight: 400
    Placement: above the primary Cue
    Interaction: none

  Display Title:
    Role: secondary context
    Applies To: Search / Shiori / Context
    Text Color: --color-text-secondary
    Font Weight: 500

  Date Added:
    Role: metadata
    Applies To: Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums

  Tags:
    Role: user tag metadata
    Applies To: Shiori
    Cell Content: Chip / Tag

  Time:
    Role: metadata
    Applies To: Search / Shiori / Context
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums
```

修改前

```text
Cues Column:
  Contains: cue text
  Cell Hover: one rounded rectangle around visible cue text union bounds using --color-bg-hover
  Cell Hover Padding X: --padding-table-cell-hover-x
  Cell Hover Padding Y: --padding-table-cell-hover-y
  Text Hover: underline cue text
  Left Click Behavior: play video
  Right Click Behavior: open Row Action Menu
```

修改后

```text
Cues Column:
  Contains: the complete primary Cue text and, when Show Cue Group is On, the complete additional Cue texts
  Primary Cue Placement: below all additional Cues
  Primary Cue Content: preserve source line breaks and automatic wrapping without clipping or truncation
  Extra Cue Content: preserve source line breaks and automatic wrapping without clipping or truncation
  Primary Cue Cell Hover: one rounded rectangle around the complete primary Cue text bounds using --color-bg-hover
  Primary Cue Cell Hover Padding X: --padding-table-cell-hover-x
  Primary Cue Cell Hover Padding Y: --padding-table-cell-hover-y
  Primary Cue Text Hover: underline the primary Cue text
  Primary Cue Left Click Behavior: play video from the primary Cue
  Primary Cue Right Click Behavior: open the primary Cue Row Action Menu
  Extra Cue Hover: none
  Extra Cue Pointer: default
  Extra Cue Left Click Behavior: treat as noninteractive cell area
  Extra Cue Right Click Behavior: none
```

## 9. 修正 Copy Cue Text 语义

修改前

```text
Interactive Cell Hover: pointer cursor for Display Title, Cues, Time, Date Added, and Tags; underline for Display Title, Cues, Time, and Date Added only
Cues Cell Left Click: Play
Cues Cell Right Click: open Cues Row Action Menu
```

修改后

```text
Interactive Cell Hover: pointer cursor for Display Title, primary Cue text, Time, Date Added, and Tags; underline for Display Title, primary Cue text, Time, and Date Added only
Primary Cue Text Left Click: Play
Primary Cue Text Right Click: open Cues Row Action Menu for the primary Cue
Extra Cue Text Hover / Left Click / Right Click: no Cue action
```

修改前

```text
Cues Row Action Menu: Play / Context / Copy Cue Text
Display Title Cell Action Menu: Open Folder / Copy Text
Time Cell Action Menu: Copy Text
Date Added Cell Action Menu: Copy Text
Open Folder Action: open the subtitle file's containing folder and select the subtitle file
Copy Text Action: copy the triggering cell's displayed text to the clipboard
```

修改后

```text
Cues Row Action Menu: Play / Context / Copy Cue Text
Display Title Cell Action Menu: Open Folder / Copy Text
Time Cell Action Menu: Copy Text
Date Added Cell Action Menu: Copy Text
Open Folder Action: open the subtitle file's containing folder and select the subtitle file
Copy Cue Text Action: copy only the exact primary Cue text, preserving its source line order and line breaks; never include additional Cue Group context
Copy Text Action: copy the triggering non-Cues cell's displayed text to the clipboard
```

## 10. 替换 Subtitle Focus Cue 组件

修改前

```text
#### Container
Display: block
Width: 100%
Height: --height-subtitle-focus-cue-slot
Background: transparent
Border: none
Overflow: hidden
Clip: cue text at fixed slot bounds
Visual Alignment: top-leading
Hit Testing: no cue-specific pointer hover or click action
Pointer Click Routing: consume within the overlay; do not pass through to the underlying Playback video surface
Wheel Event Routing: continue to the Subtitle Focus Cue Reel
Layout Stability: every cue uses identical fixed geometry regardless of line count or selection

#### Content
Text: one complete cue group
Multi-line Cue: preserve source line order and line breaks before visual clipping
Wrapping: wrap within Playback Subtitle Focus Overlay content width
Text Alignment: top-leading
First Line Origin: fixed relative to the cue slot top edge
Visible Line Capacity: two complete lines at the declared font size and line height
Overflow Content: clip at the cue slot bounds without expanding the slot
Truncation Indicator: none
Full Cue Group Value: retain complete unclipped text for S-key Shiori, C-key Copy Cue Text, and Space-key Play From This Cue
Font Family: --font-family-base
Font Size: --font-size-subtitle-focus-cue
Line Height: --line-height-subtitle-focus-cue
Font Weight: --font-weight-subtitle-focus-cue
Selected Text Color: --color-subtitle-focus-cue-selected
Unselected Text Color: --color-subtitle-focus-cue-unselected
Background / Border / Shadow: none in every state
```

修改后

```text
#### Container
Display: block
Width: 100%
Height: content-driven
Margin: 0
Padding Y: --padding-subtitle-focus-cue-y
Cue Height: (L × --line-height-subtitle-focus-cue) + (2 × --padding-subtitle-focus-cue-y) = 52L + 24px, where L is the visual line count and L >= 1
Minimum Cue Height: 76px
Background: transparent
Border: none
Overflow: visible inside the cue reel document; clip only at the Subtitle Focus Cue Reel viewport
Visual Alignment: top-leading
Hit Testing: no cue-specific pointer hover or click action
Pointer Click Routing: consume within the overlay; do not pass through to the underlying Playback video surface
Wheel Event Routing: continue to the Subtitle Focus Cue Reel
Layout Reflow: width-dependent wrapping may change Cue Height and subsequent reel offsets without changing stable Cue identity

#### Content
Text: one complete Cue
Multi-line Cue: preserve source line order and source line breaks
Wrapping: wrap within Playback Subtitle Focus Overlay content width
Visual Line Count: include both source line breaks and automatic wrapping at the current content width
Text Alignment: top-leading
Visible Content: render every visual line
Cue-bound Clipping: none
Truncation Indicator: none
Complete Cue Value: retain the exact complete text for S-key Shiori, C-key Copy Cue Text, and Space-key Play From This Cue
Font Family: --font-family-base
Font Size: --font-size-subtitle-focus-cue
Line Height: --line-height-subtitle-focus-cue
Font Weight: --font-weight-subtitle-focus-cue
Selected Text Color: --color-subtitle-focus-cue-selected
Unselected Text Color: --color-subtitle-focus-cue-unselected
Background / Border / Shadow: none in every state
```

修改前

```text
Keyboard Action Target:
  S, C, and Space act on the selected cue's complete retained cue group value
  Action lifecycle and feedback are owned by Playback Subtitle Focus Overlay Layout
```

修改后

```text
Keyboard Action Target:
  S, C, and Space act on the selected Cue's complete retained Cue value
  Action lifecycle and feedback are owned by Playback Subtitle Focus Overlay Layout
```

修改前

```text
Allowed invalidation:
- Cue selection changes may redraw only the previous selected cue and the new selected cue.
- Text replacement may redraw only the affected fixed cue slot.

Forbidden invalidation:
- Cue text line count, wrapping, and clipping must not change cue slot height or cue reel geometry.
- Cue text line count must not move the selected cue first-line origin or Focus Anchor.
- Pointer hover and click must not update cue visual state, playback state, selected cue identity, Focus Anchor, cue reel position, scrollbar metrics, or loaded cue data.
```

修改后

```text
Allowed invalidation:
- Cue selection changes may redraw only the previous selected Cue and the new selected Cue.
- Text replacement or width-dependent wrapping may remeasure only the affected visible or overscan Cue, update its dynamic height, and update the required local reel offsets.
- Remeasurement of the selected Cue may restore its accepted Focus Placement without changing stable Cue identity.

Forbidden invalidation:
- Cue text line count and wrapping must not clip, truncate, omit, or replace Cue content.
- Dynamic remeasurement must not change the selected Cue identity or keyboard-action target.
- Pointer hover and click must not update cue visual state, playback state, selected Cue identity, Focus Anchor, cue reel position, scrollbar metrics, or loaded cue data.
```

## 11. 替换 Focus Reel、Anchor、Scrollbar 和导航

修改前

```text
Subtitle Focus Cue Reel:
  Position: centered within the overlay
  Width: min(available inset width, --width-subtitle-focus-content-max)
  Orientation: vertical
  Rendering Model: native virtual document
  Rendering Scope: layout and draw only viewport-visible cue slots plus overscan
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
  Initial Position: fixed at the vertical center of the Subtitle Focus Cue Reel viewport
  Boundary Behavior: virtual leading and trailing space keeps the first and last cue aligned to the same Focus Anchor
  Geometry Independence: cue line count and clipping must not move the Focus Anchor
  Navigation Behavior: remain fixed while keyboard, wheel, or scrollbar navigation moves the cue reel by fixed Cue Slot Pitch increments

Subtitle Focus Scrollbar Region:
  Position: trailing edge of the overlay
  Height: Subtitle Focus Cue Reel viewport height
  Contains: Table Scrollbar
  Orientation: vertical
  Visibility: persistent when cue groups exist
  Before Complete Collection Load: visible but noninteractive
  After Complete Collection Load: interactive
```

修改后

```text
Subtitle Focus Cue Reel:
  Position: centered within the overlay
  Width: min(available inset width, --width-subtitle-focus-content-max)
  Orientation: vertical
  Rendering Model: native virtual document
  Rendering Scope: measure, layout, and draw only viewport-visible Cues plus overscan and an explicit navigation or scrollbar target when required
  Cue Vertical Padding: --padding-subtitle-focus-cue-y on the top and bottom
  Cue Gap: --gap-subtitle-focus-cue
  Cue Height: 52L + 24px, where L is the Cue's visual line count
  Adjacent Cue Center Distance: current Cue Height / 2 + --gap-subtitle-focus-cue + target Cue Height / 2
  Cue Geometry: every Cue occupies one content-driven item
  Cue Overflow: expand the item to contain every visual line; clip only at the reel viewport
  Viewport Edge Behavior: partially visible leading and trailing Cues are allowed
  Text Alignment: top-leading
  Contains: Subtitle Focus Cue
  Visible Decoration: none

Focus Anchor:
  Type: logical screen-space Cue-center anchor; no visible line, indicator, background, or marker
  Initial Position: fixed at the vertical center of the Subtitle Focus Cue Reel viewport
  Fit Cue Placement: align the center of the complete selected Cue with the Focus Anchor when the Cue fits within the reel viewport
  Oversized Cue Placement: when the selected Cue is taller than the reel viewport, align its top edge with the reel viewport top when entering it, then allow continuous in-Cue reading without forcing its center onto the Focus Anchor
  Boundary Behavior: virtual leading and trailing space lets the first and last fitting Cue use the same Focus Anchor
  Geometry Response: width-dependent wrapping remeasures Cue Height and restores the selected fitting Cue to the Focus Anchor; an oversized Cue preserves its readable in-Cue position
  Navigation Behavior: remain fixed while keyboard, wheel, or scrollbar navigation moves the Cue reel by content-dependent distances

Subtitle Focus Scrollbar Region:
  Position: trailing edge of the overlay
  Height: Subtitle Focus Cue Reel viewport height
  Contains: Table Scrollbar
  Orientation: vertical
  Visibility: persistent when Cues exist
  Value Mapping: map normalized scrollbar position to stable Cue ordinal, not cumulative rendered pixel height
  Height Independence: a long Cue and a short Cue consume the same ordinal share of scrollbar progress
  Before Complete Collection Load: visible but noninteractive
  After Complete Collection Load: interactive
```

修改前

```text
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
  Discrete Wheel: any nonzero input moves at least one cue group when the corresponding document boundary permits
  Precise Scroll: follow continuous gesture and momentum movement
  Update the local focused cue when another fixed cue slot crosses the Focus Anchor
  On scroll end, settle the final cue slot first-line origin onto the Focus Anchor
  If nonzero applied movement is smaller than one Cue Slot Pitch, settle one cue group in the net movement direction
  At the first and last cue boundaries, use only movement that was actually applied
  Publish only the settled cue selection to the Subtitle Focus Session
  Do not seek or update playback time

Scrollbar Drag:
  Keep the Focus Anchor fixed
  Enable dragging only after the complete current-video cue collection is available
  Map the scrollbar position directly to the complete virtual document
  Update the native reel position and local focused cue continuously while dragging
  Do not issue database requests or publish intermediate Session selections during dragging
  On drag end, settle the nearest cue slot onto the Focus Anchor and publish the final cue selection once
  Do not seek or update playback time
```

修改后

```text
#### Cue Navigation
Variable Navigation Distance:
  Fit Cue Center Distance: current Cue Height / 2 + --gap-subtitle-focus-cue + target Cue Height / 2
  Cue text line count and wrapping determine the actual movement distance
  Oversized Cue Exception: use the target Cue's Oversized Cue Placement instead of center alignment

Up:
  Select the immediately preceding Cue
  Keep the Focus Anchor fixed
  Animate the Cue reel until the target Cue reaches its accepted Focus Placement
  If the first Cue is already selected, do nothing

Down:
  Select the immediately following Cue
  Keep the Focus Anchor fixed
  Animate the Cue reel until the target Cue reaches its accepted Focus Placement
  If the last Cue is already selected, do nothing

Pointer Wheel / Trackpad Scroll:
  Move the content-driven Cue items through the reel viewport
  Discrete Wheel for a Fit Cue: any nonzero input moves at least one Cue when the corresponding document boundary permits
  Discrete Wheel for an Oversized Cue: move through the Cue's complete content first and change Cue only after the readable boundary is crossed
  Precise Scroll: follow continuous gesture and momentum movement
  Fit Cue Focus Update: update the local focused Cue when another Cue center becomes the nearest eligible target to the Focus Anchor
  Oversized Cue Focus Update: retain the current focused Cue while continuously reading within its bounds and change Cue only after crossing its boundary
  Fit Cue Scroll End: settle the nearest Cue center onto the Focus Anchor
  Oversized Cue Scroll End: preserve the current readable in-Cue offset and do not force center settlement
  At the first and last Cue boundaries, use only movement that was actually applied
  Publish only a settled Cue selection to the Subtitle Focus Session
  Do not seek or update playback time

Scrollbar Drag:
  Keep the Focus Anchor fixed
  Enable dragging only after the complete current-video Cue collection is available
  Map normalized scrollbar position to the complete ordered Cue ordinal range, not cumulative pixel height
  Update the local target Cue and native reel preview as the mapped ordinal changes
  Do not issue database requests or publish intermediate Session selections during dragging
  On drag end, place the mapped Cue using its accepted Focus Placement and publish the final Cue selection once
  Do not seek or update playback time
```

## 12. 修改 Focus 内容单位、初始选择和操作目标

修改前

```text
Cue Text:
  Selected: --color-subtitle-focus-cue-selected
  Unselected: --color-subtitle-focus-cue-unselected
  Typography: identical across visual states
  Cue Group Integrity: render and act on one complete cue group as one item
```

修改后

```text
Cue Text:
  Selected: --color-subtitle-focus-cue-selected
  Unselected: --color-subtitle-focus-cue-unselected
  Typography: identical across visual states
  Cue Integrity: render and act on one complete Cue as one item
```

修改前

```text
Default Cue:
  Select the cue group active at the captured playback timestamp
  If no cue group is active, select the nearest cue group whose start time is before the captured timestamp

Initial Position:
  Align the default selected cue first-line origin with the initial Focus Anchor
  Keep the Focus Anchor fixed at the vertical center
  Use virtual leading and trailing space so the first and last cue use the same Focus Anchor
  Do not derive position from cue text height or line count

Initial Cue Window:
  Cue Group Count: exactly 10 total when at least 10 cue groups exist; otherwise load all available cue groups
  Preferred Distribution: 6 cue groups before the selected cue, the selected cue, and 3 cue groups after it
  Selected Cue Position: seventh item when at least 6 preceding cue groups exist
  Boundary Distribution: when either boundary lacks enough cue groups, fill the remaining slots from the opposite side
  Cue Geometry: every loaded cue occupies one fixed 104px slot
  Viewport Clipping: clip the fixed ten-slot reel to the available viewport; partial leading and trailing slots are allowed
  Selection Stability: identify the selected cue by stable cue group identity and stable ordinal, not transient loaded-window index
```

修改后

```text
Default Cue:
  If the captured playback timestamp lies within a Cue Group, select the physically bottommost Cue in that group according to stable source display order
  If the captured playback timestamp lies within no Cue, select the nearest preceding Cue in stable subtitle order
  If no preceding Cue exists, select the first Cue

Initial Position:
  Keep the Focus Anchor fixed at the vertical center
  If the default selected Cue fits within the reel viewport, align the center of the complete Cue with the Focus Anchor
  If the default selected Cue is taller than the reel viewport, align its top edge with the reel viewport top
  Use virtual leading and trailing space so the first and last fitting Cue use the same Focus Anchor
  Derive Cue Height and initial reel position from the current visual line count and content width

Initial Cue Window:
  Cue Count: exactly 10 total when at least 10 Cues exist; otherwise load all available Cues
  Preferred Distribution: 6 Cues before the selected Cue, the selected Cue, and 3 Cues after it
  Selected Cue Position: seventh item when at least 6 preceding Cues exist
  Boundary Distribution: when either boundary lacks enough Cues, fill the remaining items from the opposite side
  Cue Geometry: every loaded Cue uses its content-driven 52L + 24px height
  Viewport Clipping: clip only at the available reel viewport; partial leading and trailing Cues are allowed and no Cue text is truncated
  Selection Stability: identify the selected Cue by stable Cue identity and stable ordinal, not transient loaded-window index
```

修改前

```text
Action Target:
  Use the exact focused cue group after its first-line origin is settled on the Focus Anchor
  Identify the target by stable cue group identity and stable ordinal
  Retain the exact cue text and start time required by the accepted action
  Do not resolve the action target from current playback time or a transient loaded-window index
  If cue reel navigation or settlement is active, defer the accepted action until the existing final target settles, then execute the action once against that settled cue
  Complete-cue publication must not retarget an accepted action
  Cancel a deferred action if the Subtitle Focus Session closes or is superseded before settlement

S in Cue Selection:
  Save the exact focused cue group without toggling or removing an existing Shiori
  If the cue is not saved, persist it once and show Shiori Saved
  If the cue is already saved, do not write a duplicate and show Shiori Already Saved
  Keep the Subtitle Focus Overlay visible
  Keep playback paused
  Keep the focused cue, Focus Anchor, cue reel position, and scrollbar position unchanged

C in Cue Selection:
  Copy the exact focused cue group's complete multi-line text, preserving source line order and line breaks
  Show Subtitle Copied
  Keep the Subtitle Focus Overlay visible
  Keep playback paused
  Keep the focused cue, Focus Anchor, cue reel position, and scrollbar position unchanged

Space in Cue Selection:
  Seek to the exact focused cue group's start time
  Close the Subtitle Focus Overlay
  Begin continuous playback from that time regardless of the captured playback state
  Show Play
```

修改后

```text
Action Target:
  Use the exact focused Cue after its accepted Focus Placement has settled
  Identify the target by stable Cue identity and stable ordinal
  Retain the exact Cue text and start time required by the accepted action
  Do not resolve the action target from current playback time or a transient loaded-window index
  If Cue reel navigation or settlement is active, defer the accepted action until the existing final target settles, then execute the action once against that settled Cue
  Complete-Cue publication must not retarget an accepted action
  Cancel a deferred action if the Subtitle Focus Session closes or is superseded before settlement

S in Cue Selection:
  Save the exact focused Cue without toggling or removing an existing Shiori
  If the Cue is not saved, persist it once and show Shiori Saved
  If the Cue is already saved, do not write a duplicate and show Shiori Already Saved
  Keep the Subtitle Focus Overlay visible
  Keep playback paused
  Keep the focused Cue, Focus Anchor, Cue reel position, and scrollbar position unchanged

C in Cue Selection:
  Copy the exact focused Cue's complete multi-line text, preserving source line order and line breaks
  Show Subtitle Copied
  Keep the Subtitle Focus Overlay visible
  Keep playback paused
  Keep the focused Cue, Focus Anchor, Cue reel position, and scrollbar position unchanged

Space in Cue Selection:
  Seek to the exact focused Cue's start time
  Close the Subtitle Focus Overlay
  Begin continuous playback from that time regardless of the captured playback state
  Show Play
```

## 13. 修改 Focus 数据加载和 Motion

修改前

```text
Initial Cue Window:
  Load exactly 10 cue groups around the default selected cue when at least 10 cue groups exist
  Load all available cue groups when the subtitle contains fewer than 10 cue groups
  Prefer 6 preceding cue groups and 3 following cue groups
  Place the selected cue seventh when available
  Fill missing boundary slots from the opposite side
  Give every cue one fixed --height-subtitle-focus-cue-slot slot
  Publish the complete initial cue window as one stable snapshot

Complete Current-video Load:
  Begin one background complete-cue read after the initial cue window is published
  Load and retain the complete ordered cue-content collection for the current subtitle source
  Publish the complete collection atomically only when the playback source, subtitle source, and Subtitle Focus Session still match
  Do not use ten-cue prefetch batches, a thirty-cue retention limit, eviction, target-window reads, or scrollbar debounce
  If complete loading fails, keep the initial cue window visible and the scrollbar noninteractive

Virtual Rendering:
  Define the complete virtual document from total cue count and fixed Cue Slot Pitch
  Retaining the complete cue-content collection must not create one cue view or text-layout object per cue
  Layout and draw only viewport-visible cue slots plus overscan
  Total cue count must not increase the number of cue slots actually laid out or drawn
```

修改后

```text
Initial Cue Window:
  Load exactly 10 Cues around the default selected Cue when at least 10 Cues exist
  Load all available Cues when the subtitle contains fewer than 10 Cues
  Prefer 6 preceding Cues and 3 following Cues
  Place the selected Cue seventh when available
  Fill missing boundary items from the opposite side
  Measure every visible or overscan Cue from its complete text using the current content width and 52L + 24px height rule
  Publish the complete initial Cue window as one stable snapshot

Complete Current-video Load:
  Begin one background complete-Cue read after the initial Cue window is published
  Load and retain the complete ordered Cue-content collection for the current subtitle source
  Publish the complete collection atomically only when the playback source, subtitle source, and Subtitle Focus Session still match
  Do not use ten-Cue prefetch batches, a thirty-Cue retention limit, eviction, target-window reads, or scrollbar debounce
  If complete loading fails, keep the initial Cue window visible and the scrollbar noninteractive

Virtual Rendering:
  Define the complete logical virtual document from total Cue count and stable Cue ordinal
  Resolve content-driven geometry for viewport-visible Cues plus overscan and an explicit navigation or scrollbar target when required
  Retaining the complete Cue-content collection must not create one Cue view or retained text-layout object per Cue
  Layout and draw only viewport-visible Cues plus overscan
  Scrollbar ordinal mapping must not require cumulative pixel-height layout of the complete Cue collection
  Total Cue count must not increase the number of Cue items actually laid out or drawn
```

修改前

```text
#### Motion
Cue Reel Transition Duration: --duration-subtitle-focus-scroll
Cue Reel Transition Easing: --easing-subtitle-focus-scroll
Cue Reel Step Distance: --height-subtitle-focus-cue-slot + --spacing-8 = 136px
Cue Reel Geometry: line count and clipping must not alter transition distance
Keyboard / Discrete Wheel Alignment: animate the final fixed-slot target alignment
Precise Wheel / Scrollbar Drag: follow continuous native reel offset directly
Scrollbar Release Settlement: align only the final nearest cue slot, not every skipped cue
Keyboard Action Settlement: if S, C, or Space is accepted while cue motion has an unresolved final target, complete the existing settlement first and execute once against the resulting settled focused cue
Cue Pointer Hover / Click: no visual transition, focus transfer, selection transition, or cue reel animation
Reduce Motion: resolve final alignment and any accepted deferred keyboard action immediately while preserving focus, selection, and continuous drag semantics
```

修改后

```text
#### Motion
Cue Reel Transition Duration: --duration-subtitle-focus-scroll
Cue Reel Transition Easing: --easing-subtitle-focus-scroll
Cue Reel Step Distance: content-dependent; for two fitting Cues, use current Cue Height / 2 + --gap-subtitle-focus-cue + target Cue Height / 2
Cue Reel Geometry: visual line count and wrapping determine Cue Height and transition distance
Keyboard / Discrete Wheel Alignment: animate the final target to its accepted Focus Placement
Precise Wheel: follow continuous native reel offset directly
Scrollbar Drag: preview the Cue mapped from normalized stable ordinal rather than cumulative pixel height
Fit Cue Scrollbar Release Settlement: align only the final mapped Cue center with the Focus Anchor
Oversized Cue Settlement: preserve the readable in-Cue offset during continuous reading and do not force center settlement
Width-dependent Reflow: preserve stable selected Cue identity, then restore its accepted Focus Placement
Keyboard Action Settlement: if S, C, or Space is accepted while Cue motion has an unresolved final target, complete the existing settlement first and execute once against the resulting settled focused Cue
Cue Pointer Hover / Click: no visual transition, focus transfer, selection transition, or Cue reel animation
Reduce Motion: resolve final placement and any accepted deferred keyboard action immediately while preserving focus, selection, in-Cue reading, and continuous drag semantics
```

## 14. 修改 Focus Refresh Scope 和验收项

修改前

```text
- Subtitle Focus native virtual document and fixed-slot cue geometry.
```

修改后

```text
- Subtitle Focus native virtual document and content-driven Cue geometry.
```

修改前

```text
- C may write only the exact focused cue group's complete text to the system pasteboard and publish Subtitle Copied to the shared playback feedback surface.
```

修改后

```text
- C may write only the exact focused Cue's complete text to the system pasteboard and publish Subtitle Copied to the shared playback feedback surface.
```

修改前

```text
- Cue text line count, wrapping, and clipping must not change the fixed 104px slot height, 136px navigation step, or Focus Anchor position.
```

修改后

```text
- Cue text line count and wrapping may change dynamic Cue Height and navigation distance, but must not move the screen-space Focus Anchor, change stable Cue identity, clip text, truncate text, or retarget an accepted keyboard action.
- Scrollbar progress must not be derived from cumulative rendered Cue height.
```

修改前

```text
Probe / verification:
- Before the first Enter press, Subtitle Focus request count and retained cue count remain 0.
- When subtitle boundaries allow, the initial snapshot contains 10 cue groups with the selected cue as the seventh item (zero-based index 6).
- Every cue slot remains 104px high regardless of whether its text contains 1, 2, or more lines.
- Every one-cue keyboard navigation moves the cue reel by exactly 136px.
- Cue text beyond two visible lines is clipped without changing cue reel geometry.
- Cue hover and click produce no cue redraw, selection change, Focus Anchor change, action UI, playback command, or pointer-event pass-through while wheel and scrollbar navigation remain available.
- Enter while Cue Selection is visible produces no menu, dismissal, playback command, or selection change.
- Down followed immediately by S saves the cue that settles on the Focus Anchor, not the previously settled cue.
- S on an unsaved focused cue keeps the overlay visible and playback paused and shows Shiori Saved above the overlay.
- S on an already saved focused cue creates no duplicate, keeps the overlay visible and playback paused and shows Shiori Already Saved above the overlay.
- C copies the focused cue's complete multi-line text, keeps the overlay visible and playback paused and shows Subtitle Copied above the overlay.
- Space seeks to the exact focused cue start time, closes the overlay, begins continuous playback, and shows Play.
- After complete-cue publication, retained cue count equals the current subtitle's total cue count and scrollbar interaction is enabled.
- Increasing the virtual document to 50,000 cue groups does not increase visible-plus-overscan layout or draw count.
- Continuous scrollbar drag updates the reel without intermediate Session selection commits; mouse-up publishes exactly one final selection.
- Overlay close and playback-source replacement reduce retained Subtitle Focus cue count to 0.
- Late initial or complete result publish count and stale deferred-action dispatch count remain 0 during rapid video switching.
```

修改后

```text
Probe / verification:
- Before the first Enter press, Subtitle Focus request count and retained Cue count remain 0.
- When subtitle boundaries allow, the initial snapshot contains 10 Cues with the selected Cue as the seventh item (zero-based index 6).
- A one-line Cue is 76px high, a two-line Cue is 128px high, and a three-line Cue is 180px high.
- Center-to-center navigation distance is 84px for one-line to one-line, 110px for one-line to two-line, and 162px for two-line to three-line Cues.
- Source line breaks and automatic wrapping both increase visual line count, and every resulting line remains available without Cue-bound clipping or truncation.
- A selected Cue that fits within the reel viewport has its complete Cue center aligned with the Focus Anchor.
- Resizing the overlay preserves stable selected Cue identity, recomputes visual line count, and restores the selected fitting Cue to the Focus Anchor.
- Entering a Cue taller than the reel viewport aligns its top edge to the reel viewport top.
- Continuous wheel or trackpad scrolling can traverse every line of an oversized Cue without forced center settlement, and selection changes only after the Cue boundary is crossed.
- Cue hover and click produce no Cue redraw, selection change, Focus Anchor change, action UI, playback command, or pointer-event pass-through while wheel and scrollbar navigation remain available.
- Enter while Cue Selection is visible produces no menu, dismissal, playback command, or selection change.
- Down followed immediately by S saves the Cue that settles at its accepted Focus Placement, not the previously settled Cue.
- S on an unsaved focused Cue keeps the overlay visible and playback paused and shows Shiori Saved above the overlay.
- S on an already saved focused Cue creates no duplicate, keeps the overlay visible and playback paused and shows Shiori Already Saved above the overlay.
- C copies the focused Cue's complete multi-line text, keeps the overlay visible and playback paused and shows Subtitle Copied above the overlay.
- Space seeks to the exact focused Cue start time, closes the overlay, begins continuous playback, and shows Play.
- After complete-Cue publication, retained Cue count equals the current subtitle's total Cue count and scrollbar interaction is enabled.
- Dragging the scrollbar to 50% maps to the midpoint Cue ordinal regardless of the Cue height distribution.
- Increasing the virtual document to 50,000 Cues does not increase visible-plus-overscan layout or draw count.
- Continuous scrollbar drag updates the reel without intermediate Session selection commits; mouse-up publishes exactly one final selection.
- Overlay close and playback-source replacement reduce retained Subtitle Focus Cue count to 0.
- Late initial or complete result publish count and stale deferred-action dispatch count remain 0 during rapid video switching.
```

## 15. 补充全局 Refresh Scope

修改前

```text
- Layout-local: window width, sidebar collapse, topbar visibility, route frame.
```

修改后

```text
- Layout-local: window width, sidebar collapse, topbar visibility, route frame, Cues column wrapping, dynamic table row measurement, Subtitle Focus Cue measurement, and scroll-anchor restoration.
```

修改前

```text
- Hidden Search, Shiori, and Library surfaces may defer data refresh until they become visible.
```

修改后

```text
- Hidden Search, Shiori, Context, and Library surfaces may defer data refresh until they become visible.
```

修改前

```text
- Record table snapshot rebuilds, row hydration, library snapshot rebuilds, playback render host updates, and high-frequency playback chrome updates.
```

修改后

```text
- Record table snapshot rebuilds, row hydration, dynamic row measurement, scroll-anchor correction, Subtitle Focus Cue measurement, library snapshot rebuilds, playback render host updates, and high-frequency playback chrome updates.
- Verify that width-dependent reflow and Show Cue Group changes preserve the anchored primary Cue's screen-space position.
- Verify that Subtitle Focus width-dependent reflow preserves stable selected Cue identity and restores its accepted Focus Placement.
```
