# 版本
main

# 需求描述
1. App窗口的最小宽度，降为480pt。
2. 当宽度小于等于760pt时，左边栏自动收起，且宽度增加到760pt以上后，边栏不会自动展开（即自动收起是一次性的动作。没有后续）。
3. 表格部分，Cues列，最小宽度为520pt，这意味着当App窗口达到最小宽度时，无法直接完整显示这一列，这是可以接受的，因为有进度条的存在，用户也可以自行处理宽度以满足需求。
4. 表格的其他列为固定宽度。checkbox列：50pt。Display Title列：240pt。Time列：190pt。Date Added列：160pt
5. UI详细改动见# UI文档改动。

# UI文档改动

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
  Selection
  Display Title
  Cues
  Time

Shiori Columns:
  Selection
  Display Title
  Cues
  Time
  Date Added

Column Widths:
  Selection:
    Width: 50pt
    Fixed: yes

  Display Title:
    Width: 240pt
    Fixed: yes

  Time:
    Width: 190pt
    Fixed: yes

  Date Added:
    Applies To: Shiori
    Width: 160pt
    Fixed: yes

  Cues:
    Minimum Width: 520pt
    Flexible: yes
    Behavior: expands to fill remaining table content width

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