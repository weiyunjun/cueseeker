# 版本
main

# 需求描述
1. 移除当前的正式Search界面入口及代码。现在的Test Search界面升级为正式Search界面。
2. 将顶栏的几个入口（移除的正式Search除外）放到左边栏：Library，Shiori，Test Recent Watching，Test Library，Search。
3. 左边栏默认展开，允许收起，展开/收起状态持久化。收起后完全不显示左边栏内容。
4. 左边栏除了几个入口外，还会在底部有一个设置按钮，点击打开设置界面。
5. 左边栏包括图标和标签页文字。沿用现在的。
6. 标签页，初始化默认选中Library页。
7. 选中的标签页，状态也要持久化，重启App仍然会选中关闭前选中的标签页。
8. 每个标签页都要有标题，标题位于现在的顶栏。这里，Test Recent Watching和Test Library的界面，直接将已有标题放到顶栏。其它几个界面，在顶栏处补和Test Recent Watching一样的标题component。

# 注意事项
1. 展开/收起动画曾经在远古版本有过，可以看一下，大概是一个多月前了。
2. hover左边栏和选中的效果参考表格的hover和选中效果。
3. 展开/收起按钮图标可以用macOS自带的那个。
4. 将入口放到边栏以后，语义已经和现在不同，选中标签页之后再点击选中的标签页不会有界面的刷新。

# UI文档
## 1. Core Tokens

### 1.1 颜色

#### Text
--color-text-primary:
  Light: #0F172A
  Dark: #F4F4F5
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

#### Icon
--color-icon-default:
  Light: #667085
  Dark: #A1A1AA
--color-icon-muted:
  Light: #98A2B3
  Dark: #71717A
--color-icon-disabled:
  Light: #98A2B3
  Dark: #71717A
--color-icon-on-dark:
  Light: #FFFFFF
  Dark: #FFFFFF

#### Background
--color-bg-surface:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-hover:
  Light: #F3F4F6
  Dark: #27272A
--color-bg-disabled:
  Light: #F3F4F6
  Dark: #202024
--color-bg-readonly:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-popover:
  Light: #FFFFFF
  Dark: #1C1C1F

#### Border
--color-border-control:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-control-hover:
  Light: #D1D5DB
  Dark: #52525B
--color-border-muted:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-divider:
  Light: #E5E7EB
  Dark: #303036
--color-border-disabled:
  Light: #E5E7EB
  Dark: #303036
--color-border-readonly:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-checkbox:
  Light: #D0D5DD
  Dark: #52525B

#### Active Blue
--color-accent:
  Light: #0040FF
  Dark: #7AA2FF
--color-text-active:
  Light: #0040FF
  Dark: #8AB4FF
--color-icon-active:
  Light: #0040FF
  Dark: #8AB4FF
--color-border-active:
  Light: #0040FF
  Dark: #7AA2FF
--color-bg-active:
  Light: #EBF5FF
  Dark: #14275A
--color-bg-active-hover:
  Light: #E1EBFF
  Dark: #1B3470
--color-bg-active-clear-hover:
  Light: #D8E8FD
  Dark: #243F7F

#### Focus
--color-border-focus:
  Light: #3B82F6
  Dark: #60A5FA
--color-focus-ring:
  Light: rgba(59,130,246,0.22)
  Dark: rgba(96,165,250,0.30)

#### Table Row
--color-row-hover:
  Light: #F9FAFB
  Dark: #202024
--color-row-selected:
  Light: #F3F4F6
  Dark: #27272A

#### Checkbox
--color-bg-checkbox-unchecked:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-checkbox-checked:
  Light: #111827
  Dark: #F4F4F5
--color-checkbox-icon:
  Light: #FFFFFF
  Dark: #18181B

#### Danger
--color-danger-text:
  Light: #B42318
  Dark: #FCA5A5
--color-danger-bg-hover:
  Light: #FEF3F2
  Dark: #3A1717

#### Scrollbar
--color-scrollbar-thumb-default:
  Light: #CBD5E1
  Dark: #52525B
--color-scrollbar-thumb-interactive:
  Light: #94A3B8
  Dark: #71717A
--color-scrollbar-track:
  Light: transparent
  Dark: transparent

#### Chip
--color-chip-speaker-bg:
  Light: #DDD6FE
  Dark: #31294C
--color-chip-speaker-text:
  Light: #5B21B6
  Dark: #D8B4FE
--color-chip-language-bg:
  Light: #DBEAFE
  Dark: #172A4A
--color-chip-language-text:
  Light: #0040FF
  Dark: #93C5FD

#### Watch Status
--color-watch-status-unwatched-bg:
  Light: #F3F4F6
  Dark: #27272A
--color-watch-status-unwatched-text:
  Light: #667085
  Dark: #A1A1AA
--color-watch-status-watching-bg:
  Light: #DBEAFE
  Dark: #172A4A
--color-watch-status-watching-text:
  Light: #0040FF
  Dark: #93C5FD
--color-watch-status-finished-bg:
  Light: #D1FAE5
  Dark: #123A2A
--color-watch-status-finished-text:
  Light: #047857
  Dark: #6EE7B7

#### Library Media
--color-library-progress-fill:
  Light: #0040FF
  Dark: #7AA2FF
--color-library-progress-track:
  Light: #E5E7EB
  Dark: #303036
--color-library-time-badge-bg:
  Light: rgba(15,23,42,0.72)
  Dark: rgba(0,0,0,0.58)
--color-library-time-badge-text:
  Light: #FFFFFF
  Dark: #FFFFFF
--color-library-cover-placeholder-bg:
  Light: #E5E7EB
  Dark: #303036
--color-library-media-card-hover-bg:
  Light: #E5E7EB
  Dark: #27272A

### 1.2 尺寸、圆角、间距

#### Height
--height-filter-bar-control: 40px
--height-control: 40px
--height-field: 40px
--height-table-utility-bar: 40px
--height-table-header: 40px
--height-table-row: 64px
--height-action-menu-item: 40px
--height-select-menu-item: 40px

#### Size
--size-checkbox: 16px
--size-inline-clear-button: 32px
--size-inline-clear-icon: 20px
--size-inline-clear-symbol-font-size-macos: 11pt
--size-inline-add-symbol-font-size-macos: 16pt
--size-menu-item-symbol-font-size-macos: 14pt
--size-control-icon: 20px
--size-icon-button: 40px
--size-row-action-button: 36px
--scrollbar-size: 8px

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
--radius-chip: 6px
--scrollbar-radius: 9999px

#### Spacing
--spacing-1: 4px
--spacing-2: 8px
--spacing-3: 12px
--spacing-4: 16px
--spacing-6: 24px
--spacing-8: 32px

#### Padding
--padding-control-x: 16px
--padding-field-x: 16px
--padding-menu-item: 12px 16px
--padding-header-trigger-x: 12px
--padding-chip-x: 10px
--padding-chip-y: 4px

#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 16px
--font-size-table: 14px
--font-size-caption: 12px

#### Shadow
--shadow-popover:
  Light: 0 12px 24px rgba(15,23,42,0.12)
  Dark: 0 12px 24px rgba(0,0,0,0.36)

#### Library Size
--aspect-library-cover: 16 / 9
--height-library-progress-bar: 4px
--width-library-recent-card-min: 180px
--width-library-recent-card-max: 220px
--width-library-episode-card: 160px
--width-library-folder-cover: 120px
--min-height-library-folder-card: 96px

#### Library Radius
--radius-library-cover: 8px
--radius-library-time-badge: 6px
--radius-library-folder-card: 8px
--radius-library-media-card-hover: 20px

#### Library Spacing
--gap-library-recent-grid: 16px
--gap-library-episode-grid-card: 12px
--gap-library-folder-card-content: 12px

#### Library Padding
--padding-library-folder-card: 12px 16px
--padding-library-time-badge: 2px 6px
--padding-library-media-card-hover: 12px

#### Library Typography
--font-size-section-title: 18px
--font-size-library-title: 14px
--font-size-library-meta: 12px
--font-size-library-time-badge: 12px

## 2. Components

### 2.1 Search Box

#### Container
Height: --height-filter-bar-control
Radius: --radius-search
Padding X: --padding-control-x
Background Default: --color-bg-surface
Background Disabled: --color-bg-disabled
Border Default: --color-border-control
Border Focus: --color-border-focus
Border Disabled: --color-border-disabled
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: search
Icon Color: --color-icon-default
Placeholder Text: --color-text-placeholder
Input Text: --color-text-primary
Clear Button: Inline Clear Button

#### Status
Empty
Focused Empty
Typing / Focused Filled
Filled
Clear Button Hover
Disabled

#### Cursor
Input Area: text

### 2.2 Inline Clear Button

#### Container
Size: --size-inline-clear-button
Radius: --radius-inline-clear-button
Border: none
Hover / Neutral: --color-bg-hover
Hover / Active: --color-bg-active-clear-hover
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon: x
Icon Size: --size-inline-clear-icon
Native macOS Symbol: SF Symbol xmark, bold
Native macOS Symbol Font Size: --size-inline-clear-symbol-font-size-macos
Icon Default: --color-icon-default
Icon Disabled: --color-icon-disabled

#### Status
Default
Hover / Neutral
Hover / Active Context
Disabled

#### Cursor
Not specified in image

### 2.3 Filter Panel Trigger Button

#### Container
Height: --height-filter-bar-control
Radius: --radius-control
Padding X: --padding-control-x
Border Active: --color-border-active
Background Active: --color-bg-active
Hover / Open Bg: --color-bg-active-hover
Clear Hover Bg: --color-bg-active-clear-hover
Disabled: --color-bg-disabled / --color-border-disabled / --color-text-disabled
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: filter
Text: --color-text-active
Icon: --color-icon-active
Trailing Clear Button: Inline Clear Button

#### Status
Active Default
Active Hover / Open
Clear Button Hover
Disabled

#### Cursor
Not specified in image

### 2.4 Select Trigger Button

#### Container
Height: --height-filter-bar-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: --color-bg-surface
Background Hover / Open: --color-bg-hover
Background Disabled: --color-bg-disabled
Border Default: --color-border-control
Border Hover / Open: --color-border-control-hover
Border Focus: --color-border-focus
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset
Border Disabled: --color-border-disabled

#### Content
Leading Icon: filter / sliders
Icon Size: --size-control-icon
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled
Select Indicator: chevrons-up-down

#### Status
Default
Hover
Menu Open
Disabled

#### Cursor
Not specified in image

### 2.5 Form Select Field

#### Container
Height: --height-field
Radius: --radius-field
Padding X: --padding-field-x
Background Default: --color-bg-surface
Background Hover / Open: --color-bg-hover
Background Disabled: --color-bg-disabled
Border Default: --color-border-control
Border Hover / Open: --color-border-control-hover
Border Focus: --color-border-focus
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset
Border Disabled: --color-border-disabled

#### Content
Icon Size: --size-control-icon
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled
Select Indicator: chevrons-up-down

#### Status
Default
Hover
Menu Open
Disabled

#### Cursor
Not specified in image

### 2.6 Value Input Field

#### Container
Height: --height-field
Radius: --radius-field
Padding X: --padding-field-x
Background Default: --color-bg-surface
Background Readonly: --color-bg-readonly
Background Disabled: --color-bg-disabled
Border Default: --color-border-control
Border Focus: --color-border-focus
Border Disabled: --color-border-disabled
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Text Default: --color-text-primary
Placeholder: --color-text-placeholder
Read-only Text: --color-text-readonly
Disabled Text: --color-text-disabled
Font Family: --font-family-base
Font Size: --font-size-control

#### Status
Empty
Focused Empty
Filled
Read-only / No Value Needed
Disabled

#### Cursor
Input Area: text

### 2.7 Logic Connector

#### Container
Static Label Typography: --font-family-base
Static Label Size: --font-size-body
Static Label Color: --color-text-primary
Static Label Background: transparent
Static Label Border: none
Interactive Select Height: --height-field
Interactive Select Radius: --radius-field
Interactive Select Padding X: --padding-field-x
Interactive Select Background Default: --color-bg-surface
Interactive Select Background Hover / Open: --color-bg-hover
Interactive Select Background Disabled: --color-bg-disabled
Interactive Select Border Default: --color-border-control
Interactive Select Border Hover / Open: --color-border-control-hover
Interactive Select Border Focus: --color-border-focus
Interactive Select Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset
Interactive Select Border Disabled: --color-border-disabled

#### Content
Static Label: Where
Inherited Static Labels: and / or
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled
Select Indicator: chevrons-up-down

#### Status
First Row / Static Where
Second Row / Interactive Select
Hover
Menu Open
Inherited Static Labels
Disabled

#### Cursor
Not specified in image

### 2.8 Neutral Button

#### Container
Height: --height-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: --color-bg-surface
Background Hover: --color-bg-hover
Background Disabled: --color-bg-disabled
Border Default: --color-border-control
Border Hover: --color-border-control-hover
Border Disabled: --color-border-disabled
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Not specified in image

### 2.9 Inline Add Button

#### Container
Height: --height-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: transparent
Background Hover: --color-bg-hover
Background Disabled: transparent
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon: plus
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Slot Size: --size-control-icon
Native macOS Symbol: SF Symbol plus, medium
Native macOS Symbol Font Size: --size-inline-add-symbol-font-size-macos
Icon Color Default: --color-text-primary
Icon Color Disabled: --color-text-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Not specified in image

### 2.10 Icon Button

#### Container
Button Size: --size-icon-button
Border Radius: --radius-control
Background Default: transparent
Background Hover: --color-bg-hover
Background Disabled: transparent
Border Default: none
Border Hover: none
Border Disabled: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Hover: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 2.11 Row Action Button

#### Container
Width: --size-row-action-button
Height: --size-row-action-button
Radius: --radius-row-action
Background Default: transparent
Background Hover / Menu Open: --color-bg-hover
Background Disabled: transparent
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon: ellipsis
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover / Menu Open
Disabled

#### Cursor
Not specified in image

### 2.12 Menu Item Base

#### Container
Display: flex
Align Items: center
Gap: --spacing-3
Width: 100%
Padding: --padding-menu-item
Background Hover / Highlighted: --color-bg-hover

#### Content
Leading Slot: semantic region, varies by item type
Label: label
Trailing Slot: optional semantic region, borderless inline action
Font: --font-family-base
Font Size: --font-size-body
Text Color: --color-text-primary
Disabled Text: --color-text-disabled
Icon Slot Size: --size-control-icon
Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

#### Status
Default
Hover / Highlighted
Disabled

#### Cursor
Not specified in image

### 2.13 Select Menu Item

#### Container
Display: flex
Align Items: center
Gap: --spacing-3
Width: 100%
Padding: --padding-menu-item
Height: --height-select-menu-item
Radius: --radius-select-menu-item
Background Hover / Highlighted: --color-bg-hover

#### Content
Leading Slot: checked slot
Label: label
Trailing Slot: optional borderless inline action
Font: --font-family-base
Font Size: --font-size-body
Text Color: --color-text-primary
Disabled Text: --color-text-disabled
Check Icon Slot Size: --size-control-icon
Check Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

#### Status
Default
Hover / Highlighted
Checked
Disabled

#### Cursor
Not specified in image

### 2.14 Action Menu Item

#### Container
Display: flex
Align Items: center
Gap: --spacing-3
Width: 100%
Padding: --padding-menu-item
Height: --height-action-menu-item
Radius: --radius-action-menu-item
Background Hover / Highlighted: --color-bg-hover

#### Content
Leading Icon Slot: fixed action icon
Label: label
Trailing Slot: optional
Font: --font-family-base
Font Size: --font-size-body
Text Color: --color-text-primary
Disabled Text: --color-text-disabled
Icon Slot Size: --size-control-icon
Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

#### Status
Default
Hover / Highlighted
Submenu
Disabled

#### Cursor
Not specified in image

### 2.15 Column Header Menu

#### Container
Trigger Height: --height-field
Trigger Padding X: --padding-header-trigger-x
Trigger Gap: --spacing-2
Trigger Radius: --radius-field
Trigger Background Hover / Open: --color-bg-hover
Menu Background: --color-bg-popover
Menu Border: --color-border-muted
Menu Border Radius: --radius-menu
Menu Shadow: --shadow-popover
Menu Padding: --spacing-1
Menu Item Height: --height-action-menu-item
Menu Item Padding: --padding-menu-item
Menu Item Border Radius: --radius-action-menu-item
Menu Item Background Hover / Highlighted: --color-bg-hover
Divider: --color-border-divider

#### Content
Header Trigger Text Color Default: --color-text-primary
Header Trigger Text Color Disabled: --color-text-disabled
Header Trigger Icon Color Default: --color-icon-default
Header Trigger Icon Color Disabled: --color-icon-disabled
Sort Indicator Unsorted: chevrons-up-down
Sort Indicator Asc: arrow-up
Sort Indicator Desc: arrow-down
Asc Icon: arrow-up
Desc Icon: arrow-down
Hide Icon: eye-off
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Hover / Highlighted: --color-text-primary
Menu Item Icon Color: --color-text-primary
Font Family: --font-family-base
Font Size: --font-size-table

#### Status
Default Menu
Hover / Highlighted Item
Menu Open on Sorted Asc
Menu Open on Sorted Desc

#### Cursor
Header Trigger: pointer
Menu Items: pointer

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
Row Action Trigger Size: --size-row-action-button
Row Action Trigger Radius: --radius-row-action
Row Action Trigger Background Default: transparent
Row Action Trigger Background Open: --color-bg-hover
Row Action Trigger Border: none

#### Content
Copy Cue Text Icon: copy
Open Context Icon: search
Favorite Icon: star
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Disabled: --color-text-disabled
Menu Item Icon Color Default: --color-text-primary
Menu Item Icon Color Disabled: --color-text-disabled
Row Action Trigger Icon: ellipsis
Row Action Trigger Icon Color: --color-icon-default
Row Action Trigger Disabled Icon Color: --color-icon-disabled

#### Status
Default Menu
Hover / Highlighted Item
Menu Open (from Row Action Button)

#### Cursor
Not specified in image

### 2.17 Table Row

#### Container
Row Height: --height-table-row
Header Height: --height-table-header
Row Hover Bg: --color-row-hover
Row Selected Bg: --color-row-selected
Header Hover Bg: --color-row-hover
Trigger Surface Bg: --color-bg-hover
Divider Horizontal: --color-border-divider

#### Content
Header Text Color: --color-text-primary
Cues Text Color: --color-text-primary
Columns: checkbox / Cues / Speaker / Language
Speaker: Chip / Tag
Language: Chip / Tag

#### Status
Default
Header Hover / Header Area
Header Hover / Trigger Surface
Body Hover
Body Selected

#### Cursor
Not specified in image

### 2.18 Sortable Header Cell

#### Container
Header Height: --height-table-header
Trigger Padding X: --padding-header-trigger-x
Trigger Bg Hover / Menu Open: --color-bg-hover
Row Bg Hover: --color-row-hover
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Default: --color-icon-default
Icon Disabled: --color-icon-disabled
Indicator Unsorted: chevrons-up-down
Indicator Asc: arrow-up
Indicator Desc: arrow-down

#### Status
Interaction: Default
Interaction: Hover
Interaction: Menu Open
Interaction: Disabled / Not Sortable
Sort: Unsorted
Sort: Sorted Asc
Sort: Sorted Desc

#### Cursor
Not specified in image

### 2.19 Row Selection Checkbox

#### Container
Checkbox Size: --size-checkbox
Checkbox Border Default: --color-border-checkbox
Checkbox Border Focus: --color-border-focus
Checkbox Background Unchecked: --color-bg-checkbox-unchecked
Checkbox Background Checked / Indeterminate: --color-bg-checkbox-checked
Border Radius: --radius-checkbox
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Check / Indeterminate Icon: --color-checkbox-icon

#### Status
Row Unchecked
Row Checked
Header Unchecked
Header Checked
Header Indeterminate

#### Cursor
Not specified in image

### 2.20 Interactive Text Cell

#### Container
Not specified in image

#### Content
Text Default: --color-text-primary
Text Hover: --color-text-primary
Underline Hover: same as text color
Text Decoration: underline
Decoration Thickness: 1px
Decoration Offset: 2px

#### Status
Default
Hover (Underline)

#### Cursor
Default / Non-text Area: default
Cues Text Hover: pointer

### 2.21 Table Scrollbar

#### Container
Size: --scrollbar-size
Radius: --scrollbar-radius
Track: transparent

#### Content
Default Thumb: --color-scrollbar-thumb-default
Hover / Dragging Thumb: --color-scrollbar-thumb-interactive

#### Status
Vertical Default
Vertical Hover / Dragging
Horizontal Default
Horizontal Hover / Dragging

#### Cursor
Not specified in image

### 2.22 Chip / Tag

#### Container
Height: fit-content
Radius: --radius-chip
Padding X: --padding-chip-x
Padding Y: --padding-chip-y
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-caption
Speaker Background: --color-chip-speaker-bg
Speaker Text: --color-chip-speaker-text
Language Background: --color-chip-language-bg
Language Text: --color-chip-language-text
Disabled Background: --color-bg-disabled
Disabled Text: --color-text-disabled

#### Status
Speaker / Default
Language / Default
Speaker / Disabled
Language / Disabled

#### Cursor
default

### 2.23 Count Summary

#### Container
Container Height: --height-table-utility-bar

#### Content
Font Family: --font-family-base
Font Size: --font-size-body
Primary Value: --color-text-primary
Secondary Text: --color-text-muted
Default Format: {total} rows
Selected Format: {selected} / {total} rows selected
Overflow Total: 99999+
Overflow Selected: 99999+ / 99999+ rows selected

#### Status
Default
Overflow Total
Selected
Selected / Overflow

#### Cursor
default

### 2.24 Section Title

#### Container
Display: block
Align: left
Background: transparent
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-section-title
Font Weight: semibold
Text Color: --color-text-primary

#### Status
Readonly

#### Cursor
default

### 2.25 Library Cover

#### Container
Aspect Ratio: --aspect-library-cover
Radius: --radius-library-cover
Background Fallback: --color-library-cover-placeholder-bg
Overflow: hidden

#### Content
Cover Image: fill container, preserve aspect ratio by cropping
Image Source: index-stage generated cover cache
Image Rendering: downsample to actual displayed pixel size before rendering

#### Status
No Cover
Loaded

#### Cursor
Inherited from parent component

### 2.26 Library Cover Progress Overlay

#### Container
Position: bottom aligned
Width: 100%
Height: --height-library-progress-bar

#### Content
Progress Track: --color-library-progress-track
Progress Fill: --color-library-progress-fill
Progress Fill Width: follows playback progress

#### Status
No Progress
In Progress
Finished
Unknown Duration

#### Cursor
Inherited from parent component

### 2.27 Library Cover Badge

#### Container
Position: bottom right
Radius: --radius-library-time-badge
Background: --color-library-time-badge-bg
Padding: --padding-library-time-badge

#### Content
Font Size: --font-size-library-time-badge
Text Color: --color-library-time-badge-text

#### Status
Time
Count
Hidden

#### Cursor
Inherited from parent component

### 2.28 Watch Status Badge

#### Container
Height: fit-content
Radius: --radius-chip
Padding X: --padding-chip-x
Padding Y: --padding-chip-y
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-caption
Unwatched Background: --color-watch-status-unwatched-bg
Unwatched Text Color: --color-watch-status-unwatched-text
Watching Background: --color-watch-status-watching-bg
Watching Text Color: --color-watch-status-watching-text
Finished Background: --color-watch-status-finished-bg
Finished Text Color: --color-watch-status-finished-text

#### Status
Unwatched
Watching
Finished
Disabled

#### Cursor
default

### 2.29 Empty Hint

#### Container
Display: flex
Align Items: center
Justify Content: center
Background: transparent
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-library-meta
Text Color: --color-text-muted

#### Status
Default

#### Cursor
default

### 2.30 App Sidebar Toggle Button

#### Container
Size: --size-icon-button
Radius: --radius-control
Background Default: transparent
Background Hover: --color-bg-hover
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon: macOS native sidebar toggle symbol
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 2.31 App Sidebar Navigation Item

#### Container
Height: --height-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: transparent
Background Hover: --color-row-hover
Background Selected: --color-row-selected
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: navigation item icon
Label: navigation item label
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Selected: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Selected: --color-text-primary
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Selected
Disabled

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 2.32 App Sidebar Settings Item

#### Container
Height: --height-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: transparent
Background Hover: --color-row-hover
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: gearshape
Label: Settings
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.1 Recent Watching Card Layout

#### Structure
Container: clickable media card
Orientation: vertical
Gap: --spacing-2
Padding: --padding-library-media-card-hover
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg

#### Content
Cover: Library Cover
Cover Overlay: Library Cover Progress Overlay
Cover Badge: Library Cover Badge / Time
Folder Name:
  Font Size: --font-size-library-title
  Text Color: --color-text-primary
  Line Count: 1
Meta Row:
  Episode Label:
    Font Size: --font-size-library-meta
    Text Color: --color-text-muted
  Watch Status: Watch Status Badge

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: media card press feedback
Click: open video at saved playback position
Disabled / Missing File: reduce opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.2 Library Folder Card Layout

#### Structure
Container: clickable media card
Orientation: vertical
Gap: --spacing-2
Padding: --padding-library-media-card-hover
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg

#### Content
Cover: Library Cover
Cover Badge: Library Cover Badge / Count
Folder Name:
  Font Size: --font-size-library-title
  Text Color: --color-text-primary
  Line Count: 1

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: scale card to 0.98 while pointer is pressed
Click: open Test Library Folder Detail view
Disabled / Empty Folder: reduce opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.3 Library Episode Card Layout

#### Structure
Container: clickable media card
Orientation: vertical
Gap: --spacing-2
Padding: --padding-library-media-card-hover
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg

#### Content
Cover: Library Cover
Cover Overlay: Library Cover Progress Overlay
Cover Badge: Library Cover Badge / Time
Meta Row:
  Episode Label:
    Font Size: --font-size-library-meta
    Text Color: --color-text-muted
  Watch Status: Watch Status Badge

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: scale card to 0.98 while pointer is pressed
Click: open video at saved playback position
Disabled / Missing File: reduce opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 3.4 Library Folder Detail Header Layout

#### Structure
Container: horizontal header
Orientation: horizontal
Gap: --spacing-2
Align Items: center

#### Content
Back Button:
  Base Component: Icon Button
  Icon: chevron.left
Title:
  Base Component: Section Title
  Text: folder name

#### Interaction
Back Button Click: return to Test Library一级界面
Title: readonly

#### Cursor
Back Button Default / Hover: pointer
Title: default

### 3.5 Test Search Filter Bar Layout

#### Structure
Container: horizontal toolbar
Orientation: horizontal
Gap: --spacing-3
Align Items: center

#### Content
Search: Search Box
Filter Controls:
  Filter Panel Trigger Button
  Select Trigger Button
  Form Select Field
  Value Input Field
  Logic Connector
  Inline Add Button

#### Interaction
Search Input: update query
Filter Controls: open / edit / clear filters

#### Cursor
Inherited from child components

### 3.6 Test Search Utility Bar Layout

#### Structure
Container: horizontal utility bar
Orientation: horizontal
Gap: --spacing-3
Align Items: center
Justify Content: space-between

#### Content
Row Info: Count Summary
View Controls:
  Icon Button
  Select Trigger Button
Future Actions:
  Neutral Button
  Icon Button
  Action Menu Item

#### Interaction
Row Info: readonly
View Controls: switch table display mode
Future Actions: export / screenshot / batch actions

#### Cursor
Inherited from child components

### 3.7 Test Search Table Layout

#### Structure
Container: table region
Orientation: vertical

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Row Actions: Row Action Button / Row Action Menu
Scrollbar: Table Scrollbar

#### Interaction
Header: sort / column menu
Rows: hover / select / open row actions
Text Cell: click cue text
Scrollbar: vertical table scrolling

#### Cursor
Inherited from child components