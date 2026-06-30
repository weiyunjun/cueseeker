# 版本
main

# 需求描述
1. Search和Shiori界面，hover时出现的的...按钮，改为常驻在最右侧（即便出现横向滚动条也固定在那个位置，否则会导致操作问题），位置和现在大致相同，位于滚动条左侧，每个row的...按钮都常驻。
2. 合并Start Time和End Time列为Time列（不要用Timestamp这么专业的词，一般用户看着会很抗拒），显示的数据格式是：hh:mm:ss - hh:mm:ss，如果2个hh均为00则只显示mm:ss - mm:ss。

# 相关UI文档改动

### 3.7 Search / Shiori Table Layout

#### Structure
Container: table region
Orientation: vertical

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Row Actions: fixed trailing action column with Row Action Button / Row Action Menu
Scrollbar: Table Scrollbar
Empty State: Empty Hint

Search Columns:
  Display Title
  Time
  Cues
  Speaker
  Language

Shiori Columns:
  Date Added
  Display Title
  Time
  Cues
  Language

Time Column:
  Label: Time
  Source: cue start time and cue end time
  Format: hh:mm:ss - hh:mm:ss
  Short Format: mm:ss - mm:ss when both start and end hour values are 00
  Sort: by cue start time

Search Empty Hint:
  Text: Enter a search term or add filters to show cues.
  Condition: no search term and no effective filter condition

Shiori Empty Hint:
  Text: Save cues from playback to collect Shiori.
  Condition: no saved Shiori rows

#### Interaction
Header: sort / column menu
Rows: hover / select
Row Actions: always visible in each row; fixed at the trailing edge of the table region, left of the vertical scrollbar
Text Cell: click cue text
View Menu: Cues is checked + disabled; row actions cannot be hidden; other data columns can be hidden
Search Row Action Menu: Copy Cue Text
Shiori Row Action Menu: Copy Cue Text / Remove Shiori
Remove Shiori Icon: bookmark.slash
Remove Shiori Icon Fallback: bookmark
Shiori Remove: remove the row from saved Shiori records and refresh the Shiori table
Shiori Default Sort: Date Added, newest to oldest
Scrollbar: virtualized table scrolling

#### Effective Filter Condition
An effective filter condition is any filter rule that can constrain results.
A filter rule with a non-empty value is effective.
A presence-style filter rule that does not require a value is effective when selected, for example Cues is not empty.

#### Cursor
Inherited from child components
