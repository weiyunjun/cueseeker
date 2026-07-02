# 版本
main

# 需求描述
1. 调整Search界面和Shiori界面的表格界面。详见# UI文档改动。
2. Search列的顺序调整：Display Title，Cues，Time。要同步调整View的弹出菜单中的顺序。
3. Shiori列的顺序调整：Display Title，Cues，Time，Date Added。要同步调整View的弹出菜单中的顺序。

# UI文档改动
### 1.1 颜色

#### Text
--color-text-primary:
  Light: #0F172A
  Dark: #F4F4F5
--color-text-secondary:
  Light: #475569
  Dark: #D4D4D8
--color-text-muted:
  Light: #667085
  Dark: #A1A1AA
--color-text-placeholder:
  Light: #98A2B3
  Dark: #71717A
--color-text-disabled:
  Light: #98A2B3
  Dark: #71717A
--color-text-readonly:
  Light: #808080
  Dark: #A1A1AA

### 1.2 尺寸、圆角、间距
#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 16px
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px

--font-size-player-time: 12px
--font-size-player-progress-time: 10px
--font-size-player-speed-menu-check: 11px
--font-size-player-speed-menu-item: 13px
--font-size-player-topbar-title: 13px

### 2.17 Table Row
#### Content
Header Text Color: --color-text-primary
Header Font Size: --font-size-table-header
Header Font Weight: 500
Primary Text Color: --color-text-primary
Primary Text Font Weight: 500
Secondary Text Color: --color-text-secondary
Secondary Text Font Weight: 400
Metadata Text Color: --color-text-secondary
Metadata Text Font Weight: 400
Metadata Numeric Variant: tabular-nums
Interactive Text Color: --color-text-primary
Interactive Text Font Weight: 500
Columns: defined by each table layout
Tags: Chip / Tag

### 2.18 Sortable Header Cell
#### Content
Text Size: --font-size-table-header
Text Weight: 500
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Default: --color-icon-default
Icon Disabled: --color-icon-disabled
Indicator Unsorted: chevrons-up-down
Indicator Asc: arrow-up
Indicator Desc: arrow-down

### 3.7 Search / Shiori Table Layout
#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Row Actions: Cues column trailing action area with Row Action Button / Row Action Menu
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
    Text Color: --color-text-primary
    Font Weight: 500

  Display Title:
    Role: secondary context
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 400

  Date Added:
    Role: metadata
    Applies To: Shiori
    Text Color: --color-text-secondary
    Font Weight: 400
    Numeric Variant: tabular-nums

  Time:
    Role: metadata
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 400
    Numeric Variant: tabular-nums

Time Column:
  Label: Time
  Source: cue start time and cue end time
  Format: hh:mm:ss - hh:mm:ss
  Short Format: mm:ss - mm:ss when both start and end hour values are 00
  Sort: by cue start time

Cues Column:
  Contains: cue text and row action trigger
  Row Action Placement: trailing area of the Cues cell
  Row Action Behavior: follows the row during vertical scrolling and follows the Cues column during horizontal scrolling

Search Empty Hint:
  Text: Enter a search term or add filters to show cues.
  Condition: no search term and no effective filter condition

Shiori Empty Hint:
  Text: Save cues from playback to collect Shiori.
  Condition: no saved Shiori rows
