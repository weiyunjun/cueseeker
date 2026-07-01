# 版本
main

# 需求描述
Search和Shiori界面的...按钮，从overlay，改为放在Cues列的最右侧。

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
Row Actions: Cues column trailing action area with Row Action Button / Row Action Menu
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

#### Interaction
Header: sort / column menu
Rows: hover / select
Row Actions: always visible in each row; placed inside the trailing area of the Cues column
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
