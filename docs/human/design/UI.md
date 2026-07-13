# UI 文档

## 0. 文档规则

### 0.1 文档职责

- 本文档记录 CueSeeker 当前稳定的 UI 结果。
- 本文档回答：界面显示什么、如何排列、什么可以操作、操作后发生什么。
- Core Tokens 是共享视觉数值的唯一来源。
- Components 只定义自身组成、Token 映射、状态和直接交互。
- Layouts 只定义 Components 的组合、排列、对齐、伸缩、滚动和页面级交互。
- 历史需求、修改原因和决策过程保留在 `docs/human/requirements/`，不复制到本文档。
- 本文档不记录 Store、刷新范围、缓存、虚拟化算法、异步实现、性能探针、代码实现建议和提交记录。

### 0.2 命名与引用

- 正文使用简洁中文。
- Token 标识符保持英文，不翻译、不添加中文别名。
- Component、Layout、Cue、Shiori、Search、Recent、Library、Context 等名称保持英文。
- 快捷键、SF Symbol、菜单文案和系统名称保持原文。
- 同一规则只定义一次，其他位置引用对应 Component 或 Layout。
- 未特别覆盖的系统行为遵循 macOS 原生交互和无障碍行为。

### 0.3 内容边界

- 可复用数值写入 Core Tokens。
- 只属于一个 Layout 的一次性数值可以直接写在该 Layout 中。
- Component 不重复 Token 的具体值，只引用 Token。
- Layout 不展开 Component 内部样式。
- 状态之间没有视觉或交互差异时，不重复列出。
- 图片只用于确认视觉方向，不能替代文字规则。
- 新规则必须替换旧规则，不能同时保留互相冲突的版本。
- 无法确定的内容应在写入本文档前确认，不由 AI 自行补全。

## 1. Core Tokens

### 1.1 颜色

#### Text

- `--color-text-primary`: Light `#0F172A`; Dark `#F4F4F5`
- `--color-text-secondary`: Light `#404040`; Dark `#D4D4D4`
- `--color-text-muted`: Light `#667085`; Dark `#A1A1AA`
- `--color-text-placeholder`: Light `#98A2B3`; Dark `#71717A`
- `--color-text-disabled`: Light `#98A2B3`; Dark `#71717A`
- `--color-text-readonly`: Light `#808080`; Dark `#A1A1AA`

#### Icon

- `--color-icon-default`: Light `#667085`; Dark `#A1A1AA`
- `--color-icon-muted`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-disabled`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-on-dark`: Light `#FFFFFF`; Dark `#FFFFFF`

#### Background

- `--color-bg-surface`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-hover`: Light `#F3F4F6`; Dark `#27272A`
- `--color-bg-disabled`: Light `#F3F4F6`; Dark `#202024`
- `--color-bg-readonly`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-popover`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-app-sidebar-bg`: Light `#F6F7F9`; Dark `#202024`
- `--color-app-sidebar-item-selected-bg`: Light `#FFFFFF`; Dark `#303036`
- `--color-app-topbar-bg`: Light `#FFFFFF`; Dark `#18181B`

#### Border

- `--color-border-control`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-border-control-hover`: Light `#D1D5DB`; Dark `#52525B`
- `--color-border-muted`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-border-divider`: Light `#E5E7EB`; Dark `#303036`
- `--color-border-disabled`: Light `#E5E7EB`; Dark `#303036`
- `--color-border-readonly`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-border-checkbox`: Light `#D0D5DD`; Dark `#52525B`

#### Accent

- `--color-accent`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-text-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-icon-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-border-active`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-bg-active`: Light `#EBF5FF`; Dark `#14275A`
- `--color-bg-active-hover`: Light `#E1EBFF`; Dark `#1B3470`
- `--color-bg-active-clear-hover`: Light `#D8E8FD`; Dark `#243F7F`

#### Focus

- `--color-border-focus`: macOS accent color
- `--color-focus-ring`: macOS accent color with opacity
  - Light Alpha: `0.22`
  - Dark Alpha: `0.30`
- `--focus-ring-width`: `2px`
- `--focus-ring-offset`: `2px`

#### Control

- `--color-primary-button-bg`: macOS accent color
- `--color-primary-button-bg-hover`: macOS accent color with native hover emphasis
- `--color-primary-button-text`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-bg-checkbox-unchecked`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-checkbox-checked`: Light `#111827`; Dark `#F4F4F5`
- `--color-checkbox-icon`: Light `#FFFFFF`; Dark `#18181B`
- `--color-danger-text`: Light `#B42318`; Dark `#FCA5A5`
- `--color-danger-bg-hover`: Light `#FEF3F2`; Dark `#3A1717`

#### Table

- `--color-row-hover`: Light `#F9FAFB`; Dark `#202024`
- `--color-row-selected`: Light `#F3F4F6`; Dark `#27272A`

#### Status

- `--color-chip-speaker-bg`: Light `#DDD6FE`; Dark `#31294C`
- `--color-chip-speaker-text`: Light `#5B21B6`; Dark `#D8B4FE`
- `--color-chip-language-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-chip-language-text`: Light `#0040FF`; Dark `#93C5FD`
- `--color-watch-status-unwatched-bg`: Light `#F3F4F6`; Dark `#27272A`
- `--color-watch-status-unwatched-text`: Light `#667085`; Dark `#A1A1AA`
- `--color-watch-status-watching-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-watch-status-watching-text`: Light `#0040FF`; Dark `#93C5FD`
- `--color-watch-status-finished-bg`: Light `#D1FAE5`; Dark `#123A2A`
- `--color-watch-status-finished-text`: Light `#047857`; Dark `#6EE7B7`

#### Scrollbar

- `--color-scrollbar-thumb-default`: Light `#CBD5E1`; Dark `#52525B`
- `--color-scrollbar-thumb-interactive`: Light `#94A3B8`; Dark `#71717A`
- `--color-scrollbar-track`: Light `transparent`; Dark `transparent`

#### Library Media

- `--color-library-progress-fill`: macOS accent color
- `--color-library-progress-track`: Light `#E5E7EB`; Dark `#303036`
- `--color-library-time-badge-bg`: Light `rgba(15,23,42,0.72)`; Dark `rgba(0,0,0,0.58)`
- `--color-library-time-badge-text`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-library-cover-placeholder-bg`: Light `#E5E7EB`; Dark `#303036`
- `--color-library-media-card-hover-bg`:
  - Light: macOS accent color with Alpha `0.08`
  - Dark: macOS accent color with Alpha `0.12`

#### Player Chrome

- `--color-player-stage-bg`: Light `#000000`; Dark `#000000`
- `--color-player-control-bg`: Light `rgba(0,0,0,0.30)`; Dark `rgba(0,0,0,0.30)`
- `--color-player-control-bg-hover`: Light `rgba(255,255,255,0.16)`; Dark `rgba(255,255,255,0.16)`
- `--color-player-menu-bg`: Light `rgba(0,0,0,0.55)`; Dark `rgba(0,0,0,0.55)`
- `--color-player-menu-item-hover-bg`: Light `rgba(255,255,255,0.12)`; Dark `rgba(255,255,255,0.12)`
- `--color-player-text-primary`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-player-text-secondary`: Light `rgba(255,255,255,0.62)`; Dark `rgba(255,255,255,0.62)`
- `--color-player-text-tertiary`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`
- `--color-player-icon-selected`: Light `#1A1A1F`; Dark `#1A1A1F`
- `--color-player-progress-fill`: macOS accent color
- `--color-player-progress-track`: Light `rgba(0,0,0,0.60)`; Dark `rgba(0,0,0,0.60)`
- `--color-player-progress-hover-track`: Light `rgba(255,255,255,0.35)`; Dark `rgba(255,255,255,0.35)`
- `--color-player-window-close`: Light `#FF5F57`; Dark `#FF5F57`
- `--color-player-window-minimize`: Light `#FEBC2E`; Dark `#FEBC2E`
- `--color-player-window-zoom`: Light `#28C840`; Dark `#28C840`
- `--color-player-window-control-border`: Light `rgba(0,0,0,0.18)`; Dark `rgba(0,0,0,0.18)`
- `--color-player-window-control-glyph`: Light `rgba(0,0,0,0.55)`; Dark `rgba(0,0,0,0.55)`
- `--color-player-topbar-gradient-start`: Light `rgba(18,18,24,0.66)`; Dark `rgba(18,18,24,0.66)`
- `--color-player-topbar-gradient-end`: Light `rgba(18,18,24,0)`; Dark `rgba(18,18,24,0)`

#### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#242426`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-unselected`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`

### 1.2 字体与文本

#### Typography

- `--font-family-base`: `system-ui, sans-serif`
- `--font-size-body`: `14px`
- `--font-size-control`: `14px`
- `--font-weight-control`: `500`
- `--weight-select-indicator`: `semibold`
- `--weight-button-icon`: `medium`
- `--font-size-table`: `14px`
- `--font-size-table-header`: `14px`
- `--font-size-caption`: `12px`
- `--line-height-table-cue-primary`: `24px`
- `--line-height-table-cue-secondary`: `20px`
- `--font-size-app-sidebar-item`: `13px`
- `--font-size-player-time`: `12px`
- `--font-size-player-progress-time`: `10px`
- `--font-size-player-speed-menu-check`: `11px`
- `--font-size-player-speed-menu-item`: `13px`
- `--font-size-player-topbar-title`: `13px`
- `--font-size-subtitle-focus-cue`: `40px`
- `--line-height-subtitle-focus-cue`: `52px`
- `--font-weight-subtitle-focus-cue`: `600`
- `--font-size-section-title`: `18px`
- `--font-size-library-title`: `14px`
- `--font-size-library-meta`: `12px`
- `--font-size-library-time-badge`: `10px`
- `--font-size-library-list-title`: `15px`
- `--font-size-library-list-subtitle`: `13px`
- `--font-size-library-list-meta`: `12px`

#### Text Decoration

- `--width-interactive-text-underline`: `1px`
- `--offset-interactive-text-underline`: `2px`

### 1.3 尺寸

#### Height

- `--height-filter-bar-control`: `40px`
- `--height-control`: `40px`
- `--height-field`: `40px`
- `--height-table-utility-bar`: `40px`
- `--height-table-header`: `40px`
- `--min-height-table-row`: `40px`
- `--height-action-menu-item`: `40px`
- `--height-select-menu-item`: `40px`
- `--height-app-sidebar-item`: `32px`
- `--height-app-topbar`: `45px`
- `--height-player-topbar`: `46px`
- `--height-player-bottom-control-bar`: `98px`
- `--height-player-bottom-controls-row`: `52px`
- `--height-player-capsule-button`: `40px`
- `--height-player-speed-menu`: `234px`
- `--height-player-speed-menu-item`: `30px`
- `--height-player-progress-hit-area`: `18px`
- `--height-player-progress-track`: `3px`
- `--height-player-progress-track-hover`: `6px`
- `--height-player-progress-time-capsule`: `22px`
- `--height-library-progress-bar`: `4px`
- `--height-library-list-cover`: `115px`

#### Size

- `--size-checkbox`: `16px`
- `--size-inline-clear-button`: `24px`
- `--size-inline-clear-icon`: `16px`
- `--size-inline-clear-symbol-font-size-macos`: `11pt`
- `--size-inline-add-symbol-font-size-macos`: `16pt`
- `--size-menu-item-symbol-font-size-macos`: `14pt`
- `--size-select-indicator`: `12pt`
- `--size-button-icon`: `14px`
- `--size-control-icon`: `16px`
- `--size-icon-button`: `32px`
- `--size-row-action-button`: `36px`
- `--scrollbar-size`: `8px`
- `--scrollbar-min-thumb-length`: `24px`
- `--width-app-sidebar`: `240px`
- `--size-app-sidebar-item-icon`: `18px`
- `--size-player-circle-button`: `40px`
- `--size-player-circle-button-icon`: `18px`
- `--width-player-speed-button`: `54px`
- `--width-player-speed-menu`: `172px`
- `--size-player-progress-thumb`: `12px`
- `--size-player-window-control-button`: `13px`
- `--size-player-window-control-glyph`: `7px`
- `--width-player-topbar-title-max`: `520px`
- `--width-subtitle-focus-content-max`: `960px`
- `--aspect-library-cover`: `16 / 9`
- `--width-library-recent-card-min`: `180px`
- `--width-library-recent-card-max`: `220px`
- `--width-library-episode-row-min`: `380px`
- `--width-library-list-cover`: `204px`
- `--width-library-folder-cover`: `120px`
- `--min-height-library-folder-card`: `96px`

### 1.4 间距

#### Spacing

- `--spacing-1`: `4px`
- `--spacing-2`: `8px`
- `--spacing-3`: `12px`
- `--spacing-4`: `16px`
- `--spacing-6`: `24px`
- `--spacing-8`: `32px`
- `--gap-subtitle-focus-cue`: `8px`
- `--gap-app-topbar-title-after-toggle`: `12px`
- `--gap-player-bottom-left-controls`: `8px`
- `--gap-player-bottom-right-controls`: `6px`
- `--gap-player-time-label`: `4px`
- `--gap-player-window-controls`: `8px`
- `--gap-player-speed-menu-from-button`: `8px`
- `--gap-library-recent-grid`: `16px`
- `--gap-library-episode-grid`: `16px`
- `--gap-library-list-item`: `20px`
- `--gap-library-list-info-vertical`: `8px`
- `--gap-library-folder-card-content`: `12px`

#### Padding

- `--padding-control-x`: `14px`
- `--padding-field-x`: `16px`
- `--padding-menu-item`: `12px 16px`
- `--padding-header-trigger-x`: `12px`
- `--padding-chip-x`: `10px`
- `--padding-chip-y`: `4px`
- `--padding-table-cell-hover-x`: `12px`
- `--padding-table-cell-hover-y`: `8px`
- `--padding-table-row-y`: `8px`
- `--padding-table-cell-leading`: `12px`
- `--padding-table-cell-trailing`: `14px`
- `--padding-subtitle-focus-cue-y`: `12px`
- `--padding-app-sidebar-x`: `12px`
- `--padding-app-sidebar-y`: `12px`
- `--padding-app-sidebar-item-x`: `10px`
- `--padding-app-topbar-title-x`: `24px`
- `--padding-player-chrome-x`: `24px`
- `--padding-player-chrome-bottom`: `12px`
- `--padding-player-progress-top`: `16px`
- `--padding-player-capsule-button-x`: `16px`
- `--padding-player-speed-menu`: `6px`
- `--padding-player-speed-menu-item-x`: `8px`
- `--padding-player-progress-time-capsule-x`: `8px`
- `--padding-player-topbar-x`: `16px`
- `--padding-library-folder-card`: `12px 16px`
- `--padding-library-time-badge`: `2px 6px`
- `--padding-library-media-card-hover`: `12px`
- `--padding-library-list-card`: `12px 16px`

### 1.5 形状与效果

#### Radius

- `--radius-control`: `8px`
- `--radius-field`: `8px`
- `--radius-search`: `9999px`
- `--radius-inline-clear-button`: `9999px`
- `--radius-checkbox`: `4px`
- `--radius-menu`: `16px`
- `--radius-select-menu-item`: `8px`
- `--radius-action-menu-item`: `8px`
- `--radius-row-action`: `8px`
- `--radius-table-cell-hover`: `8px`
- `--radius-chip`: `6px`
- `--scrollbar-radius`: `9999px`
- `--radius-app-sidebar-item`: `8px`
- `--radius-player-capsule`: `9999px`
- `--radius-player-speed-menu`: `14px`
- `--radius-player-speed-menu-item`: `8px`
- `--radius-library-cover`: `8px`
- `--radius-library-time-badge`: `4px`
- `--radius-library-folder-card`: `8px`
- `--radius-library-media-card-hover`: `20px`
- `--radius-library-list-card`: `16px`

#### Shadow

- `--shadow-popover`:
  - Light: `0 12px 24px rgba(15,23,42,0.12)`
  - Dark: `0 12px 24px rgba(0,0,0,0.36)`
- `--shadow-player-overlay`:
  - Light: `0 12px 24px rgba(0,0,0,0.42)`
  - Dark: `0 12px 24px rgba(0,0,0,0.42)`
- `--shadow-player-topbar-title`:
  - Light: `0 1px 2px rgba(0,0,0,0.50)`
  - Dark: `0 1px 2px rgba(0,0,0,0.50)`

### 1.6 动效

#### Interaction Motion

- `--scale-library-media-card-pressed`: `0.98`
- `--scale-library-cover-hover`: `1.02`
- `--duration-library-cover-hover`: `0.12s`

#### Subtitle Focus Motion

- `--duration-subtitle-focus-scroll`: `0.22s`
- `--easing-subtitle-focus-scroll`: `cubic-bezier(0.22, 1, 0.36, 1)`

### 1.7 Icon Assets

#### System Symbols

- Search: `magnifyingglass`
- Inline Clear: `xmark`, bold
- Filter: existing filter symbol
- Select Indicator: `chevrons-up-down`
- Sort Unsorted: `chevrons-up-down`
- Sort Ascending: `arrow-up`
- Sort Descending: `arrow-down`
- Inline Add: `plus`, medium
- Row Action: `ellipsis`
- Play: `play.fill`
- Copy: `copy`
- Context: `doc.text`
- Folder: `folder`
- Hide Column: `eye-off`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
- Settings: `gearshape`
- App Sidebar Toggle: macOS native sidebar toggle symbol

#### Custom Assets

- Recent、Library 和 Shiori Sidebar 图标沿用当前项目资源。
- Component 和 Layout 的参考图片应在所属条目中直接引用，不建立重复的全局说明。

## 2. 全局交互规则

### 2.1 状态集合

- 组件只定义实际存在差异的状态。
- 常用状态包括 Default、Hover、Pressed、Focused、Selected、Checked、Indeterminate、Menu Open、Highlighted、Disabled。
- Hover 和 Pressed 只作用于实际交互目标，不扩散到父容器或整行。
- 普通文字、图标和装饰元素不能表现为没有对应动作的控件。
- Selected 只表达持续生效的选择状态，不用于短暂 Hover。
- Menu Open 可以复用所属 Trigger 的 Hover 视觉。

### 2.2 Disabled 与 Read-only

- Disabled 不响应点击、Hover 或键盘操作，也不进入键盘焦点顺序。
- Disabled 控件使用对应的 disabled Token。
- Read-only 内容不可编辑，但仍可按所属界面规则选择和复制。
- `No value needed` 属于 Read-only，不属于 Disabled。
- Read-only 不显示 caret，也不使用 `not-allowed` Cursor。

### 2.3 Focus 与键盘导航

- 键盘焦点必须可见。
- 有边框控件使用 `--color-border-focus` 和 `--color-focus-ring`。
- 无边框控件使用 `--color-focus-ring`、`--focus-ring-width` 和 `--focus-ring-offset`。
- Search Box 和 Value Input Field 通过点击或键盘获得焦点时都显示 Focused 状态。
- Caret 只在可编辑输入区域获得焦点时出现。
- Checkbox 的焦点只作用于 Checkbox 本体。
- Sortable Header Cell 的焦点只作用于 Trigger Surface。
- 菜单中的键盘当前项使用 Highlighted 背景，不额外绘制蓝色 Focus Ring。
- Escape 关闭当前最上层的 Menu、Popover 或 Dialog。
- 一个键盘事件只能执行一个明确动作，不能同时作用于上下两层界面。

### 2.4 Pointer、点击区域与 Cursor

- 可编辑输入框和没有左键动作的普通可选择文字使用 `text`。
- Cue 的直接点击区域、Shiori Tags Cell、按钮、菜单项使用 `pointer`。
- 静态区域使用 `default`。
- Disabled 控件使用 `not-allowed`。
- Cursor 必须与实际点击区域一致。
- 没有动作的普通空白区域不得使用 `pointer`。
- Pointer 命中子控件时，不得同时触发父容器动作。

### 2.5 文字选择与复制

- 表格中的所有文字均可选择，包括表头、Display Title、Cues、Tags、Time Range 和 Date Added。
- 支持在单元格、列和行之间连续拖拽选择。
- 拖拽到可视区域顶部或底部时，表格自动滚动并继续扩展选择。
- 固定表头不随正文滚动，但仍参与文字选择和复制。
- 表格拥有键盘上下文时，`Cmd+A` 选择当前完整结果中的全部表格文字。
- `Cmd+A` 的范围包含表头、当前显示的列和全部结果行，不受当前滚动位置影响。
- 输入框拥有焦点时，`Cmd+A` 只选择该输入框的文字。
- `Cmd+C` 复制当前文字选择。
- 结构化复制时，列之间使用 Tab，表格行之间使用换行。
- 多行 Cue 在粘贴到电子表格后仍属于一个单元格。
- 文字选择不改变 Checkbox 批量选择状态。
- 文字拖拽优先于 Cue 和 Shiori Tags Cell 的单击；发生拖拽后不得执行播放或打开 Shiori Tag Popover。
- 表格存在文字选择时，CueSeeker 任一窗口内新的左键 Mouse Down 先清除旧选区；同一手势随后形成有效表格拖选时建立新选区。
- 右键 Mouse Down 不清除表格文字选择。

### 2.6 Context Menu

- Menu 以触发位置为锚点，优先显示在指针下方，并限制在当前可见区域内。
- 同一时间只打开一个同类 Menu。
- 点击 Menu 外部或按 Escape 关闭 Menu。
- Menu Item Hover 只作用于当前 Menu Item。
- Menu Open 不改变 Checkbox 状态或文字选择。
- Context Menu 内的命令只作用于明确的触发目标。

### 2.7 滚动与选择延伸

- Scrollbar 只表达当前可滚动区域。
- Scrollbar Drag 不触发内容命令。
- 文本拖选、Scrollbar Drag 和内容滚动是独立状态。
- 文本拖选触及顶部或底部时允许自动滚动。
- 自动滚动期间保持当前文字选择锚点。
- 固定表头不跟随正文纵向滚动。
- 水平滚动时，表头和正文列保持相同偏移。

## 3. Components

### 3.1 输入与选择

#### Search Box

- 用途：输入 Search 查询词。
- Token：`--height-filter-bar-control`、`--radius-search`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-disabled`、`--color-border-control`、`--color-border-focus`、`--color-border-disabled`、`--color-focus-ring`。
- 内容：Search 图标、输入文字、Placeholder、Inline Clear Button。
- 文字使用 `--font-family-base`、`--font-size-control`、`--color-text-primary`、`--color-text-placeholder`。
- 状态：Empty、Focused Empty、Typing / Focused Filled、Filled、Clear Button Hover、Disabled。
- 只有 Focused 或 Typing 状态显示 caret。
- 有内容时显示 Inline Clear Button。
- 输入区支持原生文字选择、`Cmd+A`、`Cmd+C`。

#### Select Trigger Button

- 用途：打开 Filter Sets、View 等选择型菜单。
- Token：`--height-filter-bar-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-focus`、`--color-border-disabled`。
- 内容：可选 Leading Icon、Label、Select Indicator。
- Select Indicator 固定使用 `chevrons-up-down`。
- Indicator 使用 `--size-select-indicator`、`--weight-select-indicator`，与文字间距使用 `--spacing-2`。
- 状态：Default、Hover、Menu Open、Disabled。
- Menu Open 时不把 Indicator 替换成单个 chevron。

#### Form Select Field

- 用途：在筛选编辑器中选择字段、运算符或其他枚举值。
- Token：`--height-field`、`--radius-field`、`--padding-field-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-focus`、`--color-border-disabled`。
- 内容：Label、可选 Leading Icon、`chevrons-up-down`。
- 状态：Default、Hover、Menu Open、Disabled。
- Menu Open 与 Hover 使用相同背景。
- Disabled 不打开菜单。

#### Value Input Field

- 用途：输入筛选值，或显示无需输入的只读说明。
- Token：`--height-field`、`--radius-field`、`--padding-field-x`、`--color-bg-surface`、`--color-bg-readonly`、`--color-bg-disabled`、`--color-border-control`、`--color-border-focus`、`--color-border-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--color-text-primary`、`--color-text-placeholder`、`--color-text-readonly`、`--color-text-disabled`。
- 状态：Empty、Focused Empty、Typing、Filled、Read-only / No Value Needed、Disabled。
- 只有 Focused 或 Typing 状态显示 caret。
- Read-only 可以选择复制，但不能编辑。
- Disabled 不响应输入。

#### Logic Connector

- 用途：表达筛选规则之间的 `Where`、`and`、`or` 关系。
- 静态文字使用 `--font-family-base`、`--font-size-body`、`--color-text-primary`。
- 可交互选择器复用 Form Select Field 的 Token。
- 第一条规则显示静态 `Where`。
- 第二条规则显示可选择的 `and / or`。
- 后续规则继承第二条逻辑并显示静态 Label。
- 可交互选择器固定使用 `chevrons-up-down`。

#### Tag Composer Field

- 用途：在同一流式区域中显示已关联标签，并输入、搜索或创建新标签。
- Token：`--spacing-2`、`--font-family-base`、`--font-size-body`、`--color-text-primary`、`--color-text-muted`。
- 标签使用 Chip / Tag。
- 输入框透明、无边框、无 Search 图标、无 Clear Button。
- 标签与输入文字在同一视觉行内垂直居中。
- 内容允许水平换行。
- 状态：Empty、Focused Empty、Typing、Filled With Tags、Filled With Tags And Typing、Disabled。
- 点击 Composer 空白区域聚焦输入框。
- 标签删除按钮只执行删除，不触发标签主体动作。

### 3.2 操作按钮

#### Inline Clear Button

- 用途：清除所属输入控件的当前值。
- Token：`--size-inline-clear-button`、`--radius-inline-clear-button`、`--size-inline-clear-icon`、`--size-inline-clear-symbol-font-size-macos`。
- 默认图标使用 `--color-icon-default`，Disabled 使用 `--color-icon-disabled`。
- Neutral Hover 使用 `--color-bg-hover`。
- Active Context Hover 使用 `--color-bg-active-clear-hover`。
- 使用 bold `xmark`。
- 始终无边框。
- 点击只清除当前值，不触发父控件动作。

#### Filter Panel Trigger Button

- 用途：显示筛选已生效状态并打开或关闭筛选面板。
- Token：`--height-filter-bar-control`、`--radius-control`、`--padding-control-x`、`--color-border-active`、`--color-bg-active`、`--color-bg-active-hover`。
- 文字和图标使用 `--color-text-active`、`--color-icon-active`。
- Disabled 使用 `--color-bg-disabled`、`--color-border-disabled`、`--color-text-disabled`。
- 状态：Active Default、Active Hover / Open、Clear Button Hover、Disabled。
- Trailing Clear 使用 Inline Clear Button。
- 点击 Clear 不得同时切换筛选面板。

#### Neutral Button

- 用途：执行保存、取消、导出等普通命令。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`、`--color-text-primary`。
- Leading Icon 可选，图文间距使用 `--spacing-2`。
- 状态：Default、Hover、Disabled。

#### Inline Add Button

- 用途：添加筛选条件、筛选集或其他内联项目。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-bg-hover`、`--size-control-icon`、`--size-inline-add-symbol-font-size-macos`。
- 使用 medium `plus`。
- 默认背景透明，始终无边框。
- Hover 只增加中性背景。
- Disabled 使用 `--color-text-disabled`。
- 状态：Default、Hover、Disabled。

#### Icon Button

- 用途：承载一个可由图标明确表达的独立动作。
- Token：`--size-icon-button`、`--radius-control`、`--size-control-icon`、`--color-bg-hover`、`--color-icon-default`、`--color-icon-disabled`。
- 默认背景透明，始终无边框。
- 状态：Default、Hover、Disabled。
- 不用于输入框内部 Clear。
- 不用于 Menu Item 内部 Trailing Action。

#### Row Action Button

- 用途：在明确需要可见入口时打开 Row Action Menu。
- Token：`--size-row-action-button`、`--radius-row-action`、`--color-bg-hover`、`--size-control-icon`、`--color-icon-default`、`--color-icon-disabled`。
- 使用 `ellipsis`。
- 状态：Default、Hover / Menu Open、Disabled。
- 当前 Search / Shiori / Context Table 不显示 Row Action Button。
- 如果其他界面使用该组件，它必须打开所属目标的同一套 Context Menu，不能维护另一套命令。

#### Destructive Button

- 用途：执行已经进入明确确认流程的破坏性命令。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-danger-bg-hover`、`--color-danger-text`。
- Disabled 使用 `--color-bg-disabled`、`--color-border-disabled`、`--color-text-disabled`、`--color-icon-disabled`。
- Leading Icon 可选，图文间距使用 `--spacing-2`。
- 状态：Default、Hover、Disabled。
- 不代替普通主按钮。

### 3.3 菜单系统

#### Menu Item Base

- 用途：统一 Select Menu Item 和 Action Menu Item 的内部结构。
- Token：`--padding-menu-item`、`--spacing-3`、`--color-bg-hover`、`--font-family-base`、`--font-size-body`、`--color-text-primary`、`--color-text-disabled`。
- 结构：Leading Slot、Label、可选 Trailing Slot。
- Leading Slot 的语义由具体 Menu Item 决定。
- Trailing Action 必须是无边框内联动作。
- 状态：Default、Hover / Highlighted、Disabled。

#### Select Menu Item

- 用途：表达一个可以被选择的菜单值。
- Token：`--height-select-menu-item`、`--radius-select-menu-item`、`--padding-menu-item`、`--spacing-3`、`--color-bg-hover`。
- Leading Slot 始终预留。
- 只有 Checked 状态显示 checkmark。
- Checked 不使用单独背景。
- 状态：Default、Hover / Highlighted、Checked、Disabled。
- 不定义 Checked + Highlighted 的独立视觉。

#### Action Menu Item

- 用途：表达一个立即执行的命令或子菜单入口。
- Token：`--height-action-menu-item`、`--radius-action-menu-item`、`--padding-menu-item`、`--spacing-3`、`--color-bg-hover`。
- Leading Icon 固定表达动作语义。
- Trailing Slot 可以显示 Submenu Indicator。
- 不使用 Checked 或 Selected。
- 状态：Default、Hover / Highlighted、Submenu、Disabled。

#### Column Header Menu

- 用途：为 Sortable Header Cell 提供排序和列显示命令。
- Trigger 使用 `--height-field`、`--padding-header-trigger-x`、`--radius-field`、`--color-bg-hover`。
- Menu 使用 `--color-bg-popover`、`--color-border-muted`、`--radius-menu`、`--shadow-popover`、`--spacing-1`。
- Menu Item 使用 Action Menu Item。
- 命令：Asc、Desc、Hide。
- Asc、Desc、Hide 使用固定 Leading Icon。
- 当前排序状态由 Header Indicator 表达，不使用 Checked Menu Item。
- Menu Open 只强调 Trigger Surface，不强调整列或整格 Header。
- Cues 不允许隐藏时，Hide 为 Disabled。

#### Row Action Menu

- 用途：显示统一的表格行级操作。
- Menu 使用 `--color-bg-popover`、`--color-border-muted`、`--radius-menu`、`--shadow-popover`、`--spacing-1`。
- Menu Item 使用 `--height-action-menu-item`、`--padding-menu-item`、`--radius-action-menu-item`、`--color-bg-hover`。
- 只在正文行的非 Selection Column 区域触发，包括所有数据 Cell 的内容和空白区域。
- Selection Column 的 Checkbox 和空白区域均不触发 Row Action Menu。
- 菜单目标始终是右键所在行的 Primary Cue，不自动扩展到已勾选行。
- 不根据右键所在的数据列打开不同菜单。
- 批量命令继续通过明确的 Batch Actions 入口执行。
- 具体命令、顺序和动作语义由 Search / Shiori / Context Table Layout 定义。

#### Library Card Context Menu

- 用途：为 Recent、Library Folder 和 Library Episode 卡片提供 Context Menu。
- Menu 使用 `--color-bg-popover`、`--color-border-muted`、`--radius-menu`、`--shadow-popover`、`--spacing-1`。
- Menu Item Hover 使用 `--color-bg-hover`。
- Recent 和 Library Folder 在卡片交互区域触发。
- Library Episode 只在 Cover Region 触发。
- 菜单锚定右键位置并限制在可见区域内。
- 点击菜单外关闭。
- 不显示系统 Popover Arrow。

#### Player Speed Menu

- 用途：显示并选择播放速度。
- Token：`--width-player-speed-menu`、`--height-player-speed-menu`、`--radius-player-speed-menu`、`--padding-player-speed-menu`。
- 背景、边框和阴影使用 `--color-player-menu-bg`、`--color-player-text-tertiary`、`--shadow-player-overlay`。
- Menu Item 使用 `--height-player-speed-menu-item`、`--radius-player-speed-menu-item`、`--padding-player-speed-menu-item-x`。
- Hover / Selected 使用 `--color-player-menu-item-hover-bg`。
- 当前速度显示 checkmark。
- 状态：Closed、Open、Item Default、Item Hover、Item Selected、Interaction Suppressed。
- 选择速度后应用并关闭菜单。

### 3.4 表格

#### Table Row

- 用途：承载一条 Primary Cue 及其只读元数据和批量选择状态。
- 最小行高使用 `--min-height-table-row`。
- 横向间距继续使用 `--padding-table-cell-leading` 和 `--padding-table-cell-trailing`，不修改、不统一。
- 正文纵向间距统一使用 `--padding-table-row-y`。
- 行顶部留白、Cues 内不同 Cue Item 之间的垂直间距、行底部留白相等。
- `--padding-table-cell-hover-y` 与 `--padding-table-row-y` 使用相同值。
- 设本行显示的 Cue Item 数量为 `N`，每个 Cue Item 的自然高度为 `Hᵢ`：

  `Cue Block Height = ΣHᵢ + (N - 1) × --padding-table-row-y`

- 最终行高：

  `Row Height = max(--min-height-table-row, max(All Column Content Block Heights) + 2 × --padding-table-row-y)`

- 所有列的完整内容块在行内垂直居中。
- Metadata 不再对齐 Primary Cue 第一视觉行。
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
- 所有 Cue 保留源换行和自动换行，不裁剪、不截断、不显示省略号。
- 行不显示 Full-row Hover 或 Full-row Selected 背景。
- 只显示水平 Divider，不显示垂直列分隔线。
- 普通左键不选择整行。
- Checkbox 是批量选择的唯一入口。
- 行级右键交互使用 Row Action Menu。

#### Sortable Header Cell

- 用途：显示列名、当前排序方向并打开 Column Header Menu。
- Token：`--height-table-header`、`--padding-header-trigger-x`、`--color-bg-hover`、`--font-size-table-header`、`--color-text-primary`、`--color-icon-default`。
- 排序状态：Unsorted、Sorted Asc、Sorted Desc。
- Indicator 分别为 `chevrons-up-down`、`arrow-up`、`arrow-down`。
- 交互状态：Default、Hover、Menu Open、Disabled / Not Sortable。
- Hover、Focus 和 Menu Open 只作用于 Trigger Surface。
- 不绘制垂直 Divider 或 Boxed Cell。
- Header 文字可以拖拽选择。
- 普通单击执行排序；发生文字拖拽时不执行排序。

#### Row Selection Checkbox

- 用途：明确控制单行或整个结果范围的批量选择。
- Token：`--size-checkbox`、`--radius-checkbox`、`--color-border-checkbox`、`--color-border-focus`、`--color-bg-checkbox-unchecked`、`--color-bg-checkbox-checked`、`--color-checkbox-icon`。
- 行状态：Unchecked、Checked、Disabled。
- Header 状态：Unchecked、Checked、Indeterminate、Disabled。
- Header Checkbox 不排序，也不打开 Column Header Menu。
- `Cmd+A` 不改变 Checkbox 状态。

#### Interactive Text Cell

- 用途：为 Cue 文字提供文字选择和表格正文中唯一的普通文字左键动作。
- Token：`--color-bg-hover`、`--radius-table-cell-hover`、`--padding-table-cell-hover-x`、`--padding-table-cell-hover-y`。
- 下划线使用 `--width-interactive-text-underline`、`--offset-interactive-text-underline` 和当前文字色。
- Hover Region 覆盖当前完整显示的 Cue 内容。
- Show Cue Group 开启时，所有显示的 Cue 共用一个 Hover Region。
- Hover 使用一个圆角矩形，不为每一行文字分别绘制背景。
- Hover 时所有显示的 Cue 文字显示下划线。
- 无拖拽的普通单击从 Primary Cue 播放。
- 从 Cue 文字开始拖拽时进入文字选择并抑制播放。
- Display Title、Tags 中的文字、Time Range 和 Date Added 不使用 Interactive Text Cell。
- 右键交给所属行的 Row Action Menu。

#### Table Scrollbar

- 用途：控制表格水平或垂直滚动位置。
- Token：`--scrollbar-size`、`--scrollbar-radius`、`--scrollbar-min-thumb-length`。
- Thumb 使用 `--color-scrollbar-thumb-default` 和 `--color-scrollbar-thumb-interactive`。
- Track 使用 `--color-scrollbar-track`。
- 状态：Vertical Default、Vertical Hover / Dragging、Horizontal Default、Horizontal Hover / Dragging。
- 只显示 Thumb，不显示箭头按钮。
- Track 保持透明。

#### Count Summary

- 用途：显示结果数量和批量选择数量。
- Token：`--height-table-utility-bar`、`--font-family-base`、`--font-size-body`、`--color-text-primary`、`--color-text-muted`。
- 默认格式：`{total} rows`
- 选择格式：`{selected} / {total} rows selected`
- 超过 `99999` 显示 `99999+`。
- 状态：Default、Overflow Total、Selected、Selected / Overflow。
- 只读，不响应点击。

### 3.5 展示与状态

#### Chip / Tag

- 用途：显示 Speaker、Language 或 Shiori Tag，并在所属界面允许时提供标签操作。
- Token：`--radius-chip`、`--padding-chip-x`、`--padding-chip-y`、`--font-family-base`、`--font-size-caption`。
- Speaker 使用 `--color-chip-speaker-bg`、`--color-chip-speaker-text`。
- Language 使用 `--color-chip-language-bg`、`--color-chip-language-text`。
- Shiori Tag 使用 `--color-bg-hover`、`--color-text-secondary`。
- Disabled 使用 `--color-bg-disabled`、`--color-text-disabled`。
- Table 内的 Tag 不显示删除按钮。
- Tag Composer 和 Popover 中的 Removable Tag 显示独立 `x`。
- `x` Hover 使用 `--color-danger-text`、`--color-danger-bg-hover`。
- 标签主体和删除按钮是两个独立命中区域。
- Table Tag 文字可以拖拽选择。
- Table Tag 不单独定义表格中的左键或右键动作。
- Table Tag 所属 Shiori Tags Cell 的交互由 Search / Shiori / Context Table Layout 定义。

#### Section Title

- 用途：显示 Library 或其他内容区域的章节标题。
- Token：`--font-family-base`、`--font-size-section-title`、`--color-text-primary`。
- 字重为 semibold。
- 左对齐、透明背景、无边框。
- 只读，不承担导航或展开动作。

#### Watch Status Badge

- 用途：显示 Unwatched、Watching、Finished 状态。
- Token：`--radius-chip`、`--padding-chip-x`、`--padding-chip-y`、`--font-family-base`、`--font-size-caption`。
- 三种状态分别使用 `--color-watch-status-unwatched-*`、`--color-watch-status-watching-*`、`--color-watch-status-finished-*`。
- 状态：Unwatched、Watching、Finished、Disabled。
- 只读，不独立修改观看状态。

#### Empty Hint

- 用途：在当前区域没有内容时显示简短说明。
- Token：`--font-family-base`、`--font-size-library-meta`、`--color-text-muted`。
- 在所属空状态区域中居中。
- 透明背景、无边框。
- 只读，不承担恢复或创建动作。

### 3.6 Library Media

#### Library Cover

- 用途：显示视频或文件夹封面。
- Token：`--aspect-library-cover`、`--radius-library-cover`、`--color-library-cover-placeholder-bg`。
- 状态：No Cover、Loaded。
- 图片填满容器并保持比例裁切。
- 本组件不定义点击动作，交互由所属卡片决定。

#### Library Cover Progress Overlay

- 用途：在封面底部显示观看进度。
- Token：`--height-library-progress-bar`、`--color-library-progress-track`、`--color-library-progress-fill`。
- No Progress 和 Unknown Duration 状态隐藏。
- In Progress 按比例显示。
- Finished 填满。
- 只读，不参与 Hit Testing。

#### Library Cover Badge

- 用途：在封面右下角显示时间或数量。
- Token：`--radius-library-time-badge`、`--padding-library-time-badge`、`--color-library-time-badge-bg`、`--font-size-library-time-badge`、`--color-library-time-badge-text`。
- 状态：Time、Count、Hidden。
- 只读，不独立响应点击。

### 3.7 App Navigation

#### App Sidebar Toggle Button

- 用途：展开或折叠 App Sidebar。
- Token：`--size-icon-button`、`--radius-control`、`--color-bg-hover`、`--size-control-icon`、`--color-icon-default`、`--color-icon-disabled`。
- 使用 macOS native sidebar toggle symbol。
- 默认背景透明，始终无边框。
- 状态：Default、Hover、Disabled。

#### App Sidebar Navigation Item

- 用途：在 Search、Recent、Library 和 Shiori 之间导航。
- Token：`--height-app-sidebar-item`、`--radius-app-sidebar-item`、`--padding-app-sidebar-item-x`、`--color-app-sidebar-item-selected-bg`、`--spacing-3`。
- 文字使用 `--font-family-base`、`--font-size-app-sidebar-item`、`--color-text-primary`、`--color-text-disabled`。
- 图标使用 `--size-app-sidebar-item-icon`、`--color-icon-default`、`--color-icon-disabled`。
- 状态：Default、Selected、Disabled。
- 同一时刻只有当前页面处于 Selected。
- 点击当前 Selected Item 不重复导航。

#### App Sidebar Settings Item

- 用途：打开 Settings。
- Token 与 App Sidebar Navigation Item 相同。
- 图标固定使用 `gearshape`。
- Label 固定为 `Settings`。
- 状态：Default、Disabled。
- 它是独立命令，不参与主要导航项的 Selected 状态。

### 3.8 Player Controls

#### Player Circle Button

- 用途：承载播放器中的单一图标命令或持续切换状态。
- Token：`--size-player-circle-button`、`--radius-player-capsule`、`--color-player-control-bg-hover`、`--size-player-circle-button-icon`。
- 图标使用 `--color-player-text-primary`、`--color-player-icon-selected`、`--color-player-text-tertiary`。
- 状态：Default、Hover、Pressed、Selected、Disabled、Interaction Suppressed。
- Selected 只用于持续生效的切换状态。
- Interaction Suppressed 不响应指针，也不显示可点击反馈。

#### Player Capsule Button

- 用途：显示时间、速度等短文本，并在允许时执行命令。
- Token：`--height-player-capsule-button`、`--radius-player-capsule`、`--padding-player-capsule-button-x`、`--color-player-control-bg`、`--color-player-control-bg-hover`。
- 文字使用 `--color-player-text-primary`、`--color-player-text-tertiary`、`--font-size-player-time`。
- 数字使用等宽数字。
- 状态：Default、Hover、Pressed、Menu Open、Disabled、Interaction Suppressed。

#### Player Circle Button Group

- 用途：将相关 Player Circle Button 放入同一个胶囊容器。
- Token：`--height-player-capsule-button`、`--radius-player-capsule`、`--color-player-control-bg`、`--color-player-control-bg-hover`。
- 横向排列，子项之间无间隙。
- 只有子按钮响应点击。
- 容器空白区域不承担动作。
- 状态：Default、Child Hover、Child Pressed、Child Disabled、Interaction Suppressed。

#### Player Progress Scrubber

- 用途：显示播放进度并支持预览和 Seek。
- Token：`--height-player-progress-hit-area`、`--height-player-progress-track`、`--height-player-progress-track-hover`、`--radius-player-capsule`。
- Track 使用 `--color-player-progress-track`、`--color-player-progress-hover-track`、`--color-player-progress-fill`。
- Thumb 使用 `--size-player-progress-thumb`、`--color-player-progress-fill`。
- 状态：Default、Hover、Dragging、Disabled / No Duration。
- Hover 显示 Preview Track、Thumb 和 Player Progress Time Capsule。
- Dragging 持续显示 Thumb 和时间预览。
- 无有效 Duration 时不可 Seek。

#### Player Progress Time Capsule

- 用途：在 Progress Hover 或 Drag 时显示目标时间。
- Token：`--height-player-progress-time-capsule`、`--radius-player-capsule`、`--padding-player-progress-time-capsule-x`、`--color-player-control-bg`。
- 文字使用 `--color-player-text-primary`、`--font-size-player-progress-time`。
- 数字使用等宽数字。
- 状态：Hidden、Visible On Progress Hover、Visible On Progress Drag。
- 不参与 Hit Testing。

#### Player Window Control Button

- 用途：提供播放器页面中的 Close、Minimize 和 Zoom。
- Token：`--size-player-window-control-button`、`--radius-player-capsule`、`--color-player-window-control-border`。
- 三种背景使用 `--color-player-window-close`、`--color-player-window-minimize`、`--color-player-window-zoom`。
- Glyph 使用 `--color-player-window-control-glyph`、`--size-player-window-control-glyph`。
- 状态：Default、Cluster Hover / Glyph Visible、Pressed。
- 任一按钮 Hover 时，同组按钮显示各自 Glyph。

#### Player Topbar Title

- 用途：显示当前播放项目标题。
- Token：`--width-player-topbar-title-max`、`--color-player-text-primary`、`--font-size-player-topbar-title`、`--shadow-player-topbar-title`。
- 单行居中。
- 超过最大宽度时尾部截断。
- 状态：Default、Truncated。
- 只读，不承担播放或导航动作。

### 3.9 Subtitle Focus

#### Subtitle Focus Cue

- 用途：显示一个完整 Cue，并表达当前键盘动作目标。
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- Natural Height：

  `Visual Line Count × --line-height-subtitle-focus-cue + 2 × --padding-subtitle-focus-cue-y`

- Resolved Height 不超过 Cue Reel Viewport Height。
- Oversized Cue 从第一视觉行开始显示，只裁掉底部超出内容。
- 不显示省略号。
- 完整 Cue 原文继续作为 S、C 和 Space 的动作值。
- Cue 本身没有 Hover 或点击动作。
- 点击不得改变选择，也不得穿透到底层 Video。
- Wheel Event 交给所属 Cue Reel。

## 4. Layouts

### 4.1 App Shell

#### App Sidebar Layout

- 固定在窗口左侧。
- 宽度为 `--width-app-sidebar`，高度占满窗口。
- 背景使用 `--color-app-sidebar-bg`。
- 水平内边距使用 `--padding-app-sidebar-x`。
- 垂直内边距使用 `--padding-app-sidebar-y`。
- 从上到下包括：
  1. Top Safe Area
  2. Navigation Region
  3. Flexible Spacer
  4. Settings Region
- Top Safe Area 为 macOS Window Controls 和 Sidebar Toggle 预留空间。
- Navigation Region 纵向排列 App Sidebar Navigation Item，间距使用 `--spacing-1`。
- Navigation Item：
  - Search
  - Recent
  - Library
  - Shiori
- Settings Region 包含 App Sidebar Settings Item。
- Expanded 为默认状态，显示图标和 Label。
- Collapsed 隐藏 Sidebar 内容，并从主内容区移除 Sidebar 宽度。
- Sidebar Toggle 在 Collapsed 状态下仍显示。
- 点击 Navigation Item 切换工作台页面。
- 点击 Settings 打开 Settings Window。
- Sidebar Expanded / Collapsed 状态跨 App 启动保留。

#### App Topbar Layout

- 用于非 Playback 页面。
- 位于窗口顶部，宽度占满窗口。
- 高度为 `--height-app-topbar`。
- 背景使用 `--color-app-topbar-bg`。
- Sidebar 展开时显示宽度为 `--width-app-sidebar` 的 Sidebar Segment。
- Sidebar Segment 使用 `--color-app-sidebar-bg`。
- Sidebar Toggle Slot 在 Expanded 和 Collapsed 状态下都保持可见。
- Title Slot 使用现有标题组件。
- Expanded 状态的 Title Leading：

  `--width-app-sidebar + --padding-app-topbar-title-x`

- Collapsed 状态的 Title Leading：

  `max(--padding-app-topbar-title-x, Sidebar Toggle Trailing Edge + --gap-app-topbar-title-after-toggle)`

- 空白区域支持原生窗口拖动。
- 双击空白区域遵循 macOS Titlebar 行为。
- Playback Page 显示时隐藏 App Topbar。

### 4.2 Recent 与 Library

#### Recent Watching Card Layout

- 卡片为纵向 Media Card。
- 卡片宽度处于 `--width-library-recent-card-min` 和 `--width-library-recent-card-max` 之间。
- 卡片间距使用 `--gap-library-recent-grid`。
- 内容间距使用 `--spacing-2`。
- Hover 外围使用 `--padding-library-media-card-hover`。
- Hover 圆角使用 `--radius-library-media-card-hover`。
- Hover 背景使用 `--color-library-media-card-hover-bg`。
- 内容包括：
  - Library Cover
  - Library Cover Progress Overlay
  - Library Cover Badge / Time
  - Folder Name
  - Episode Label
  - Watch Status Badge
- Folder Name 使用 `--font-size-library-title`、`--color-text-primary`，单行显示。
- Episode Label 使用 `--font-size-library-meta`、`--color-text-muted`。
- 左键从保存的播放位置打开视频。
- 右键打开 Library Card Context Menu，不触发播放。
- Context Menu 可以包含：
  - Open Folder
  - Mark as Finished
  - Mark as Unwatched
  - Mark as Watching
  - Context
- 文件缺失或 Disabled 时降低透明度并禁用点击。

#### Library Folder Card Layout

- 卡片为纵向 Media Card。
- 内容间距使用 `--spacing-2`。
- Hover 外围使用 `--padding-library-media-card-hover`。
- Hover 圆角使用 `--radius-library-media-card-hover`。
- Hover 背景使用 `--color-library-media-card-hover-bg`。
- 内容包括：
  - Library Cover
  - Library Cover Badge / Count
  - Folder Name
- Folder Name 使用 `--font-size-library-title`、`--color-text-primary`，单行显示。
- Pressed 时缩放至 `--scale-library-media-card-pressed`。
- 左键进入 Library Folder Detail。
- 右键打开 Library Card Context Menu。
- Context Menu 可以包含：
  - Open Folder
  - Mark All as Finished
  - Mark All as Unwatched
  - Mark All as Watching
- Empty Folder 或 Disabled 状态禁用点击。

#### Library Episode Grid and Card Layout

- Grid 位于 Library Folder Detail。
- 使用单列布局。
- Row 占满可用内容宽度。
- 最小 Row Width 使用 `--width-library-episode-row-min`。
- Row 间距使用 `--gap-library-episode-grid`。
- Episode Card 水平排列。
- Card 使用 `--gap-library-list-item`、`--padding-library-list-card`、`--radius-library-list-card`。
- 分为 Cover Region 和 Info Region。
- Action Region 已移除。
- Cover Region：
  - 宽度 `--width-library-list-cover`
  - 高度 `--height-library-list-cover`
  - 包含 Library Cover、Progress Overlay、Time Badge
  - 是唯一的播放和 Context Menu 区域
  - Hover 使用 `--radius-library-media-card-hover`、`--color-library-media-card-hover-bg`
- Info Region：
  - 高度与 Cover Region 相同
  - 使用纵向布局
  - 间距为 `--gap-library-list-info-vertical`
  - 不触发播放 Hover
- 第一行包括 Video Name 和 Watch Status Badge。
- Video Name 使用 `--font-size-library-list-title`、semibold、`--color-text-primary`。
- 第二行显示：

  `字幕文件：{subtitle file name}`

- 第二行使用 `--font-size-library-list-subtitle`、`--color-text-secondary`。
- 第三行显示：

  `{video size} {resolution} {frame rate} {codec}`

- 第三行使用 `--font-size-library-list-meta`、`--color-text-muted`。
- 左键点击 Cover Region 从保存位置播放。
- 右键点击 Cover Region 打开 Library Card Context Menu。
- Info Region 不显示 Pointer Cursor。
- 文件缺失时禁用 Cover Region。

#### Library Folder Detail Header Layout

- 使用水平布局。
- 子项垂直居中。
- 间距使用 `--spacing-2`。
- 包含：
  - Back Button：Icon Button，`chevron.left`
  - Title：Section Title，内容为 Folder Name
- 点击 Back Button 返回 Library 一级界面。
- Title 只读。

### 4.3 Search、Shiori 与 Context

#### Search Filter Bar Layout

- 使用水平 Toolbar。
- 子项垂直居中。
- 间距使用 `--spacing-3`。
- Search Box 为主要 Flexible 区域。
- Filter Sets Select Trigger 和 Filter Panel Trigger Button 为固定内容宽度。
- 基本顺序：

  `Search Box → Filter Sets Select Trigger → Filter Panel Trigger Button`

- 不需要查询输入的页面可以隐藏 Search Box，但保留 Filter Controls。
- Filter Editor 作为二级界面打开。
- Filter Editor 可以组合：
  - Logic Connector
  - Form Select Field
  - Value Input Field
  - Inline Add Button
  - Neutral Button
- 输入 Query 只更新当前输入内容。
- 提交后更新结果。
- Filter Trigger 负责打开、关闭和清除筛选。

#### Search / Shiori Utility Bar Layout

- 使用水平布局。
- 高度使用 `--height-table-utility-bar`。
- 子项垂直居中。
- 间距使用 `--spacing-3`。
- 左右区域使用 `space-between`。
- Left Region 包含：
  - Count Summary
  - Batch Actions
- Batch Actions 使用 Neutral Button。
- Batch Actions 只在 Checkbox Selected Count 大于 `0` 时显示。
- Right Region 包含 View Controls。
- View Controls 可以使用 Icon Button 和 Select Trigger Button。
- View Menu 控制列显示。
- Cues 始终显示，不允许隐藏。
- Utility Bar 的复杂 Batch 操作只提供入口，具体配置在二级界面中完成。

#### Search / Shiori / Context Table Layout

- 适用于 Search、Shiori 和 Search-hosted Context。
- Header 固定，正文独立滚动。
- Header 和正文保持相同水平偏移。
- 不显示垂直列分隔线。
- 只显示水平 Row Divider。
- Header 和正文默认使用 `--color-bg-surface`。
- 不为 Header 增加独立 Tint。

- Search / Context 列顺序：
  1. Selection
  2. Display Title
  3. Cues
  4. Time Range

- Shiori 列顺序：
  1. Selection
  2. Display Title
  3. Cues
  4. Tags
  5. Time Range
  6. Date Added

- Column Width：
  - Selection：`50pt`，固定
  - Display Title：`240pt`，固定
  - Cues：最小 `520pt`，填满剩余宽度
  - Tags：`180pt`，固定，仅 Shiori
  - Time Range：`190pt`，固定
  - Date Added：`160pt`，固定，仅 Shiori

- Cues / Primary Cue：
  - 主要内容
  - `--color-text-secondary`
  - Hover 使用 `--color-text-primary`
  - `--font-size-table`
  - `--line-height-table-cue-primary`
  - Font Weight `500`

- Cues / Extra Cues：
  - Show Cue Group 开启时显示
  - 位于 Primary Cue 上方
  - `--color-text-muted`
  - `--font-size-caption`
  - `--line-height-table-cue-secondary`
  - Font Weight `400`

- Display Title：
  - Secondary Context
  - `--color-text-secondary`
  - Font Weight `500`

- Tags：
  - 仅 Shiori
  - 使用 Chip / Tag
  - Table Tag 不显示删除按钮

- Time Range 和 Date Added：
  - Metadata
  - `--color-text-secondary`
  - Font Weight `500`
  - 使用 `tabular-nums`

- Time Range 格式：

  `hh:mm:ss - hh:mm:ss`

- 当开始和结束的小时均为 `00` 时：

  `mm:ss - mm:ss`

- Time Range 按 Cue Start Time 排序。

- Table Row 的垂直几何遵循 Table Row Component。

- Show Cue Group：
  - 设置位置：Settings / Search，紧接 Search Scope
  - Control：macOS native switch
  - Label：`Show Cue Group`
  - Default：Off
  - 跨 App 启动保留
  - 适用于 Search、Shiori 和 Context
  - Off：只显示 Primary Cue
  - On：在 Primary Cue 上方显示全部 Additional Cues
  - Primary Cue Identity 不变
  - 所有默认动作继续以 Primary Cue 为目标
  - 所有显示的 Cue 共用一个 Hover 和点击区域
  - Primary Cue 与 Extra Cues 只通过字体和颜色区分

- 文字选择遵循 `2.5 文字选择与复制`。

- 正文左键：
  - Cues 使用 Interactive Text Cell。
  - Shiori Tags Cell 是显式控件，整个 Cell 均可点击，包括没有 Tag 的空白区域。
  - 无拖拽单击 Shiori Tags Cell，打开 Shiori Tag Popover。
  - 从 Shiori Tags Cell 内的文字开始拖拽时只进行文字选择，不打开 Popover。
  - Display Title、Time Range 和 Date Added 文字只负责选择和复制。
  - Checkbox 只改变批量选择。
  - 除 Shiori Tags Cell 外，其他普通空白区域无动作。
  - 文字拖选可以从非标题栏且非顶栏的任意非交互区域开始（非交互区域 = 点击没有效果的区域）。手势进入表格后才建立新选区。
  - 选区内容始终只有表格文字。

- 正文 Hover：
  - 不显示 Full-row Hover 或 Full-row Selected。
  - Cue Hover 使用 Interactive Text Cell。
  - Display Title、Time Range 和 Date Added 不显示可点击 Hover。
  - Pointer Cursor 只出现在 Cue 的直接点击区域和 Shiori Tags Cell。

- 行右键交互使用 Row Action Menu。

- Search / Context Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  6. `Copy Time Range`

- Shiori Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  6. `Copy Time Range`
  7. `Remove Shiori`

- Divider：
  - `Context` 与 `Copy Cue Text` 之间显示 Divider。
  - Shiori 的 `Copy Time Range` 与 `Remove Shiori` 之间显示 Divider。

- `Play`：
  - 从 Primary Cue 播放。

- `Open Subtitle Folder`：
  - 打开 Subtitle File 所在文件夹。
  - 在文件夹中选中对应 Subtitle File。

- `Context`：
  - 打开 Primary Cue 的 Context。
  - 当前已位于 Context 时，以右键所在行的 Primary Cue 更新 Context 目标。

- `Copy Cue Text`：
  - 只复制 Primary Cue 的准确文字。
  - 保留源行序和换行。

- `Copy Cue Group Text`：
  - 仅 `Show Cue Group = On` 时显示。
  - 按稳定 Source Display Order 复制当前显示的完整 Cue Group。
  - 保留每个 Cue 的源行序和换行。

- `Copy Time Range`：
  - 复制当前行 Primary Cue 显示的 Time Range。
  - 输出格式遵循本 Layout 的 Time Range 格式。

- `Remove Shiori`：
  - 仅用于 Shiori。
  - 打开 Confirmation Dialog。
  - 不直接移除。

- View Menu：
  - Cues 始终 Checked 且 Disabled。
  - 其他数据列可以隐藏。
  - Selection Column 不作为普通数据列隐藏。

- Search Empty Hint：
  - 文案：`Enter a search term or add filters to show cues.`
  - 条件：没有 Search Term，也没有 Effective Filter Condition。

- Shiori Empty Hint：
  - 文案：`Save cues from playback to collect Shiori.`
  - 条件：没有已保存的 Shiori Row。

- Effective Filter Condition：
  - 具有非空 Value 的规则。
  - 不需要 Value 的 Presence-style 规则，例如 `Cues is not empty`。

### 4.4 Dialogs 与 Popovers

#### Confirmation Dialog Layout

- 使用 Modal Overlay。
- Panel 居中、纵向排列。
- Panel 背景使用 `--color-bg-surface`。
- Panel 圆角使用 `--radius-control`。
- Panel 边框使用 `--color-border-control`。
- 从上到下包括：
  1. Title
  2. Message
  3. Actions
- Title 使用 `--color-text-primary`。
- Message 使用 `--color-text-muted`。
- Actions 水平排列并 Trailing 对齐。
- Actions 使用 Neutral Button 和 Destructive Button。
- 默认焦点为 Cancel。
- Escape 等同于 Cancel。
- 点击 Dialog 外部不关闭。
- Return 激活当前默认焦点动作。

- Remove Shiori：
  - Title：`Remove Shiori`
  - Message：`This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.`
  - Cancel：Neutral Button，`Cancel`
  - Confirm：Destructive Button，`Remove`

- Delete Tag：
  - Title：`Delete Tag`
  - Message：`Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone.`
  - Cancel：Neutral Button，`Cancel`
  - Confirm：Destructive Button，`Delete`

- Confirm 只执行当前明确的 Command Target。
- Cancel 不产生数据变更。

#### Shiori Tag Popover Layout

- 使用无系统箭头的 Popover Overlay。
- 锚定于 Shiori Tags Cell 的点击位置。
- 优先显示在指针下方，并限制在可见区域内。
- 点击 Popover 外部关闭。
- 点击 Popover 内部不自动关闭。
- 内容变化时允许重新测量和调整位置。
- 从上到下包括：
  1. Current Tags and Search
  2. Global Tag Pool
- 两个 Section 之间不显示 Separator。
- Delete Tag Confirmation 使用居中的 Confirmation Dialog，不嵌入 Popover Panel。

- Current Tags and Search：
  - Hint：`Current Tags`
  - Hint 使用 `--color-text-muted`
  - Tag Composer 使用 Tag Composer Field
  - Current Tags 使用 Removable Chip / Tag
  - 无 Current Tags 时 Placeholder 为 `Add a tag`
  - 已有 Current Tags 时不显示 Placeholder

- Global Tag Pool：
  - Hint：`Select a tag or create one`
  - Hint 使用 `--color-text-muted`
  - Tags 使用水平换行布局
  - 输入为空时显示全部 Existing Tags
  - 输入非空时显示 Matching Tags
  - 已关联 Tag 仍然显示
  - 输入非空且没有完全匹配时显示 Create Option
  - Create Option 使用 `Create` Label 和当前输入文字的 Tag Preview
  - Create Option Hover 使用 `--color-bg-hover`

- 打开时自动聚焦 Tag Composer Input。
- 点击尚未关联的 Tag：
  - 只关联当前 Shiori
  - 清空输入
  - 保持 Popover 打开
  - 恢复输入焦点
- 点击已经关联的 Tag：
  - 不执行动作
  - 不显示提示
  - 保持 Popover 打开
- 点击 Create Option：
  - 创建 Tag
  - 关联当前 Shiori
  - 清空输入
  - 保持 Popover 打开
- Current Tag Body 无动作。
- Current Tag `x` 只解除当前 Shiori 的 Tag 关联。
- Global Tag `x` 打开 Delete Tag Confirmation。
- Escape：
  - Dialog 未打开时关闭 Popover
  - Dialog 打开时取消 Dialog
- 右键不打开 Tag 专用 Menu；所属 Table Row 的统一 Row Action Menu 优先。

### 4.5 Player

#### Player Topbar Layout

- 位于 Playback Page 顶部。
- 宽度占满窗口。
- 高度使用 `--height-player-topbar`。
- 背景为：

  `--color-player-topbar-gradient-start → --color-player-topbar-gradient-end`

- 可见性跟随 Player UI Visible / Hidden。
- Fullscreen 时隐藏，由 macOS Fullscreen Titlebar 接管。
- Window Control Cluster 位于 Leading。
- Window Control 间距使用 `--gap-player-window-controls`。
- 包含 Close、Minimize、Zoom。
- Title Slot 在 Topbar 中居中。
- Title 最大宽度使用 `--width-player-topbar-title-max`。
- Empty Titlebar Area 支持窗口拖动和双击。
- Window Control Cluster Hover 时显示全部 Glyph。
- Close 返回播放来源页面。
- Minimize 最小化窗口。
- Zoom 进入 Fullscreen。

#### Player Bottom Control Bar Layout

- 位于 Playback Stage 底部。
- 宽度占满 Playback Stage。
- 高度使用 `--height-player-bottom-control-bar`。
- 背景透明。
- 使用纵向布局。
- 可见性跟随 Player UI Visible / Hidden。

- Progress Region：
  - 位于顶部
  - 包含 Player Progress Scrubber
  - 水平内边距使用 `--padding-player-chrome-x`

- Control Region：
  - 位于 Progress Region 下方
  - 高度使用 `--height-player-bottom-controls-row`
  - 水平内边距使用 `--padding-player-chrome-x`
  - 底部内边距使用 `--padding-player-chrome-bottom`

- Left Control Group：
  - Leading 对齐
  - 间距使用 `--gap-player-bottom-left-controls`
  - Play / Pause
  - Previous / Next
  - Existing Playback Volume Control
  - Playback Time

- Right Control Group：
  - Trailing 对齐
  - 间距使用 `--gap-player-bottom-right-controls`
  - Show / Hide Subtitles
  - Playback Speed
  - Fullscreen

- 两组之间由 Flexible Spacer 分隔。
- Speed Button 使用 Player Capsule Button。
- Speed Button 宽度使用 `--width-player-speed-button`。
- Speed Menu 与按钮间距使用 `--gap-player-speed-menu-from-button`。
- Timeline Scrubbing 期间抑制无关 Hover 和 Menu Interaction。
- Scrubbing 结束后恢复正常交互。

#### Player Progress Scrubber Layout

- 位于 Player Bottom Control Bar 顶部。
- 宽度占满可用空间。
- Hit Area 高度使用 `--height-player-progress-hit-area`。
- Track 在 Hit Area 中垂直居中。
- Track 包含：
  - Base Track
  - Hover Preview Track
  - Played Track
  - Thumb

- Base Track：
  - 默认高度 `--height-player-progress-track`
  - Hover / Drag 高度 `--height-player-progress-track-hover`
  - 颜色 `--color-player-progress-track`

- Hover Preview Track：
  - 从起点延伸至 Pointer
  - 使用 `--color-player-progress-hover-track`
  - Hover 时显示

- Played Track：
  - 表达当前播放进度
  - Drag 时表达当前 Scrub Target
  - 使用 `--color-player-progress-fill`

- Thumb：
  - 使用 `--size-player-progress-thumb`
  - Hover 或 Drag 时显示

- Player Progress Time Capsule：
  - 位于 Pointer 或 Drag 位置上方
  - 水平居中并限制在 Scrubber Bounds 内
  - 无 Duration 时不显示

- Pointer Hover：
  - 增加 Track Height
  - 显示 Preview、Thumb、Time Capsule

- Pointer Move：
  - 更新 Preview Width
  - 更新时间与位置

- Drag Start：
  - 开始 Scrubbing
  - 显示 Thumb 和 Time Capsule
  - 抑制无关 Player Chrome Interaction

- Drag Move：
  - 更新 Target Time 和 Preview

- Drag End：
  - Seek 至最终 Target
  - 结束 Scrubbing
  - 恢复正常交互

- Pointer Exit：
  - 非 Drag 状态隐藏 Preview、Thumb 和 Time Capsule

#### Playback Subtitle Focus Overlay Layout

- 覆盖完整 Playback Stage。
- 不是独立原生窗口。
- 位于 Video 和 Playback Chrome 之上。
- 位于现有 Playback Feedback Overlay 之下。
- 背景使用 `--color-subtitle-focus-overlay-bg`。
- Light 和 Dark Appearance 均使用固定 Dark Appearance。
- 内容内边距使用 `--spacing-8`。
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。

- Subtitle Focus Cue Reel：
  - 在 Overlay 内居中
  - 最大宽度使用 `--width-subtitle-focus-content-max`
  - 纵向排列 Subtitle Focus Cue
  - Cue Gap 使用 `--gap-subtitle-focus-cue`
  - 允许顶部和底部出现部分可见的相邻 Cue
  - 不显示卡片、边框、背景或可见 Focus Marker

- Focus Anchor：
  - 是不可见的 Screen-space Anchor
  - 固定在 Cue Reel Viewport 垂直中心
  - Fit Cue 的完整中心与 Focus Anchor 对齐
  - Oversized Cue 的顶边与 Viewport 顶边对齐
  - 第一和最后一个 Fit Cue 也可以使用相同 Anchor
  - 窗口宽度变化后保留当前 Cue，并恢复对应 Placement

- Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - Natural Height：

    `52 × Visual Line Count + 24px`

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 一行 Cue Natural Height：`76px`
  - 两行 Cue Natural Height：`128px`
  - 三行 Cue Natural Height：`180px`
  - Fit Cue 显示全部内容
  - Oversized Cue 从第一视觉行开始，只裁剪底部超出内容
  - Oversized Cue 不保留内部阅读 Offset

- Subtitle Focus Scrollbar：
  - 位于 Overlay Trailing Edge
  - 使用纵向 Table Scrollbar
  - 存在 Cue 时持续可见
  - 完整 Cue 集合可用前可以显示为不可交互状态
  - Position 映射到 Fractional Cue Ordinal
  - 长 Cue 和短 Cue 占用相同的 Ordinal 比例
  - Drag 时在相邻 Cue Placement 之间连续预览
  - Release 时选择最近的稳定 Cue
  - Thumb 不短于 `--scrollbar-min-thumb-length`

- 打开：
  - Playback Page 活跃时按 Enter
  - 立即暂停 Playback
  - 初始 Cue 准备期间保留暂停的视频画面
  - 不显示 Loading Spinner 或 Progress Bar
  - 初始 Cue 准备完成后显示 Overlay

- Default Cue：
  - Timestamp 位于 Cue Group 内时，选择该组稳定显示顺序中物理位置最靠下的 Cue
  - Timestamp 不位于 Cue 内时，选择最近的 Previous Cue
  - 没有 Previous Cue 时选择第一个 Cue

- Cue Navigation：
  - Up 选择 Previous Cue
  - Down 选择 Next Cue
  - 到达边界时无动作
  - Discrete Wheel 在允许方向上至少移动一个 Cue
  - Precise Scroll 和 Momentum 在相邻 Placement 之间连续移动
  - Scroll 结束后 Fit Cue Center 回到 Focus Anchor
  - Scroll 结束后 Oversized Cue 回到 Top Placement
  - Wheel、Trackpad 和 Scrollbar Navigation 不执行 Seek

- Cue Pointer：
  - Cue 不显示 Hover
  - Cue 不响应左键动作
  - 点击不改变 Selected Cue
  - 点击不打开 Menu
  - 点击不穿透到底层 Video
  - Wheel 和 Scrollbar 仍可使用
  - Cursor 使用 `default`

- Keyboard Actions：
  - 所有动作以已经 Settled 的 Selected Cue 为目标
  - Cue 正在移动时接受的动作，在当前目标 Settled 后执行一次

- `S`：
  - 保存 Selected Cue
  - 已保存时不删除、不重复创建
  - 新保存显示 `Shiori Saved`
  - 已存在显示 `Shiori Already Saved`
  - Overlay 保持显示
  - Playback 保持暂停
  - Cue 位置不变

- `C`：
  - 复制 Selected Cue 的完整多行文字
  - 保留源行序和换行
  - 显示 `Subtitle Copied`
  - Overlay 保持显示
  - Playback 保持暂停
  - Cue 位置不变

- `Space`：
  - Seek 至 Selected Cue Start Time
  - 关闭 Overlay
  - 从该位置连续播放
  - 显示 `Play`

- `Enter`：
  - 被消费但无动作
  - 不打开 Menu
  - 不关闭 Overlay
  - 不恢复播放
  - 不改变 Selected Cue

- Escape：
  - 关闭 Overlay
  - 恢复打开前的 Playback State
  - 不执行隐式 Seek

- Motion：
  - Duration 使用 `--duration-subtitle-focus-scroll`
  - Easing 使用 `--easing-subtitle-focus-scroll`
  - 动画距离由当前 Cue 和目标 Cue 的 Resolved Height 决定
  - Reduce Motion 下立即到达最终 Placement
  - Reduce Motion 不改变选择、Oversized Cue Placement 或 Scrollbar Drag 语义