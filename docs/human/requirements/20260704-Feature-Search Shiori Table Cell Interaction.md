# 版本
main

# 需求描述
1. 取消表格的整体的hover和selected效果。
2. 删除Cues的...按钮。
3. 每个单元格的内容会有单独的hover效果，和现在的hover表格整列的效果颜色一致，圆角矩形。
4. 点击Cues单元格，从直接播放视频改为弹出一个菜单，在...按钮的菜单基础上，增加了一个Play选项。
5. 取消Cues单元格hover时的下划线，鼠标样式还是保留。
6. 点击其它列的单元格后续也会有菜单，暂时还没想好做什么。
7. 修改部分UI界面颜色，详见# UI文档改动。

# UI文档改动

### 1.2 尺寸、圆角、间距
#### Radius
--radius-control: 8px
--radius-field: 8px
--radius-search: 9999px
--radius-inline-clear-button: 9999px
--radius-checkbox: 4px
--radius-menu: 16px
--radius-select-menu-item: 8px
--radius-action-menu-item: 8px
--radius-row-action: 8px
--radius-table-cell-hover: 6px
--radius-chip: 6px
--scrollbar-radius: 9999px
--radius-app-sidebar-item: 8px

--radius-player-capsule: 9999px
--radius-player-speed-menu: 14px
--radius-player-speed-menu-item: 8px

#### Padding
--padding-control-x: 14px
--padding-field-x: 16px
--padding-menu-item: 12px 16px
--padding-header-trigger-x: 12px
--padding-chip-x: 10px
--padding-chip-y: 4px
--padding-table-cell-hover: 4px
--padding-app-sidebar-x: 12px
--padding-app-sidebar-y: 12px
--padding-app-sidebar-item-x: 10px
--padding-app-topbar-title-x: 24px

--padding-player-chrome-x: 24px
--padding-player-chrome-bottom: 12px
--padding-player-progress-top: 16px
--padding-player-capsule-button-x: 16px
--padding-player-speed-menu: 6px
--padding-player-speed-menu-item-x: 8px
--padding-player-progress-time-capsule-x: 8px
--padding-player-topbar-x: 16px

### 2.16 Row Action Menu

#### Container
Menu Background: --color-bg-popover
Menu Border: --color-border-muted
Menu Border Radius: --radius-menu
Menu Shadow: --shadow-popover
Menu Padding: --spacing-1
Menu Min Width: fit-content
Menu Item Height: --height-action-menu-item
Menu Item Padding: --padding-menu-item
Menu Item Radius: --radius-action-menu-item
Menu Item Hover Background: --color-bg-hover
Divider: --color-border-divider
Menu Anchor: Cues cell content region
Menu Open Cell Background: --color-row-hover

#### Content
Play Icon: play.fill
Copy Cue Text Icon: copy
Open Context Icon: search
Favorite Icon: star
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Disabled: --color-text-disabled
Menu Item Icon Color Default: --color-text-primary
Menu Item Icon Color Disabled: --color-icon-disabled

#### Status
Default Menu
Hover / Highlighted Item
Menu Open (from Cues Cell)

### 2.17 Table Row

#### Container
Row Height: --height-table-row
Header Height: --height-table-header
Row Hover Bg: none
Row Selected Bg: none
Header Hover Bg: --color-row-hover
Cell Content Hover Bg: --color-row-hover
Cell Content Hover Radius: --radius-table-cell-hover
Cell Content Hover Inset: --padding-table-cell-hover
Trigger Surface Bg: --color-bg-hover
Divider Horizontal: --color-border-control
Divider Width: 1px

#### Status
Default
Header Hover / Header Area
Header Hover / Trigger Surface
Body Hover: no full-row background
Body Selected: no full-row background
Cell Content Hover

### 2.20 Interactive Text Cell

#### Container
Background Default: transparent
Background Hover: --color-row-hover
Radius Hover: --radius-table-cell-hover
Padding / Inset Hover: --padding-table-cell-hover
Scope: hovered cell content area only; does not fill the full row

#### Content
Text Default: --color-text-primary
Text Hover: --color-text-primary
Underline Hover: none
Text Decoration: none

#### Status
Default
Hover

### 3.7 Search / Shiori Table Layout

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Row Actions: Row Action Menu opened from the Cues cell
Scrollbar: Table Scrollbar
Empty State: Empty Hint

Search Columns:
  Display Title
  Cues
  Time

Shiori Columns:
  Display Title
  Cues
  Time
  Date Added

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

  Time:
    Role: metadata
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums

Time Column:
  Label: Time
  Source: cue start time and cue end time
  Format: hh:mm:ss - hh:mm:ss
  Short Format: mm:ss - mm:ss when both start and end hour values are 00
  Sort: by cue start time

Cues Column:
  Contains: cue text
  Cell Hover: rounded cell content background using --color-row-hover
  Click Behavior: open Row Action Menu
  Play Behavior: use the Play menu item to open video playback

Search Empty Hint:
  Text: Enter a search term or add filters to show cues.
  Condition: no search term and no effective filter condition

Shiori Empty Hint:
  Text: Save cues from playback to collect Shiori.
  Condition: no saved Shiori rows

#### Interaction
Header: sort / column menu
Rows: no full-row hover or selected background
Cell Content: hover shows rounded content background
Cues Cell: pointer cursor; click opens Row Action Menu
Other Data Cells: reserved for future cell menus; no action defined yet
View Menu: Cues is checked + disabled; other data columns can be hidden
Search Row Action Menu: Play / Copy Cue Text
Shiori Row Action Menu: Play / Copy Cue Text / Remove Shiori
Remove Shiori Icon: bookmark.slash
Remove Shiori Icon Fallback: bookmark
Shiori Remove: remove the row from saved Shiori records and refresh the Shiori table
