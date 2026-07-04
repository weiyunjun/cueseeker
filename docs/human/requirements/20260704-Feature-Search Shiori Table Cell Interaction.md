# 版本
main

# 需求描述
1. 取消表格的整体的hover和selected效果。
2. 删除Cues的...按钮。
3. 每个单元格的内容会有单独的hover效果，和现在的hover表头文字区域的效果颜色一致，圆角矩形。
4. 点击Cues单元格，从直接播放视频改为弹出一个菜单，在...按钮的菜单基础上，增加了一个Play选项。
5. Display Title，2个菜单：Open Folder，Copy Text。Open Folder用Library那个文件夹图标，点击后打开字幕所在文件夹并选中该字幕。Copy Text用Copy Cue Text那个图标，点击后将文字复制到剪贴板。
6. Time，1个菜单：Copy Text。Copy Text用Copy Cue Text那个图标，点击后将文字复制到剪贴板。
7. Date Added，1个菜单：Copy Text。Copy Text用Copy Cue Text那个图标，点击后将文字复制到剪贴板。
8. 详见# UI文档改动。

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
--radius-table-cell-hover: 8px
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
--padding-table-cell-hover-x: 12px
--padding-table-cell-hover-y: 6px
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
Menu Anchor: triggering table cell content region
Menu Open Cell Background: --color-bg-hover

#### Content
Play Icon: play.fill
Copy Cue Text Icon: copy
Copy Text Icon: copy
Open Context Icon: search
Open Folder Icon: folder
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
Header Hover Bg: none
Trigger Surface Bg: --color-bg-hover
Cell Content Hover Bg: --color-bg-hover
Cell Content Hover Radius: --radius-table-cell-hover
Cell Content Hover Padding X: --padding-table-cell-hover-x
Cell Content Hover Padding Y: --padding-table-cell-hover-y
Cell Content Hover Scope: one rounded rectangle around the union bounds of visible text / content
Divider Horizontal: --color-border-control
Divider Width: 1px

#### Status
Default
Header Hover / Header Area: no background
Header Hover / Trigger Surface
Body Hover: no full-row background
Body Selected: no full-row background
Cell Content Hover

### 2.18 Sortable Header Cell

#### Container
Header Height: --height-table-header
Trigger Padding X: --padding-header-trigger-x
Trigger Bg Hover / Menu Open: --color-bg-hover
Row Bg Hover: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

### 2.20 Interactive Text Cell

#### Container
Background Default: transparent
Background Hover: --color-bg-hover
Radius Hover: --radius-table-cell-hover
Padding X Hover: --padding-table-cell-hover-x
Padding Y Hover: --padding-table-cell-hover-y
Scope: one rounded rectangle around the union bounds of visible text / content; does not fill the full cell or full row
Multi-line Text: one unified rounded rectangle, not separate per-line backgrounds

#### Content
Text Default: --color-text-primary
Text Hover: --color-text-primary
Underline Hover: same as text color
Text Decoration: underline
Decoration Thickness: --width-interactive-text-underline
Decoration Offset: --offset-interactive-text-underline

#### Status
Default
Hover (Underline)

### 3.7 Search / Shiori Table Layout

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Cell Actions: Row Action Menu opened from interactive data cells
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
  Cell Hover: one rounded rectangle around visible cue text union bounds using --color-bg-hover
  Cell Hover Padding X: --padding-table-cell-hover-x
  Cell Hover Padding Y: --padding-table-cell-hover-y
  Text Hover: underline cue text
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
Header Area: no hover background
Cell Content: hover shows one rounded rectangle around visible text / content union bounds using --color-bg-hover
Cues Cell: pointer cursor; hover underlines cue text; click opens Row Action Menu
Display Title Cell: pointer cursor; click opens Display Title Cell Action Menu
Time Cell: pointer cursor; click opens Time Cell Action Menu
Date Added Cell: pointer cursor; click opens Date Added Cell Action Menu
Other Data Cells: reserved for future cell menus; no action defined yet
View Menu: Cues is checked + disabled; other data columns can be hidden
Cues Row Action Menu: Play / Context / Copy Cue Text
Display Title Cell Action Menu: Open Folder / Copy Text
Time Cell Action Menu: Copy Text
Date Added Cell Action Menu: Copy Text
Open Folder Action: open the subtitle file's containing folder and select the subtitle file
Copy Text Action: copy the triggering cell's displayed text to the clipboard
Shiori Row Action Menu Extra Item: Remove Shiori
Remove Shiori Icon: bookmark.slash
Remove Shiori Icon Fallback: bookmark
Shiori Remove: remove the row from saved Shiori records and refresh the Shiori table
Cell Action Menu Anchor: use the triggering cell content hover rectangle as the menu anchor; menu gap uses the existing menu spacing token
