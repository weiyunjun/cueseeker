# 版本
main

# 需求描述
1. 根据# UI文档部分的内容，修改或添加component，这些控件会应用于Test Search 2界面
2. 参考图片见docs/human/requirements/assets/20260614/，23个component均有参考图。
3. 除此之外，还有3个布局参考图，分别是：20260614-SearchFilterBar.png，20260614-TableUtilityBar.png，20260614-DataTable.png。分别对应界面的从上到下的三个区域。
4. 这个需求的主要任务是：按照现有文档修改或添加component，修改布局，并且保证可以和设计文档对齐。不要求和UI无关的功能实现，例如点击View按钮后，点击弹出的菜单显示或隐藏表格的列。

# 流程描述：
1. 修改所有component。保持视觉一致。具体查看# Component修改方案和# UI文档。
2. 根据布局参考图修改布局。

# 注意事项
这一部分记录实际对齐流程中遇到的问题和约束的标准。
1. Focus效果，需要和# UI文档中保持一致。如果某个component没有Focus相关的token，需要禁用其Focus效果。

# Component修改方案

| 组件 ID | 组件名称 (Component Name) | 当前是否存在 / 所在文件 | 方案类型 | 方案说明 |
| :--- | :--- | :--- | :--- | :--- |
| **2.1** | **Search Box** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchSearchField` | **直接修改** | 增加 `isRedesign`，当为 true 时将圆角改为 `9999px`（胶囊形），并调整 padding 和 Focus 环。 |
| **2.2** | **Inline Clear Button** | **不存在** | **新增组件** | 新建 `WorkbenchInlineClearButton`，并嵌入到 `WorkbenchSearchField` 中。 |
| **2.3** | **Filter Panel Trigger Button** | **部分存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchFilterChip` | **直接修改** | 在 `WorkbenchFilterChip` 基础上支持右侧 Inline Clear Button，以及特定的激活/悬浮态背景色。 |
| **2.4** | **Select Trigger Button** | **部分存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchToolbarButton` | **直接修改** | 支持 chevrons-up-down 指示器及 redesign 边框和悬浮态。 |
| **2.5** | **Form Select Field** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchSelectFieldLabel` | **直接修改** | 调整高度为 40px，圆角 8px，应用新 Token 颜色。 |
| **2.6** | **Value Input Field** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchTextInputField` / `WorkbenchReadonlyField` | **直接修改** | 调整高度为 40px，圆角 8px，支持只读/禁用样式。 |
| **2.7** | **Logic Connector** | **部分存在**<br>[SchemaWorkbenchSearchShell.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift) 中的 `SchemaWorkbenchFilterRuleRow` 左侧逻辑 | **直接修改** | 调整静态标签（Where）和交互下拉（And/Or）的对齐与高度。 |
| **2.8** | **Neutral Button** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchButton` | **直接修改** | 调整边框、高度及文字大小（16px）。 |
| **2.9** | **Inline Add Button** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchPlainActionButton` | **直接修改** | 改为透明背景及特定的 Hover 状态。 |
| **2.10** | **Icon Button** | **存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchIconButton` | **直接修改** | 统一大小为 40x40，圆角为 `--radius-control`，并调整 cursor。 |
| **2.11** | **Row Action Button** | **不存在**（原为文本按钮悬浮条） | **新增组件** | 新建 36x36 圆角 8px 的 ellipsis 按钮。 |
| **2.12** | **Menu Item Base** | **部分存在**<br>[WorkbenchControls.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift) 中的 `WorkbenchPopoverRow` | **直接修改** | 调整 padding 和 Slot 布局以适配底层 Menu Item。 |
| **2.13** | **Select Menu Item** | **部分存在**<br>`WorkbenchPopoverRow` 的选择状态 | **直接修改** | 调整为高度 40px，圆角 8px。 |
| **2.14** | **Action Menu Item** | **部分存在**<br>`WorkbenchPopoverRow` 的操作状态 | **直接修改** | 调整为高度 40px，圆角 8px。 |
| **2.15** | **Column Header Menu** | **不存在** | **新增组件** | 在表头增加 context menu/popover，支持排序和隐藏操作。 |
| **2.16** | **Row Action Menu** | **不存在** | **新增组件** | 用于响应 Row Action Button 的点击，展示拷贝、上下文、收藏。 |
| **2.17** | **Table Row** | **存在**（AppKit 绘制）<br>[SubtitleTableView.swift](file:///Users/weiyunjun/Documents/Code/CueSeeker/apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift) 中的 `Coordinator.drawRowsNow` | **直接修改** | **在 AppKit 渲染流程中判断 `isRedesign`**，将行高改为 64px 并应用新 Hover/Selected 背景色。 |
| **2.18** | **Sortable Header Cell** | **部分存在**<br>`SubtitleVirtualTableHeaderView` | **直接修改** | 表头支持绘制 chevrons-up-down / 箭头图标，支持悬浮和点击事件。 |
| **2.19** | **Row Selection Checkbox** | **不存在** | **新增组件** | 新建 SwiftUI Checkbox 组件，并由 AppKit 表头及表行进行混合渲染/事件传递。 |
| **2.20** | **Interactive Text Cell** | **不存在** | **直接修改** | 在 `SubtitleTableView` 绘制 displayTitle 时，增加 Hover 下划线绘制。 |
| **2.21** | **Table Scrollbar** | **存在**<br>`SubtitleTableView` 的 `NSScrollView` | **直接修改** | 调整 `NSScrollView` 的 scroller 样式以符合 8px 规范。 |
| **2.22** | **Chip / Tag** | **存在**（AppKit 绘制）<br>`SubtitleTableView.Coordinator.drawTags` | **直接修改** | 调整 AppKit 绘制的颜色，适配 Speaker 紫色和 Language 蓝色 Token。 |
| **2.23** | **Count Summary** | **不存在** | **新增组件** | 在 Table Utility Bar 区域实现计数器，支持已选择与总数的展示及 Overflow（99999+）。 |

---



# UI文档
## 1. Core Tokens

### 1.1 颜色

#### Text
--color-text-primary: #0F172A
--color-text-muted: #667085
--color-text-placeholder: #98A2B3
--color-text-disabled: #98A2B3
--color-text-readonly: #808080

#### Icon
--color-icon-default: #667085
--color-icon-muted: #98A2B3
--color-icon-disabled: #98A2B3
--color-icon-on-dark: #FFFFFF

#### Background
--color-bg-surface: #FFFFFF
--color-bg-hover: #F3F4F6
--color-bg-disabled: #F3F4F6
--color-bg-readonly: #FFFFFF
--color-bg-popover: #FFFFFF

#### Border
--color-border-control: #E5E7EB
--color-border-control-hover: #D1D5DB
--color-border-muted: #E5E7EB
--color-border-divider: #E5E7EB
--color-border-disabled: #E5E7EB
--color-border-readonly: #E5E7EB
--color-border-checkbox: #D0D5DD

#### Active Blue
--color-accent: #0040FF
--color-text-active: #0040FF
--color-icon-active: #0040FF
--color-border-active: #0040FF
--color-bg-active: #EBF5FF
--color-bg-active-hover: #E1EBFF
--color-bg-active-clear-hover: #D8E8FD

#### Focus
--color-border-focus: #3B82F6
--color-focus-ring: rgba(59,130,246,0.22)
--focus-ring-width: 3px
--focus-ring-offset: 0px

#### Table Row
--color-row-hover: #F9FAFB
--color-row-selected: #F3F4F6

#### Checkbox
--color-bg-checkbox-unchecked: #FFFFFF
--color-bg-checkbox-checked: #111827
--color-checkbox-icon: #FFFFFF

#### Danger
--color-danger-text: #B42318
--color-danger-bg-hover: #FEF3F2

#### Scrollbar
--color-scrollbar-thumb-default: #CBD5E1
--color-scrollbar-thumb-interactive: #94A3B8
--color-scrollbar-track: transparent

#### Chip
--color-chip-speaker-bg: #DDD6FE
--color-chip-speaker-text: #5B21B6
--color-chip-language-bg: #DBEAFE
--color-chip-language-text: #0040FF

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
--shadow-popover: 0 12px 24px rgba(15,23,42,0.12)

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
Hover Bg: --color-bg-active-hover
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
Active Hover
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
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

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
Icon Size: --size-control-icon
Icon Color: --color-icon-default
Disabled Icon: --color-icon-disabled

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
Check Icon Size: --size-control-icon
Icon Color: --color-icon-default
Disabled Icon: --color-icon-disabled

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
Icon Size: --size-control-icon
Icon Color: --color-icon-default
Disabled Icon: --color-icon-disabled

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
Icon Size: --size-control-icon
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Hover / Highlighted: --color-text-primary
Menu Item Icon Color: --color-icon-default
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
Menu Item Icon Size: --size-control-icon
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Disabled: --color-text-disabled
Menu Item Icon Color Default: --color-icon-default
Menu Item Icon Color Disabled: --color-icon-disabled
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
Header Hover Bg: --color-bg-hover
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
Default
Hover / Unsorted
Sorted Asc
Sorted Desc
Menu Open
Disabled / Not Sortable

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
Not specified in image

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