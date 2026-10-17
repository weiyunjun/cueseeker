# 说明
1. 本文档由人类维护，定义基础交互组件（`C-01` ~ `C-07`）：Inputs、Selection Controls、Buttons、Menus、Navigation、Tables、Scrollbars。
2. 所有组件默认遵守 `/docs/human/design/ui/UI Design Rules.md`（如全局无按下视觉效果）与 `/docs/human/design/ui/UI Interaction Rules.md`。

# 2. Components（Part 1：Controls `C-01` ~ `C-07`）

## 2.1 Inputs

### C-01.0 Inputs Shared

#### Focus Treatment

- Indicator：Border Color Only
- Focus Ring：None
- Focused Geometry：Same size, radius, padding, and layout as unfocused state
- Single-line Text & Placeholder Position：Same in unfocused and focused states, including when content overflows
- Error Priority：Danger Border overrides Focus Border

#### Single-line Input Behavior

- Applies To：Text Field, Search Field, Number Field
- Line Breaks：Disallowed；pasted line breaks are replaced with spaces
- Return Key：Does not insert line breaks, select all text, or trigger dialog confirmation（Command Panel Search Field keeps its action execution）

#### Pointer

- I-beam across the entire input container（except the Search Field clear button），clicking anywhere inside focuses the input

### C-01.1 Text Field

#### Shared

##### Anatomy

- Label
- Validation Message
  - Placement：Below Container
  - Content：Optional
  - Reserved Lines：`1`
  - Maximum Lines：`1`
- Container
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Radius：`--radius-field`
- Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
- Placeholder
  - Color：`--color-text-placeholder`

##### Sizes

- Height：`--height-field`
- Padding Inline：`--padding-field-x`
- Label to Container Gap：`--spacing-2`
- Container to Validation Message Gap：`--spacing-1`

##### States

- Empty
- Focused
  - Border Color：`--color-border-focus`
- Filled
- Error
  - Border Color：`--color-danger-text`
- Focused Error
  - Border Color：`--color-danger-text`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Text Color：`--color-text-disabled`

### C-01.2 Text Area

#### Shared

##### Anatomy

- Label
- Validation Message
  - Placement：Below Container
  - Content：Optional
  - Reserved Lines：`1`
  - Maximum Lines：`1`
- Container
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Radius：`--radius-field`
- Multiline Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
- Insertion Point
  - Color：`--color-border-focus`
- Placeholder
  - Color：`--color-text-placeholder`
- Text Content Origin
  - Applies To：Placeholder, Insertion Point, First Text Line
  - Rule：Shared
- Vertical Scrollbar
  - Component：Scrollbar / Vertical
  - Visibility：Inherit Scrollbar Visibility

##### Sizes

- Height：由所在布局决定
- Padding Inline：`--padding-field-x`
- Padding Block：`10px`
- Label to Container Gap：`--spacing-2`
- Container to Validation Message Gap：`--spacing-1`

##### States

- Empty
- Focused
  - Border Color：`--color-border-focus`
- Filled
- Error
  - Border Color：`--color-danger-text`
- Focused Error
  - Border Color：`--color-danger-text`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Text Color：`--color-text-disabled`

### C-01.3 Search Field

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Border Width：`--border-width-control`
  - Radius：`--radius-search`
- Search Icon
  - Size：`--size-control-icon`
  - Color：`--color-text-secondary`
- Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
- Placeholder
  - Color：`--color-text-placeholder`
- Clear Action
  - Presence：Optional
  - Component：Icon Button
- Content Gap：`--spacing-2`

##### Sizes

- Height：`--height-control`
- Padding Inline：`--padding-control-x`

##### States

- Empty
- Focused Empty
  - Border Color：`--color-border-focus`
- Filled
- Focused Filled
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Text Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

### C-01.4 Number Field

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Radius：`--radius-field`
- Numeric Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
  - Text Alignment：Trailing
  - Digit Style：Monospaced
  - Value Rule：Digits `0-9` only；输入或粘贴遇到换行符或 `.` 时在首个位置截断；超出上限时立即钳制为上限值，为空或低于下限时在失焦时恢复原值或钳制为下限值（Play `Auto Switch Gap`：`0 ~ 10000`；Subtitle `Size`：`1 ~ 200`；`Letter Spacing` / `Line Spacing`：`0 ~ 100`；`Margin X` / `Margin Y`：`0 ~ 500`；`Outline Width` / `Blur` / `Shadow Offset`：`0 ~ 50`；`Background Opacity` / `Shadow Opacity`：`0 ~ 100`）
- Unit Label
  - Presence：Optional
  - Placement：Inside Container
  - Current Value：`ms`、`%`
- Placeholder
  - Color：`--color-text-placeholder`
- Increment / Decrement / Spinner
  - Presence：None

##### Sizes

- Height：`--height-field`
- Padding Inline：`--padding-field-x`
- Content Gap：`--spacing-2`

##### States

- Empty
- Focused
  - Border Color：`--color-border-focus`
- Filled
- Error
  - Border Color：`--color-danger-text`
- Focused Error
  - Border Color：`--color-danger-text`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Text Color：`--color-text-disabled`

### C-01.5 Shortcut Field

#### Shared

##### Anatomy

- Container：同 Text Field
- Keycap
  - Component：Keycap / Popover Surface
  - Placement：Leading
  - Gap：`--spacing-1`
  - 修饰键（⌃、⌥、⇧、⌘）与主键各占一个 Keycap
- Placeholder
  - Presence：仅 Recording
  - Font Size：`--font-size-control`
  - Color：`--color-text-placeholder`
- Inline Clear
  - Component：Icon Button / Inline Clear
  - Presence：仅 Recording
  - Placement：Trailing
- Validation Message：同 Text Field；只在有提示时出现，不预留行

##### Sizes

- Width：`--width-shortcut-field`
- Height：`--height-field`
- Padding Inline：`--padding-field-x`

##### States

- Default
- Empty
  - 触发：快捷键已清空
- Recording
  - Border Color：`--color-border-focus`
  - Keycap 换为 Placeholder 与 Inline Clear
- Error
  - 触发：快捷键冲突；Recording 时按下排除或保留键静默忽略，不触发 Error
  - Border Color：`--color-danger-text`

## 2.2 Selection Controls

### C-02.1 Checkbox

#### Shared

##### Anatomy

- Control
  - Shape：Circle
  - Rendering：Phosphor / Monochrome
  - Size：`--size-checkbox`
- Label
  - Presence：Optional

##### Sizes

- Control Size：`--size-checkbox`
- Symbol Size：Control Size

##### States

- Unchecked
  - Icon：`circle`
  - Control Color：`--color-border-checkbox`
  - 圆圈内部透明，透出所在表面
- Checked
  - Icon：`check-circle`（Fill）
  - Control Color：`--color-bg-checkbox-checked`
  - 勾为纯白色，外圈为 Control Color
- Indeterminate
  - Icon：`minus-circle`（Fill）
  - Control Color：`--color-bg-checkbox-checked`
  - 横线为纯白色，外圈为 Control Color
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Control Color：`--color-text-disabled`
  - Label Color：`--color-text-disabled`

#### Variants

##### Table Selection Checkbox

- Hit Area：Containing Row
- Disabled：所在行为 Unavailable

##### Playback Selection Checkbox

- Hit Area：Entire Playback Cue Item
- Hover：None
- Focus Ring：None
- Control Size：`--size-playback-collage-checkbox`

##### Form Checkbox

- Hit Area：Control and Label
- Hover：None
- Focus Ring：None
- Label
  - Font Size：`--font-size-body`
  - Color：`--color-text-primary`
- Control to Label Gap：`--spacing-2`

### C-02.2 Switch

#### Shared

##### Anatomy

- Platform Native Switch
- Label
  - Presence：Optional

##### Sizes

- Platform Native

##### States

- Platform Native

### C-02.3 Color Well

#### Shared

##### Anatomy

- Container：同 Text Field
- Swatch
  - 纯色无边框圆角色块
  - Size：`--size-settings-color-swatch`
  - Radius：`--radius-settings-color-swatch`
- Prefix：固定显示 `#`，`--color-text-muted`，不可编辑
- Hex Input
  - 仅允许 `0-9`、`A-F`（自动转大写，最多 6 位）；粘贴自动剥离 `#` 并在首个换行符或 `.` 处截断
  - 支持 3 位与 6 位色值（3 位保持原样不展开；4~5 位失焦时截断取前 3 位；0~2 位失焦时恢复原值）
- Preset Popover
  - 聚焦或点击时在下方浮出 6×2 预设色块面板（Surface `--color-bg-popover`，Swatch Size `--size-settings-color-preset-swatch`，Radius `--radius-settings-color-swatch`）

##### Sizes

- Width：`--width-settings-number-field`
- Height：`--height-field`
- Padding Inline：`--padding-field-x`
- Content Gap：`--spacing-2`

##### States

- Default
- Focused / Open
  - Border Color：`--color-border-focus`

### C-02.4 Segmented Control

#### Shared

##### Anatomy

- Container
  - Background：`--color-segmented-control-bg`
  - Border Color：`--color-segmented-control-border`
  - Border Width：`--border-width-control`
  - Radius：`--radius-control`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-segmented-control`
  - Font Weight：`--font-weight-control`

##### Sizes

- Height：`--height-segmented-control`
- Padding：`--padding-segmented-control`
- Option Gap：`--gap-segmented-control`
- Option Width：各选项等宽，为最长选项文字的宽度加两侧各一个 `--padding-control-x`

##### States

- Unselected
  - Label Color：`--color-segmented-control-unselected-content`
- Selected
  - Background：`--color-segmented-control-selected-bg`
  - Border Color：`--color-segmented-control-selected-border`
  - Border Width：`--border-width-control`
  - Radius：`--radius-control` 减 `--padding-segmented-control`
  - Label Color：`--color-segmented-control-selected-content`
- Hover：None

### C-02.5 Filter Chip

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
  - Border Width：`--border-width-control`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-body`
  - 单行，超出时尾部省略号
- Count
  - Font Size：`--font-size-caption`
  - Placeholder：计数未知时为静止的圆角块，Width `--width-filter-chip-count-placeholder`，Height `--height-filter-chip-count-placeholder`，Color `--color-border-control`
- Content Gap：`--spacing-2`

##### Sizes

- Height：`--height-filter-chip`
- Max Width：`--max-width-filter-chip`
- Padding Inline：`--padding-control-x`

##### Interaction

- 点击切换选中
- 不获得焦点

##### States

- Default
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Label Color：`--color-text-primary`
  - Count Color：`--color-text-secondary`
- Hover
  - 仅未选中时
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Selected
  - Background：`--color-filter-chip-selected-bg`
  - Border Color：`--color-filter-chip-selected-content`
  - Label Color：`--color-filter-chip-selected-content`
  - Count Color：`--color-filter-chip-selected-content`

## 2.3 Buttons

### C-03.1 Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Leading Icon
  - Presence：Optional
  - Size：`--size-button-icon`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Font Weight：`--font-weight-control`
- Content Gap：`--spacing-2`

##### Sizes

- Height：`--height-control`
- Padding Inline：`--padding-control-x`

##### States

- Default
- Hover
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled

#### Variants

##### Neutral

- Default
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Label Color：`--color-text-secondary`
  - Icon Color：`--color-text-secondary`
- Hover
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Open
  - 触发：挂靠的菜单或面板打开，或按钮所控的模式开启
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
  - Label Color：`--color-text-secondary`
  - Icon Color：`--color-text-secondary`
- Focused
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

##### Cover Summary

- Usage：Cover Summary Resume or Play Action
- Default
  - Background：`--color-cover-summary-scrim` with `--opacity-cover-summary-button-bg`
  - Border Color：`--color-cover-summary-text` with `--opacity-cover-summary-button-border`
  - Label Color：`--color-cover-summary-text`
  - Icon Color：`--color-cover-summary-text`
- Hover
  - Background：`--color-cover-summary-scrim` with `--opacity-cover-summary-button-bg-hover`
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Opacity：`--opacity-cover-summary-button-disabled`

##### Primary

- Default
  - Background：`--color-primary-button-bg`
  - Border：None
  - Label Color：`--color-primary-button-text`
  - Icon Color：`--color-primary-button-text`
- Hover
  - Background：`--color-primary-button-bg-hover`
- Disabled
  - Background：`--color-bg-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

##### Destructive

- Default
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
  - Label Color：`--color-danger-text`
  - Icon Color：`--color-danger-text`
- Hover
  - Background：`--color-danger-bg-hover`
  - Border Color：`--color-border-control-hover`
- Focused
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

### C-03.2 Icon Button

#### Shared

##### Anatomy

- Container
  - Radius：Size Variant
  - Border：None
- Icon
  - Size：Size Variant

##### Sizes

- Default
  - Width：`--size-icon-button`
  - Height：`--size-icon-button`
  - Radius：`--radius-control`
  - Icon Size：`--size-control-icon`
- Inline Clear
  - Width：`--size-inline-clear-button`
  - Height：`--size-inline-clear-button`
  - Radius：`--radius-inline-clear-button`
  - Icon Size：`--size-inline-clear-icon`
- Row Action
  - Width：`--size-row-action-button`
  - Height：`--size-row-action-button`
  - Radius：`--radius-row-action`
  - Icon Size：`--size-control-icon`
- Dialog Close
  - Width：`--size-dialog-close-button`
  - Height：`--size-dialog-close-button`
  - Radius：`--radius-control`
  - Icon Size：`--size-dialog-close-icon`

##### Surface Hover

| 所在表面 | Surface Hover |
| --- | --- |
| `--color-bg-surface` | `--color-bg-hover` |
| `--color-table-bg` | `--color-bg-hover` |
| `--color-settings-group-bg` | `--color-bg-hover` |
| `--color-bg-dialog` | `--color-bg-hover` |
| `--color-subtitle-focus-overlay-bg` | `--color-overlay-surface-shortcut-button-bg-hover` |
| `--color-bg-popover` | `--color-popover-surface-shortcut-button-bg-hover` |
| `--color-player-topbar-gradient-start` | `--color-player-control-bg-hover` |

##### States

- Default
  - Background：Transparent
  - Icon Color：`--color-text-secondary`；在 `--color-player-topbar-gradient-start` 上为 `--color-player-text-primary`
- Hover
  - Background：Surface Hover
- Open
  - 触发：挂靠的菜单、面板或窗口打开，或按钮所控的模式开启
  - Background：Surface Hover
  - Icon Color：与 Default 保持一致
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Background：Transparent
  - Icon Color：`--color-text-disabled`

### C-03.3 Shortcut Action Button

#### Shared

##### Anatomy

- Container
  - Background：Transparent
  - Border：None
  - Radius：`--radius-chip`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-body`
  - Font Weight：`--font-weight-control`
  - Color：`--color-text-muted`
- Keycap：Keycap
- Content Gap：`--spacing-1`

##### Sizes

- Padding Inline：`--spacing-2`
- Padding Block：`--spacing-1`

##### Interaction

- 点击执行的动作与 Keycap 所示按键相同

##### States

- Default
- Hover
  - 内部 Keycap 一并切换到 Hover
- Open
  - 触发：挂靠的菜单打开
  - 外观与 Hover 相同

#### Variants

##### Overlay Surface

- Surface：`--color-subtitle-focus-overlay-bg`
- Keycap：Keycap / Overlay Surface
- Hover
  - Background：`--color-overlay-surface-shortcut-button-bg-hover`

##### Popover Surface

- Surface：`--color-bg-popover`；Command Panel 为 `--color-bg-dialog`
- Keycap：Keycap / Popover Surface
- Hover
  - Background：`--color-popover-surface-shortcut-button-bg-hover`

## 2.4 Menus

### C-04.1 Menu

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-menu`
  - Shadow：`--shadow-popover`
- Item Stack
- Vertical Scrollbar
  - Presence：Content Overflow
  - Component：Scrollbar / Vertical
  - Placement：位于 Item Stack 之外，与 Item Stack 相距 `--padding-menu`，与菜单边缘相距 `--gap-menu-scrollbar-outer`；出现时菜单加宽，Item Stack 宽度不变

##### Sizes

- Padding：`--padding-menu`
- Max Height：自然高度、`--max-height-menu`、菜单所在一侧的可用空间，三者取小
- Menu Item 的 Radius 等于 `--radius-menu` 减 `--padding-menu`

##### Placement

- Anchor：由按钮弹出时挂靠该按钮，由右键弹出时挂靠右键点中的内容
- Direction：默认朝下；下方空间不足时朝上；两侧都不足时取空间较大的一侧
- 方向与高度在弹出瞬间确定一次，之后随挂靠对象平移，不再重新计算
- Workbench 表格行菜单以表格正文区域为边界；跟随挂靠对象移动而越过边界的部分被裁剪
- Player More Menu 及其二级菜单以播放页顶栏与底栏按钮之间的区域为边界

##### States

- Closed
- Open
  - Highlight：打开时默认高亮首项；键盘与指针共用同一个高亮，同时只有一项高亮；滚轮滚动与拖拽滚动条本身不改变高亮；打开时的高亮项与键盘导航后的高亮项不在可见范围内时，菜单最小滚动使其完整可见，不带动画
  - Modality：打开期间下层不出现任何 Hover 或选中的视觉变化，挂靠对象保持打开时的高亮；下层原有的焦点与已选中的文字在菜单打开时一并取消；菜单之外的 App 内快捷键不响应，⌘ 组合键除外；右键点中另一个带右键菜单的对象时，菜单与高亮一起换到那个对象

#### Variants

##### Dropdown Menu

##### Context Menu

- Item：Menu Item / Action Menu Item、Destructive Menu Item、Submenu Trigger
- Workbench Search 表格行菜单：Play、Open Subtitle Folder、Save to Excerpt List；Menu Divider；Copy Cue Text、Copy Deep Link、Copy Cue Group Text、Copy Time Range
- Workbench Excerpt 表格行菜单：Play、Open Subtitle Folder；Menu Divider；Copy Cue Text、Copy Deep Link、Copy Cue Group Text、Copy Time Range；Menu Divider；Move to ...、Duplicate to ...；Menu Divider；Remove Excerpt
- Copy Cue Group Text 只在显示 Cue Group 时出现

##### Player Speed Menu

- Surface：Player Chrome
- Item：Menu Item / Radio Menu Item
- Highlight On Open：当前生效倍速

##### Player More Menu

- Surface：Player Chrome
- 圆角、Padding 与 Menu Item 高度与 Player Speed Menu 相同；宽度随菜单项内容
- Item：Menu Item / Submenu Trigger：Audio Track、Subtitle、Default Audio Track、Default Subtitle
- 视频没有音轨时 Audio Track 与 Default Audio Track 为 Disabled

### C-04.2 Submenu

#### Shared

##### Anatomy

- Trigger：Menu Item / Submenu Trigger
- Menu Surface：Menu

##### States

- Closed
- Open
  - 指针进入 Trigger 即展开，不等待；指针移到另一个 Trigger 时，前一个收起，后一个展开
  - 点击 Trigger、键盘右方向键与回车同样立即展开；展开后指针移动之前，二级菜单不因指针关闭或切换
  - Safe Area：指针离开 Trigger 时的位置与二级菜单靠 Menu 那条边的两端围成的区域，连同两个菜单之间的间隙。指针位于其中并朝二级菜单移动时保持展开，途经的 Menu Item 不取得高亮，也不展开自己的二级菜单
  - 指针离开 Safe Area，且不在 Menu 与二级菜单之上时关闭
  - 指针在 Safe Area 中转向或停下 300 毫秒，或离开 Safe Area 回到 Menu 上时，所在的 Menu Item 立即取得高亮，是 Trigger 时展开它的二级菜单，否则关闭；不在任何 Menu Item 上时同样关闭
- Highlighted
- Disabled

#### Variants

##### Excerpt Destination Submenu

- Structure：Excerpt List 项依次排列，末尾是 Menu Divider 与 New List 项；没有列表项时不显示 Divider
- 列表项按创建时间正序，与 Excerpt 一级界面的卡片顺序一致
- 由 Move to ... 与 Duplicate to ... 展开时不含当前所在的列表；由 Save to Excerpt List 展开时含全部列表
- 也由 Playback Footer 的 Save to Excerpt List 按钮直接弹出，挂靠该按钮，内容与表格行菜单的 Save to Excerpt List 相同
- Highlight On Open：由 Save to Excerpt List 打开时为最近保存的列表，没有则首项；由 Move to ... 与 Duplicate to ... 展开时为首项
- Item：Menu Item / Action Menu Item，均不带 Leading Icon

##### Audio Track Submenu

- Surface：Player Chrome
- Width：自然宽度、`--max-width-player-audio-track-menu`、展开一侧的可用空间，三者取小；出现 Vertical Scrollbar 时总宽仍不超出展开一侧的可用空间，空间不足时 Item Stack 变窄
- Direction：默认朝右；右侧空间不足时朝左；两侧都不足时取空间较大的一侧
- 由 Player More Menu 的 Audio Track 与 Default Audio Track 展开
- Structure：视频的音轨按文件中的顺序排列
- Item：Menu Item / Radio Menu Item，Trailing Slot 为 Tag / Player Chrome；名称完整显示，超出宽度时换行，Selection Indicator 与 Tag 对齐名称首行
- 名称：`#序号 语言, 标题, 编码, 声道`，缺少的部分省略
- 由 Audio Track 展开：勾选当前音频源，默认音频源所在项带 Tag「Default」
- 由 Default Audio Track 展开：勾选默认音频源，当前音频源所在项带 Tag「Current」

##### Subtitle Submenu

- Surface：Player Chrome
- Width、Direction 与 Item 同 Audio Track Submenu
- 由 Player More Menu 的 Subtitle 与 Default Subtitle 展开
- Structure：视频匹配的字幕按 Data 中的字幕顺序排列
- 名称：字幕文件名最后最多 2 级后缀名，只有 1 级后缀名时显示 1 级，例如 `.sc.ass`、`.srt`
- 由 Subtitle 展开：勾选当前字幕，默认字幕所在项带 Tag「Default」
- 由 Default Subtitle 展开：勾选默认字幕，当前字幕所在项带 Tag「Current」

### C-04.3 Menu Item

#### Shared

##### Anatomy

- Container
- Leading Slot
  - Presence：Optional
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
- Trailing Slot
  - Presence：Optional
- Content Gap：`--spacing-2`

##### Sizes

- Padding Inline：`--padding-menu-item`；Trailing Slot 为图标时该侧减 `2px`

##### States

- Default
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-text-primary`
- Highlighted
  - Background：`--color-bg-hover`
- Disabled
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

#### Variants

##### Action Menu Item

- Leading Slot：Icon / Empty
- Trailing Slot：Shortcut / Empty
- Height：`--height-action-menu-item`
- Radius：`--radius-action-menu-item`

##### Radio Menu Item

- Leading Slot：Selection Indicator
- Indicator Slot：Always Reserved
- Selected：Indicator Visible，不带背景
- Unselected：Indicator Hidden
- Highlighted：背景按 Menu Item / Highlighted，可与 Selected 落在不同项
- Height：`--height-select-menu-item`
- Radius：`--radius-select-menu-item`

##### Destructive Menu Item

- Leading Slot：Icon / Empty
- Trailing Slot：Shortcut / Empty
- Default
  - Label Color：`--color-danger-text`
  - Icon Color：`--color-danger-text`
- Highlighted
  - Background：`--color-danger-bg-hover`
- Disabled
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-text-disabled`

##### Submenu Trigger

- Leading Slot：Icon，各 Submenu Trigger 共用同一个右箭头图标
- Trailing Slot：Submenu Indicator，宽度按图形本身，不留左右空白

### C-04.4 Menu Divider

#### Shared

##### Anatomy

- Divider
  - Color：`--color-border-divider`

##### Sizes

- Inset Inline：`--inset-menu-divider`，两端与 Menu Item 的内容对齐
- Margin Block：`--gap-menu-divider`

##### States

## 2.5 Navigation

### C-05.1 Sidebar

#### Shared

##### Anatomy

- Surface
  - Background：`--color-app-sidebar-bg`
- Scroll Region
  - Scrollbar：Scrollbar / Vertical

##### Sizes

##### States

- Default
- Scrolling

### C-05.2 Sidebar Toggle

#### Shared

##### Anatomy

- Container：Icon Button
- Icon：`sidebar-simple`

##### Sizes

- Width：`--size-icon-button`
- Height：`--size-icon-button`
- Icon Size：`--size-control-icon`

##### States

- Default
- Hover
- Focused

### C-05.3 Sidebar Item

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-app-sidebar-item`
- Leading Icon Slot
  - Presence：Optional
  - Size：`--size-app-sidebar-item-icon`
  - Glyph Alignment：Center
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-app-sidebar-item`
- Content Gap：`--spacing-3`

##### Sizes

- Height：`--height-app-sidebar-item`
- Padding Inline：`--padding-app-sidebar-item-x`

##### States

- Default
- Hover
- Selected
  - Background：`--color-app-sidebar-item-selected-bg`
  - Label Color：`--color-app-sidebar-item-selected-content`
  - Icon Color：`--color-app-sidebar-item-selected-content`
  - Selection Scope：Current Item Only

#### Variants

##### Primary

- Leading Icon：Required

### C-05.4 Tabs

#### Shared

##### Anatomy

- Tab List
- Selection Indicator

##### Sizes

##### States

- Default
- Select Mode
  - Label Color：`--color-text-secondary`，与 Default 相同
  - 整条 Header 为全选点击区域，效果与点击 Selection Checkbox 一致
  - 无 Hover 反馈；指针为箭头
- Disabled

### C-05.5 Tab

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-body`
- Leading Icon
  - Presence：Optional
- Selection Indicator

##### Sizes

##### States

- Unselected
  - Label Color：`--color-tab-unselected`
- Hover
- Selected
  - Label Color：`--color-tab-selected`
  - Indicator Color：`--color-tab-selected`
- Focused
- Disabled
  - Label Color：`--color-text-disabled`

### C-05.6 Breadcrumb

#### Shared

##### Anatomy

- Node List
  - Link Item（未激活上级节点）
  - Current Item（当前所在末级节点）
- Separator
  - Icon：`caret-right`（12px，线宽 1.15px）
  - Color：`--color-text-muted`

##### Sizes

- Item to Separator Gap：`--spacing-2`
- Font Family：`--font-family-base`
- Font Size：`--font-size-body`（14px）

##### States

- Link Item (Default)
  - Font Weight：`--font-weight-control`（500 Medium）
  - Label Color：`--color-text-secondary`
- Link Item (Hover)
  - Label Color：`--color-text-primary`
- Current Item
  - Font Weight：Semibold（600）
  - Label Color：`--color-text-primary`
  - Interaction：不可点击，无 Hover 变化

## 2.6 Tables

### C-06.1 Table

#### Shared

##### Anatomy

- Surface
  - Background：`--color-table-bg`，铺满 Header 与 Body Viewport
- Header
- Body Viewport
- Rows
- Horizontal Scrollbar：Scrollbar / Horizontal

##### Sizes

- Header Height：`--height-table-header`

##### States

- Empty
- Loading
- Normal Mode
- Select Mode
- Disabled

#### Scrollbar Mapping

##### Horizontal

- Position Domain：Content Offset
- Extent Domain：Content Width

### C-06.2 Table Header Cell

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-table-header`
  - Font Weight：Medium
  - Color：`--color-text-secondary`
  - Alignment：Vertical Top
- Leading Slot
  - Presence：Optional
- Trailing Slot
  - Presence：Optional

##### Sizes

- Height：`--height-table-header`
- Padding Inline
  - Leading：`--padding-table-cell-leading`
  - Trailing：`--padding-table-cell-trailing`

##### States

- Default
- Disabled

#### Variants

##### Selection

- Label：`#`，与 Checkbox 共享水平居中对齐
- Checkbox：Checkbox / Table Selection Checkbox
- Alignment：Horizontal Center / Vertical Top
- States
  - None Selected
  - Partially Selected
  - All Selected

### C-06.3 Table Row

#### Shared

##### Anatomy

- Row Container
- Cell Stack
- Selection Slot
  - Presence：Select Mode，或未选中行 / 表头 Hover 时显示（已失效条目除外，保持显示行号且不可选中）

##### Sizes

- Minimum Height：`--min-height-table-row`
- Padding Block：`--padding-table-row-y`

##### States

- Default
- Hover
  - Background：`--color-row-hover`
  - 菜单或对话框打开期间不随指针移动；右键菜单的关联行保持 Hover
  - 指针真实移动后落在行上时随之移动；滚动与布局变化不移动它
- Selected
  - Background：`--color-row-selected`
  - Select Mode 下 Shift 加左键点击按区间选中：无选中时从第 1 行选到点击行；点击行已选中时只取消该行；点击行未选中时选中它到最近选中行之间的全部行
  - Unavailable 行不可选中：点击不改变勾选，全选与 Shift 区间选中跳过它，表头的全选状态不计入它
  - 最近选中行是最近一次产生选中的操作所选中的最高行；取消选中不改变它，选中清空时它一并清空
- Disabled

### C-06.4 Table Cell

#### Shared

##### Anatomy

- Content Region
- Leading Slot
  - Presence：Optional
- Trailing Slot
  - Presence：Optional

##### Sizes

- Padding Inline
  - Leading：`--padding-table-cell-leading`
  - Trailing：`--padding-table-cell-trailing`

##### States

- Default
- Disabled

#### Variants

##### Text

- Font Family：`--font-family-base`
- Font Size：`--font-size-table`
- Font Weight：Regular
- Color：`--color-text-secondary`
- Selection：Enabled
- Pointer：I-beam

##### Index Text

- Font Family：`--font-family-base`
- Font Size：`--font-size-caption`
- Font Weight：Regular
- Color：`--color-text-muted`
- Digits：Monospaced Digits
- Alignment：Horizontal Center / Vertical Center
- Selection：Disabled

##### Interactive Text

- Font Family：`--font-family-base`
- 目标字幕
  - Font Size：`--font-size-table`
  - Font Weight：Medium
  - Color：`--color-text-primary`
- Cue Group 附加字幕
  - Font Size：`--font-size-caption`
  - Font Weight：Regular
  - Color：`--color-text-secondary`
- Hover Region
  - Padding Inline：`--padding-table-cell-hover-x`
  - Padding Block：`--padding-table-cell-hover-y`
  - Radius：`--radius-table-cell-hover`
- Selection：Enabled
- Pointer：Grab
- States
  - Default
  - Hover
    - Text Decoration：Underline
    - Underline Color：与该行文字同色
    - Text Color：不变
  - Focused
  - Disabled

### C-06.5 Selection Action Overlay

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Selected Count
  - Content：已选行数 / 可选行数，可选行数不含 Unavailable 行
  - Color：`--color-text-muted`
  - Leading Inset：`--spacing-3`，与相邻按钮的透明内边距等宽
- Action Slots
  - Component：Shortcut Action Button / Popover Surface
  - Padding Inline：`--spacing-3`
  - Padding Block：`--spacing-2`

##### Layout

- Selected Count 在上，Action Slots 在下，左对齐
- Action Slots 宽度不足时换行，文字不截断
- 容器宽度由内容决定，不超过 Table 可见宽度

##### Sizes

- Group Gap：`--spacing-2`
- Action Gap：`--spacing-2`
- Line Gap：`--spacing-2`
- Padding Inline：`--spacing-3`
- Padding Block：`--spacing-2`

##### States

## 2.7 Scrollbars

### C-07.1 Scrollbar

#### Shared

##### Anatomy

- Track
  - Color：`--color-scrollbar-track`
- Thumb
  - Color：`--color-scrollbar-thumb-default`
  - Radius：`--scrollbar-radius`

##### Rendering

- Implementation：Custom Drawn
- Platform Native Scrollbar：None
- Layout：Overlay
- Reserved Gutter：None

##### Interaction

- Mouse Wheel：Supported
- Trackpad Scroll：Supported
- Thumb Drag：Supported

##### Sizes

- Thickness：`--scrollbar-size`
- Minimum Thumb Length：`--scrollbar-min-thumb-length`

##### States

- Hidden
- Hover Visible
  - Thumb Color：`--color-scrollbar-thumb-interactive`
- Scrolling Visible
- Dragging Visible
  - Thumb Color：`--color-scrollbar-thumb-interactive`

##### Visibility

- No Overflow：Hidden
- Idle：Hidden
- Scroll Area Hover：Visible
- Scrolling：Visible
- Dragging：Visible

#### Variants

##### Vertical

##### Horizontal
