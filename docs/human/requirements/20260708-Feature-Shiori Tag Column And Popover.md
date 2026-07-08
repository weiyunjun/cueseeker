# 版本
main

# 需求描述
给Shiori界面加一个Tag列及相关功能。
1. 它类似Notion的逻辑，鼠标左键点击Tag列的单元格后，会弹出一个界面，用于创建，添加，删除tag。
2. 每个Shiori允许分配多个tag。
3. 点击单元格以后，弹出菜单的界面包含从上到下的2栏：1. 当前Shiori包含的tags，输入框（用于搜索tag或创建tag）2. --muted的字体Select a tag or create one，所有已创建tags。
4. 第一栏，输入内容后，下面显示匹配的内容，以及Create [xxx]的选项。点击匹配的内容添加该tag，点击Create [xxx]的选项创建该tag并添加该tag。不论点击哪一个以后，都会清空输入的内容。
5. 所有在这个弹出菜单界面的tag（第1栏和第2栏），都要包含x按钮。
6. 在第1栏点击tag的x按钮，会直接解除该Shiori的tag。在第2栏点击tag的x按钮，会弹出警告界面，标题是Delete Tag，内容是Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone. 这里用Confirmation Dialog Layout作为警告界面。
7. 表格中，而非弹出菜单中显示的tag，不要带x按钮。
8. tag列的宽度要固定为180 pt。
9. 弹出菜单，第二栏，标签不要做那种垂直列表的，而是和第一栏一样平铺.
10. 弹出菜单，第二栏，点击已选标签，不会有任何提示或实质性改变。


# UI文档修改

**1. `### 2.22 Chip / Tag`**

修改前：

```markdown
#### Content
Font Family: --font-family-base
Font Size: --font-size-caption
Speaker Background: --color-chip-speaker-bg
Speaker Text: --color-chip-speaker-text
Language Background: --color-chip-language-bg
Language Text: --color-chip-language-text
Disabled Background: --color-bg-disabled
Disabled Text: --color-text-disabled
```

修改后：

```markdown
#### Content
Font Family: --font-family-base
Font Size: --font-size-caption
Speaker Background: --color-chip-speaker-bg
Speaker Text: --color-chip-speaker-text
Language Background: --color-chip-language-bg
Language Text: --color-chip-language-text
Shiori Tag Background: --color-bg-hover
Shiori Tag Text: --color-text-secondary
Disabled Background: --color-bg-disabled
Disabled Text: --color-text-disabled
Remove Button Icon: x
Remove Button Icon Color Default: --color-icon-muted
Remove Button Icon Color Hover: --color-danger-text
Remove Button Background Hover: --color-danger-bg-hover
Non-removable Layout: [label]
Removable Layout: [label | x]
```

修改前：

```markdown
#### Status
Speaker / Default
Language / Default
Speaker / Disabled
Language / Disabled
```

修改后：

```markdown
#### Status
Speaker / Default
Language / Default
Speaker / Disabled
Language / Disabled
Shiori Tag / Default
Shiori Tag / Hover
Shiori Tag / Removable
Shiori Tag Remove Button / Hover
Shiori Tag / Disabled
```

修改前：

```markdown
#### Cursor
default
```

修改后：

```markdown
#### Cursor
Default: default
Interactive Tag Body: pointer
Remove Button: pointer
Disabled: default
```

新增：

```markdown
#### Interaction
Non-removable Tag: display label only; no x button
Removable Tag: display label and x remove button
Tag Body Click: delegated to the owning layout
Remove Button Click: delegated to the owning layout
Remove Button Hit Area: only the x button; must not trigger tag body click
```

新增：

```markdown
#### Refresh Scope
Owner:
- Direct chip owner: table cell, tag popover section, or dialog command target.

Allowed invalidation:
- Chip hover may update only the hovered chip.
- Remove button hover may update only the hovered remove button.
- Tag body click may execute only the action declared by the owning layout.
- Remove button click may execute only the remove or delete action declared by the owning layout.

Forbidden invalidation:
- Chip hover must not reload table rows or rebuild table snapshots.
- Remove button hover must not update row selection, Search, Shiori, Library, or Playback state.
- Remove button click must not also trigger tag body click.
```

**2. `### 3.7 Search / Shiori Table Layout`**

#### Content

修改前：

```markdown
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
```

修改后：

```markdown
#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Cell Actions: left-click default actions, Shiori Tags popover, and right-click Row Action Menu from declared interactive cell hover regions
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
  Tags

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

  Tags:
    Applies To: Shiori
    Width: 180pt
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

Tags Column:
  Applies To: Shiori
  Identifier: tags
  Label: Tags
  Source: tags associated with the Shiori cue
  Cell Content: horizontally tiled Chip / Tag items
  Cell Tags: non-removable; do not show x button
  Cell Hover: one rounded rectangle around visible tag content union bounds using --color-bg-hover
  Left Click Behavior: open Shiori Tag Popover Layout
  Right Click Behavior: no action

Search Empty Hint:
  Text: Enter a search term or add filters to show cues.
  Condition: no search term and no effective filter condition

Shiori Empty Hint:
  Text: Save cues from playback to collect Shiori.
  Condition: no saved Shiori rows
```

#### Interaction

修改前：

```markdown
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
Remove Shiori Action: open Confirmation Dialog Layout
Cell Action Menu Anchor: use the right-click pointer position inside the triggering cell content hover region; menu opens below the click position and clamps to visible content bounds
```

修改后：

```markdown
#### Interaction
Header: sort / column menu
Rows: no full-row hover or selected background
Header Area: no hover background
Cell Content: hover shows one rounded rectangle around visible text / content union bounds using --color-bg-hover
Cell Content Hit Testing: hover, pointer, underline, left-click action, and right-click menu use the same Cell Content hover region
Non-hover Cell Area Left Click: toggle row checkbox selection
Non-hover Cell Area Right Click: no cell action menu
Interactive Cell Hover: pointer cursor for Display Title, Cues, Time, Date Added, and Tags; underline for Display Title, Cues, Time, and Date Added only
Cues Cell Left Click: Play
Cues Cell Right Click: open Cues Row Action Menu
Display Title Cell Left Click: Open Folder
Display Title Cell Right Click: open Display Title Cell Action Menu
Time Cell Left Click: Copy Text
Time Cell Right Click: open Time Cell Action Menu
Date Added Cell Left Click: Copy Text
Date Added Cell Right Click: open Date Added Cell Action Menu
Tags Cell Left Click: open Shiori Tag Popover Layout
Tags Cell Right Click: no action
Tags Cell Table Chips: non-removable; no x button
Other Data Cells: reserved for future cell menus; no action defined yet
View Menu: Cues is checked + disabled; other data columns can be hidden
Cues Row Action Menu: Play / Context / Copy Cue Text
Display Title Cell Action Menu: Open Folder / Copy Text
Time Cell Action Menu: Copy Text
Date Added Cell Action Menu: Copy Text
Open Folder Action: open the subtitle file's containing folder and select the subtitle file
Copy Text Action: copy the triggering cell's displayed text to the clipboard
Shiori Row Action Menu Extra Item: Remove Shiori
Remove Shiori Action: open Confirmation Dialog Layout
Cell Action Menu Anchor: use the right-click pointer position inside the triggering cell content hover region; menu opens below the click position and clamps to visible content bounds
```

#### Refresh Scope

修改前：

```markdown
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

修改后：

```markdown
#### Refresh Scope
Owner:
- Search / Shiori table surface.
- Table document, header, scrollbar, selection, tag popover, and menu subregions own their own local rendering.

Allowed invalidation:
- Search or Shiori row snapshot changes may update table rows and table summary.
- Column visibility changes may update header, column layout, visible rows, and cursor rects.
- Filter or submitted search changes may reload the owning table data.
- Visible-row changes may request additional rows only for the owning table.
- Row action menus may update only the active row, active menu, and menu overlay.
- Tags cell popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Adding, creating, or removing a tag association for the current Shiori may update only the current row's Tags cell and the open tag popover.
- Confirmed global tag deletion may update only the open tag popover and visible Shiori Tags cells whose cue used the deleted tag.

Forbidden invalidation:
- Table hover, cursor, focus, menu-open, tag popover open, tag popover hover, tag popover typing, and scrollbar interactions must not invalidate SearchView, App Sidebar, App Topbar, Playback Page, or Playback render host.
- Search table updates must not invalidate Shiori or Library surfaces.
- Shiori table updates must not invalidate Search or Library surfaces.
- Tag popover typing and hover must not reload table rows, rebuild table snapshots, or start background row hydration.
- Tag association changes must not rebuild the full table snapshot when the current or affected visible Tags cells can be patched.
- Background row hydration must not run while the owning table surface is not allowed to respond to interaction.
```

**3. 新增 `### Shiori Tag Popover Layout`**

新增：

```markdown
#### Structure
Container: popover overlay
Orientation: vertical
Layout Sections:
  1. Current Tags and Search
  2. Global Tag Pool
Dismiss: click outside popover closes the popover
System Popover Arrow: none
```

新增：

```markdown
#### Content
Current Tags and Search:
  Current Tags Layout: horizontal wrap
  Current Tags: tags associated with the current Shiori cue
  Current Tag Style: Removable Chip / Tag using [label | x]
  Tag Composer: Tag Composer Field
  Tag Composer Tags: tags associated with the current Shiori cue
  Tag Composer Input: search or create tag query
  Search Results: matching existing tags for the current input
  Create Option: Create [input text] when no exact existing tag matches

Global Tag Pool:
  Hint Text: Select a tag or create one
  Hint Text Color: --color-text-muted
  Tags Layout: horizontal wrap
  Tags: all existing tags
  Global Tag Style: Removable Chip / Tag using [label | x]
```

新增：

```markdown
#### Interaction
Open Trigger: left click on a Shiori Tags cell
Typing: update local search text and matching results
Click Matching Tag: add that tag to the current Shiori cue and clear the input
Click Create Option: create the tag, add it to the current Shiori cue, and clear the input
Current Tag Body Click: no action
Current Tag x Click: remove only that tag association from the current Shiori cue
Global Tag Body Click / Not Associated: add that tag to the current Shiori cue
Global Tag Body Click / Already Associated: no action and no prompt
Global Tag x Click: open Confirmation Dialog Layout using Delete Tag Content
Right Click: no action
Escape Key: close popover
```

新增：

```markdown
#### Cursor
Popover Background: default
Search / Create Input: text
Tag Body: pointer when the owning interaction has an action; default when no action is available
Tag x Button: pointer
```

新增：

```markdown
#### Refresh Scope
Owner:
- Shiori tag popover overlay.
- Current Shiori row Tags cell for current-cue association changes.
- Visible Shiori Tags cells affected by confirmed global tag deletion.

Allowed invalidation:
- Popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Typing may update only the popover input value, local matching results, and local create option visibility.
- Tag hover and x hover may update only the hovered tag or x button.
- Adding an existing tag may update only the current row Tags cell, current tag section, global tag pool selected/no-op state, and input value.
- Creating a tag may update only the current row Tags cell, current tag section, global tag pool, and input value.
- Removing a current tag association may update only the current row Tags cell and current tag section.
- Confirmed global tag deletion may update only the open popover tag sections and visible Shiori Tags cells whose cue used the deleted tag.

Forbidden invalidation:
- Popover open, close, typing, focus, hover, and measurement must not reload Shiori table rows or rebuild the Shiori table snapshot.
- Popover local state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore unless the user confirms a data-changing command.
- Adding, creating, removing, or deleting tags must not invalidate SearchView, Library, Playback Page, or Playback render host.
- Confirmed global tag deletion must not rebuild the full Shiori table snapshot when affected visible Tags cells can be patched.
- Global tag body click on an already associated tag must not publish state changes, show a prompt, reload data, or redraw unrelated rows.

Probe / verification:
- Opening the popover keeps table snapshot rebuild count at 0.
- Typing in the input keeps table row reload count at 0.
- Adding or removing a current tag redraws only the current visible Tags cell and the popover.
- Confirmed global tag deletion redraws only affected visible Tags cells and the popover.
```

**4. `### 3.10 Confirmation Dialog Layout`**

新增：

```markdown
#### Delete Tag Content
Title: Delete Tag
Message: Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone.
Cancel Action Button:
  Base Component: Neutral Button
  Text: Cancel
  Default Focus: yes
Destructive Action Button:
  Base Component: Destructive Button
  Text: Delete
  Text Color: --color-danger-text
  Hover Background: --color-danger-bg-hover
```

修改前：

```markdown
#### Interaction
Default Focus: Cancel Action Button
Cancel Action: close dialog without changes
Remove Action: remove the Shiori row, close dialog, refresh Shiori table and selection state
Escape Key: same as Cancel
Return Key: activate default focused action
Click Outside: no action, dialog remains open
```

修改后：

```markdown
#### Interaction
Default Focus: Cancel Action Button
Cancel Action: close dialog without changes
Remove Shiori Action: remove the Shiori row, close dialog, refresh Shiori table and selection state
Delete Tag Action: delete the tag globally, close dialog, refresh the open Shiori Tag Popover and affected visible Shiori Tags cells
Confirmed Destructive Action: execute only the requested command target
Escape Key: same as Cancel
Return Key: activate default focused action
Click Outside: no action, dialog remains open
```

**5. 新增 `### 2.43 Tag Composer Field`**

```markdown
#### Container
Background: --color-bg-popover
Border: none
Padding X: --spacing-3
Padding Y: --spacing-3
Gap X: --spacing-2
Gap Y: --spacing-2
Layout: horizontal wrap
Align Items: center
Min Height: fit-content

#### Content
Tags: Chip / Tag
Tag Layout: removable Chip / Tag using [label | x]
Inline Text Input:
  Background: transparent
  Border: none
  Focus Ring: none
  Font Family: --font-family-base
  Font Size: --font-size-body
  Text Color: --color-text-primary
  Placeholder Text Color: --color-text-placeholder
  Width: flexible inline width
  Min Width: enough for text caret and short input
  Search Icon: none
  Clear Button: none

#### Status
Empty
Focused Empty
Typing
Filled With Tags
Filled With Tags And Typing
Disabled

#### Cursor
Tag Body: delegated to owning layout
Tag x Button: pointer
Inline Text Input: text

#### Interaction
Typing: update owning layout's local query state
Tag Body Click: delegated to owning layout
Tag x Click: delegated to owning layout
Click Empty Composer Area: focus Inline Text Input

#### Refresh Scope
Owner:
- Owning tag composer layout.

Allowed invalidation:
- Typing may update only the inline input value and owning layout's local matching results.
- Tag hover may update only the hovered tag.
- Tag x hover may update only the hovered x button.
- Focus changes may update only the composer field and owning popover focus state.

Forbidden invalidation:
- Typing, focus, hover, and local measurement must not reload table rows or rebuild table snapshots.
- Local input state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore.
```
**6. 修改 `### 3.14 Shiori Tag Popover Layout`**

修改前：

```markdown
#### Content
Current Tags and Search:
  Current Tags Layout: horizontal wrap
  Current Tags: tags associated with the current Shiori cue
  Current Tag Style: Removable Chip / Tag using [label | x]
  Tag Composer: Tag Composer Field
  Tag Composer Tags: tags associated with the current Shiori cue
  Tag Composer Input: search or create tag query
  Search Results: matching existing tags for the current input
  Create Option: Create [input text] when no exact existing tag matches

Global Tag Pool:
  Hint Text: Select a tag or create one
  Hint Text Color: --color-text-muted
  Tags Layout: horizontal wrap
  Tags: all existing tags
  Global Tag Style: Removable Chip / Tag using [label | x]
```

修改后：

```markdown
#### Content
Current Tags and Search:
  Tag Composer: Tag Composer Field
  Tag Composer Tags: tags associated with the current Shiori cue
  Tag Composer Tag Style: Removable Chip / Tag using [label | x]
  Tag Composer Input: search or create tag query

Global Tag Pool:
  Hint Text: Select a tag or create one
  Hint Text Color: --color-text-muted
  Tags Layout: horizontal wrap
  Tags When Input Is Empty: all existing tags
  Tags When Input Is Not Empty: existing tags matching the current input
  Global Tag Style: Removable Chip / Tag using [label | x]
  Create Option Visibility: when the current input is not empty and no existing tag exactly matches it
  Create Option Layout: horizontal row
  Create Option Content: Create label + non-removable Chip / Tag preview using the current input text
  Create Option Hover Background: --color-bg-hover
```

#### Interaction

修改前：

```markdown
#### Interaction
Open Trigger: left click on a Shiori Tags cell
Typing: update local search text and matching results
Click Matching Tag: add that tag to the current Shiori cue and clear the input
Click Create Option: create the tag, add it to the current Shiori cue, and clear the input
Current Tag Body Click: no action
Current Tag x Click: remove only that tag association from the current Shiori cue
Global Tag Body Click / Not Associated: add that tag to the current Shiori cue
Global Tag Body Click / Already Associated: no action and no prompt
Global Tag x Click: open Confirmation Dialog Layout using Delete Tag Content
Right Click: no action
Escape Key: close popover
```

修改后：

```markdown
#### Interaction
Open Trigger: left click on a Shiori Tags cell
Typing In Tag Composer: update local search text and Global Tag Pool matching results
Click Matching Global Tag / Not Associated: add that tag to the current Shiori cue and clear the input
Click Matching Global Tag / Already Associated: no action and no prompt
Click Create Option: create the tag, add it to the current Shiori cue, and clear the input
Current Tag Body Click: no action
Current Tag x Click: remove only that tag association from the current Shiori cue
Global Tag Body Click / Not Associated: add that tag to the current Shiori cue and clear the input
Global Tag Body Click / Already Associated: no action and no prompt
Global Tag x Click: open Confirmation Dialog Layout using Delete Tag Content
Right Click: no action
Escape Key: close popover
```

#### Cursor

修改前：

```markdown
#### Cursor
Popover Background: default
Search / Create Input: text
Tag Body: pointer when the owning interaction has an action; default when no action is available
Tag x Button: pointer
```

修改后：

```markdown
#### Cursor
Popover Background: default
Tag Composer Inline Text Input: text
Create Option Row: pointer
Tag Body: pointer when the owning interaction has an action; default when no action is available
Tag x Button: pointer
```

#### Refresh Scope

修改前：

```markdown
#### Refresh Scope
Owner:
- Shiori tag popover overlay.
- Current Shiori row Tags cell for current-cue association changes.
- Visible Shiori Tags cells affected by confirmed global tag deletion.

Allowed invalidation:
- Popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Typing may update only the popover input value, local matching results, and local create option visibility.
- Tag hover and x hover may update only the hovered tag or x button.
- Adding an existing tag may update only the current row Tags cell, current tag section, global tag pool selected/no-op state, and input value.
- Creating a tag may update only the current row Tags cell, current tag section, global tag pool, and input value.
- Removing a current tag association may update only the current row Tags cell and current tag section.
- Confirmed global tag deletion may update only the open popover tag sections and visible Shiori Tags cells whose cue used the deleted tag.

Forbidden invalidation:
- Popover open, close, typing, focus, hover, and measurement must not reload Shiori table rows or rebuild the Shiori table snapshot.
- Popover local state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore unless the user confirms a data-changing command.
- Adding, creating, removing, or deleting tags must not invalidate SearchView, Library, Playback Page, or Playback render host.
- Confirmed global tag deletion must not rebuild the full Shiori table snapshot when affected visible Tags cells can be patched.
- Global tag body click on an already associated tag must not publish state changes, show a prompt, reload data, or redraw unrelated rows.

Probe / verification:
- Opening the popover keeps table snapshot rebuild count at 0.
- Typing in the input keeps table row reload count at 0.
- Adding or removing a current tag redraws only the current visible Tags cell and the popover.
- Confirmed global tag deletion redraws only affected visible Tags cells and the popover.
```

修改后：

```markdown
#### Refresh Scope
Owner:
- Shiori tag popover overlay.
- Current Shiori row Tags cell for current-cue association changes.
- Visible Shiori Tags cells affected by confirmed global tag deletion.

Allowed invalidation:
- Popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Typing in Tag Composer may update only the composer input value, Global Tag Pool matching tags, and Create Option visibility.
- Tag hover, x hover, and Create Option hover may update only the hovered tag, x button, or Create Option row.
- Adding an existing tag may update only the current row Tags cell, Tag Composer tags, Global Tag Pool associated/no-op state, and composer input value.
- Creating a tag may update only the current row Tags cell, Tag Composer tags, Global Tag Pool tags, and composer input value.
- Removing a current tag association may update only the current row Tags cell and Tag Composer tags.
- Confirmed global tag deletion may update only the open popover tag sections and visible Shiori Tags cells whose cue used the deleted tag.

Forbidden invalidation:
- Popover open, close, typing, focus, hover, and measurement must not reload Shiori table rows or rebuild the Shiori table snapshot.
- Popover local state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore unless the user confirms a data-changing command.
- Adding, creating, removing, or deleting tags must not invalidate SearchView, Library, Playback Page, or Playback render host.
- Confirmed global tag deletion must not rebuild the full Shiori table snapshot when affected visible Tags cells can be patched.
- Global tag body click on an already associated tag must not publish state changes, show a prompt, reload data, or redraw unrelated rows.

Probe / verification:
- Opening the popover keeps table snapshot rebuild count at 0.
- Typing in Tag Composer keeps table row reload count at 0.
- Adding or removing a current tag redraws only the current visible Tags cell and the popover.
- Confirmed global tag deletion redraws only affected visible Tags cells and the popover.
```
