# 版本
main

# 需求描述
修改表格交互。
1. 保持hover区域和点击区域，各种视觉效果上的一致。鼠标移动到非hover背景色区域不要再有hover效果和点击功能。
2. 点击左键hover区域不再弹出菜单，而是执行默认操作：Display Title单元格，Open Folder。Cues单元格，Play。Time单元格，Copy Text。Date Added单元格，Copy Text。
3. 点击右键hover的区域，而非单元格区域，弹出菜单，和当前版本左键点击的菜单保持一致。
4. 注意弹出的菜单，应该在点击位置的下方，而不是固定挂在单元格下方的某个位置。
5. 左键点击非hover区域，可以勾选/取消勾选checkbox。
6. 给Cues外的单元格，也加上hover时的下划线效果，保持一致。
7. UI具体改动，见# UI文档改动。

# UI文档改动

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
Menu Anchor: right-click pointer position inside triggering table cell content hover region
Menu Position: below right-click position, clamped to visible content bounds
Menu Open Cell Background: --color-bg-hover on triggering content hover region only

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

### 2.20 Interactive Text Cell

#### Cursor
Default / Non-interactive Area: default
Interactive Text Hover: pointer

### 3.7 Search / Shiori Table Layout

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Cell Actions: left-click default actions and right-click Row Action Menu from interactive cell hover regions
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
  Left Click Behavior: play video
  Right Click Behavior: open Row Action Menu

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
Cell Content Hit Testing: hover, pointer, underline, left-click action, and right-click menu use the same Cell Content hover region
Non-hover Cell Area Left Click: toggle row checkbox selection
Non-hover Cell Area Right Click: no cell action menu
Interactive Cell Hover: pointer cursor and underline for Display Title, Cues, Time, and Date Added
Cues Cell Left Click: Play
Cues Cell Right Click: open Cues Row Action Menu
Display Title Cell Left Click: Open Folder
Display Title Cell Right Click: open Display Title Cell Action Menu
Time Cell Left Click: Copy Text
Time Cell Right Click: open Time Cell Action Menu
Date Added Cell Left Click: Copy Text
Date Added Cell Right Click: open Date Added Cell Action Menu
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
Cell Action Menu Anchor: use the right-click pointer position inside the triggering cell content hover region; menu opens below the click position and clamps to visible content bounds