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

#### Icon

- `--color-icon-default`: Light `#667085`; Dark `#A1A1AA`
- `--color-icon-muted`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-disabled`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-on-dark`: Light `#FFFFFF`; Dark `#FFFFFF`

#### Background

- `--color-bg-surface`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-hover`: Light `#F3F4F6`; Dark `#27272A`
- `--color-bg-disabled`: Light `#F3F4F6`; Dark `#202024`
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
- `--color-library-cover-crop-accent`: macOS accent color
- `--color-library-cover-crop-mask`: macOS shadow color with Alpha `0.55`
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

- `--color-subtitle-focus-overlay-bg`: Light `#F6F7F9`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `#111827`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-group-selected`: Light `#475467`; Dark `rgba(255,255,255,0.62)`
- `--color-subtitle-focus-cue-unselected`: Light `#858B95`; Dark `rgba(255,255,255,0.34)`
- `--color-playback-information-badge-bg`: Light `#D1D5DB`; Dark `#18181B`
- `--color-playback-information-badge-text`: Light `#1F2937`; Dark `#F4F4F5`
- `--color-playback-information-badge-unselected-bg`: Light `#E5E7EB`; Dark `#303036`
- `--color-playback-information-badge-unselected-text`: Light `#475467`; Dark `#A1A1AA`
- `--color-playback-module-sidebar-selected`: Light `#111827`; Dark `rgba(255,255,255,0.94)`
- `--color-playback-module-sidebar-unselected`: Light `#667085`; Dark `rgba(255,255,255,0.34)`

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
- `--font-size-subtitle-focus-cue`: `24px`
- `--line-height-subtitle-focus-cue`: `32px`
- `--font-weight-subtitle-focus-cue`: `600`
- `--font-size-subtitle-focus-cue-group`: `20px`
- `--line-height-subtitle-focus-cue-group`: `28px`
- `--font-weight-subtitle-focus-cue-group`: `500`
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
- `--height-form-text-area`: `96px`
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
- `--height-playback-cue-information-badge`: `23px`
- `--height-library-progress-bar`: `4px`
- `--height-library-list-cover`: `115px`

#### Size

- `--size-checkbox`: `16px`
- `--size-playback-collage-checkbox`: `24px`
- `--min-width-filter-data-card`: `200px`
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
- `--gap-subtitle-focus-internal-line`: `3px`
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
- `--padding-subtitle-focus-cue-y`: `8px`
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

#### Toast Motion

- `--duration-toast-motion`: `0.20s`
- `--easing-toast-motion`: `cubic-bezier(0.22, 1, 0.36, 1)`

#### Subtitle Focus Motion

- `--duration-subtitle-focus-scroll`: `0.22s`
- `--easing-subtitle-focus-scroll`: `cubic-bezier(0.22, 1, 0.36, 1)`

### 1.7 Icon Assets

#### System Symbols

- Current: `clock`
- Playlist: `list.bullet`
- Search: `magnifyingglass`
- Inline Clear: `xmark`, bold
- Filter: `line.3.horizontal.decrease`
- Filter Data Card Duration: `clock`
- Filter Data Card Character: `textformat`
- Filter Data Card Language: `globe`
- Filter Data Card Watch Status: `eye`
- Filter Data Card Option Unchecked: `circle`
- Filter Data Card Option Checked: `checkmark.circle.fill`
- Select Indicator: `chevrons-up-down`
- Sort Unsorted: `chevrons-up-down`
- Sort Ascending: `arrow-up`
- Sort Descending: `arrow-down`
- Inline Add: `plus`, medium
- Row Action: `ellipsis`
- Play: `play.fill`
- Copy Cue Text、Copy Cue Group Text、Copy Time Range、Copy Table、Copy Deep Link(s): `doc.on.doc`
- Deep Link、Copy Deep Link: `link`
- Context: `doc.text`
- Folder: `folder`
- Edit: `square.and.pencil`
- Delete: `trash`
- Move: `arrow.right`
- Duplicate: `copy`
- Action Submenu: `chevron.right`
- Hide Column: `eye-off`
- Cue Content Changed: `clock.arrow.circlepath`
- Cue Unavailable: `questionmark.circle`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
- Settings: `gearshape`
- App Sidebar Toggle: macOS native sidebar toggle symbol

#### Custom Assets

- Recent、Library 和 Shiori Sidebar 图标沿用当前项目资源。
- Shiori List 默认封面中央复用现有 Shiori 图形。
- Component 和 Layout 的参考图片应在所属条目中直接引用，不建立重复的全局说明。

## 2. 全局交互规则

### 2.1 状态集合

- 组件只定义实际存在差异的状态。
- 常用状态包括 Default、Hover、Pressed、Focused、Selected、Checked、Indeterminate、Menu Open、Highlighted、Error、Disabled。
- Hover 和 Pressed 只作用于实际交互目标，不自动扩散到父容器。
- Table Row 是显式例外，其整行 Hover 和 Selected 视觉由 Table Row Component 定义。
- 普通文字、图标和装饰元素不能表现为没有对应动作的控件。
- Selected 只表达持续生效的选择状态，不用于短暂 Hover。
- Menu Open 可以复用所属 Trigger 的 Hover 视觉。

### 2.2 Disabled 与 Read-only

- Disabled 不响应点击、Hover 或键盘操作，也不进入键盘焦点顺序。
- Disabled 控件使用对应的 disabled Token。
- Read-only 内容不可编辑，但仍可按所属界面规则选择和复制。
- Read-only 不显示 caret，也不使用 `not-allowed` Cursor。

### 2.3 Focus 与键盘导航

- 键盘焦点必须可见。
- 有边框控件使用 `--color-border-focus` 和 `--color-focus-ring`。
- 无边框控件使用 `--color-focus-ring`、`--focus-ring-width` 和 `--focus-ring-offset`。
- Search Box、Form Text Field 和 Form Text Area 通过点击或键盘获得焦点时都显示 Focused 状态。
- Form Text Field 和 Form Text Area 处于 Error 时保留错误边框；获得焦点时同时显示 Focus Ring。
- Command Panel Search Box 获得输入焦点时不显示额外 Focus Ring、边框色或背景变化，只显示 Caret。
- Caret 只在可编辑输入区域获得焦点时出现。
- Checkbox 的焦点只作用于 Checkbox 本体。
- Sortable Header Cell 的焦点只作用于 Trigger Surface。
- 菜单中的键盘当前项使用 Highlighted 背景，不额外绘制蓝色 Focus Ring。
- Escape 关闭当前最上层的 Menu、Popover 或 Dialog。
- 一个键盘事件只能执行一个明确动作，不能同时作用于上下两层界面。

### 2.4 Pointer、点击区域与 Cursor

- 可编辑输入框和没有左键动作的普通可选择文字使用 `text`。
- Cue 的直接点击区域、按钮、菜单项使用 `pointer`。
- 静态区域使用 `default`。
- Disabled 控件使用 `not-allowed`。
- Cursor 必须与实际点击区域一致。
- 没有动作的普通空白区域不得使用 `pointer`。
- Pointer 命中子控件时，不得同时触发父容器动作。

### 2.5 文字选择与复制

- 普通模式下，表格中的所有文字均可选择，包括表头、Display Title、Cues、Language Tags、Time Range 和 Date Added。
- 普通模式下支持在单元格、列和行之间连续拖拽选择。
- Select 状态下禁用表格文字选择，不建立或扩展文字选区。
- 拖拽到可视区域顶部或底部时，表格自动滚动并继续扩展选择。
- 固定表头不随正文滚动，但仍参与文字选择和复制。
- 表格拥有键盘上下文时，`Cmd+A` 选择当前完整结果中的全部表格文字。
- `Cmd+A` 的范围包含表头、当前显示的列和全部结果行，不受当前滚动位置影响。
- 输入框拥有焦点时，`Cmd+A` 只选择该输入框的文字。
- `Cmd+C` 复制当前文字选择。
- 结构化复制时，列之间使用 Tab，表格行之间使用换行。
- 多行 Cue 在粘贴到电子表格后仍属于一个单元格。
- 文字选择不改变 Checkbox 批量选择状态。
- 文字拖拽优先于 Cue 的单击；发生拖拽后不得执行播放。
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
- 内容：Search 图标、输入文字、Placeholder、可选 Result Count Text、Inline Clear Button。
- 文字使用 `--font-family-base`、`--font-size-control`、`--color-text-primary`、`--color-text-placeholder`。
- Result Count Text 使用 `--font-size-control` 和 `--color-text-muted`，位于 Inline Clear Button 左侧。
- Search 只有 exact 结果和当前 Filter Data Panel 的筛选投影完整计算完成后才显示 Result Count Text。
- Shiori 只有当前 Query 和 Filter Data Panel 的筛选投影完整计算完成后才显示 Result Count Text。
- Result Count Text 使用 `1 result` 和 `{N} results`，显示 Search 或当前 Shiori List 经过 Filter Data Panel 筛选后的结果数量。
- 状态：Empty、Focused Empty、Typing / Focused Filled、Filled、Clear Button Hover、Disabled。
- 只有 Focused 或 Typing 状态显示 caret。
- 有内容时显示 Inline Clear Button。
- 输入区支持原生文字选择、`Cmd+A`、`Cmd+C`。

#### Command Panel Search Box

- 用途：在 Playback Command Panel 一级界面中输入查询词。
- 复用 Search Box 的高度、圆角、水平内边距、文字、Placeholder、Search 图标和 Inline Clear Button。
- 跟随 CueSeeker 当前有效 Appearance。
- Light Appearance 使用 Light Token；Dark Appearance 使用 Dark Token。
- 状态：Empty、Typing、Filled、Clear Button Hover。
- Command Panel 打开后默认获得输入焦点并显示 Caret。
- Empty、Typing 和 Filled 的容器外观保持一致。
- 获得输入焦点时不增加额外 Focus Ring、焦点边框或焦点背景。
- 有内容时显示 Inline Clear Button。
- 点击 Inline Clear Button 清除查询词并更新一级选项。
- 输入区支持原生文字选择、`Cmd+A`、`Cmd+C`。
- 输入焦点存在时，无修饰字母键优先作为查询输入。
- 进入任一二级界面后隐藏 Command Panel Search Box。

#### Select Trigger Button

- 用途：打开 View 等选择型菜单。
- Token：`--height-filter-bar-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-focus`、`--color-border-disabled`。
- 内容：可选 Leading Icon、Label、Select Indicator。
- Select Indicator 固定使用 `chevrons-up-down`。
- Indicator 使用 `--size-select-indicator`、`--weight-select-indicator`，与文字间距使用 `--spacing-2`。
- 状态：Default、Hover、Menu Open、Disabled。
- Menu Open 时不把 Indicator 替换成单个 chevron。

#### Form Text Field

- 用途：输入名称等单行表单内容。
- Token：`--height-field`、`--radius-field`、`--padding-field-x`、`--color-bg-surface`、`--color-bg-disabled`、`--color-border-control`、`--color-border-focus`、`--color-border-disabled`、`--color-focus-ring`。
- 从上到下包括：
  1. Label
  2. 可选 Validation Message
  3. 单行 Input
- Label 持续显示，不使用 Placeholder 代替 Label。
- Validation Message 使用 `--font-size-caption` 和 `--color-danger-text`。
- Error 状态的边框使用 `--color-danger-text`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--color-text-primary`、`--color-text-placeholder`、`--color-text-disabled`。
- 状态：Empty、Focused Empty、Typing、Filled、Error、Focused Error、Disabled。
- Input 支持原生文字选择、`Cmd+A`、`Cmd+C` 和 `Cmd+V`。

#### Form Text Area

- 用途：输入描述等多行表单内容。
- 结构、Label、Validation Message、文字和 Error 视觉与 Form Text Field 相同。
- 高度使用 `--height-form-text-area`。
- 使用多行输入，`Enter` 插入换行。
- 内容超过可视高度后启用纵向滚动。
- 不提供用户拖拽缩放。
- 状态：Empty、Focused Empty、Typing、Filled、Error、Focused Error、Disabled。
- Text Area 支持原生文字选择、`Cmd+A`、`Cmd+C` 和 `Cmd+V`。

#### Filter Data Card

- 用途：显示一类筛选条件、各选项的分布数量和当前选择状态。
- Filter Data Card 是 Search 与 Shiori 共用的 Component，不绑定固定的数据卡片数量或页面位置。
- Card 使用 `--color-bg-surface`、`--color-border-control`、`--radius-control` 和 `--spacing-3`。
- Card Border 为 `1px`。
- Card 内容纵向排列，内部间距使用 `--spacing-2`。
- Card Title Row 由 Title Icon 和 Title 组成，两者间距使用 `--spacing-2`。
- Card Title Icon 使用 `--size-checkbox` 和 `--color-text-secondary`。
- Card Title 使用 `--font-size-control`、Font Weight `600` 和 `--color-text-secondary`。
- Card Title Row 底部额外使用 `--spacing-1`。
- Option Row 由 Checkbox、Option Label 和 Option Count 组成。
- Checkbox 与 Option Label 的间距使用 `--spacing-2`。
- Option Label 使用 `--font-size-body` 和 `--color-text-muted`。
- Option Count 使用 `--font-size-caption` 和 `--color-text-muted`，在 Card 尾部右对齐。
- Card Title Icon 与 Option Checkbox 占用相同宽度的 Leading Control Column，并保持水平中心线一致。
- Card Title 与 Option Label 从 Leading Control Column 后的同一水平位置开始。
- Unchecked Checkbox 使用 `circle`、`--size-checkbox`、`--color-bg-checkbox-unchecked` 和 `--color-border-checkbox`。
- Checked Checkbox 使用 `checkmark.circle.fill` 和 `--size-checkbox`；背景使用 `--color-text-muted`，Checkmark 使用 `--color-checkbox-icon`。
- 整个 Option Row 都是 Checkbox 的点击区域。
- 点击 Option Row 只切换 Checked 状态，不显示额外 Hover、Pressed、Click 动画或背景。
- 状态：Default、Calculating、Disabled。
- Calculating 状态下，Option Count 显示 `Calculating`；全部 Option 禁止交互，但保持原有 Checked 或 Unchecked 视觉，不使用 Disabled Token。
- Disabled 状态下，Card Title Icon 和全部 Checkbox 使用 `--color-icon-disabled`，Card Title、Option Label 和 Option Count 使用 `--color-text-disabled`。
- Disabled 状态不改变 Card Surface 和 Border。

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

#### Filter Button

- 用途：在 Search 或 Shiori 中显示或隐藏当前 Filter Data Panel。
- Token：`--height-filter-bar-control`、`--radius-control`、`--padding-control-x`、`--spacing-2`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-disabled`。
- 内容顺序：Filter Icon、`Filter`、Select Indicator。
- Filter Icon、文字和 Select Indicator 使用普通中性按钮颜色，不使用 Active Accent 颜色。
- 不显示数字或 Filter Count Badge。
- Filter Data Panel 可见时，Filter Button 进入 Open 状态并复用 Hover 视觉。
- Disabled 使用 `--color-bg-disabled`、`--color-border-disabled`、`--color-text-disabled` 和 `--color-icon-disabled`。
- 状态：Default、Hover / Open、Disabled。
- 不显示 Trailing Clear。

#### Neutral Button

- 用途：执行保存、取消、导出等普通命令。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-bg-surface`、`--color-bg-hover`、`--color-bg-disabled`、`--color-border-control`、`--color-border-control-hover`、`--color-border-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`、`--color-text-primary`。
- Leading Icon 可选，图文间距使用 `--spacing-2`。
- 状态：Default、Hover、Disabled。

#### Primary Button

- 用途：执行当前界面的主要确认操作。
- Token：`--height-control`、`--radius-control`、`--padding-control-x`、`--color-primary-button-bg`、`--color-primary-button-bg-hover`、`--color-primary-button-text`、`--color-bg-disabled`、`--color-text-disabled`。
- 文字使用 `--font-family-base`、`--font-size-control`、`--font-weight-control`。
- 状态：Default、Hover、Disabled。

#### Inline Add Button

- 用途：添加列表或其他内联项目。
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

#### Action Submenu

- 用途：从 Action Menu Item 打开关联的二级命令列表。
- Parent Item 使用 Action Menu Item，Trailing Slot 固定显示 `chevron.right`。
- Submenu 复用所属 Menu 的背景、边框、圆角、阴影和 Action Menu Item。
- Submenu 紧邻 Parent Menu 右侧显示，并限制在当前可见区域内。
- 通过以下方式打开：
  - Hover Parent Item，并经过 macOS 原生菜单延迟
  - 点击 Parent Item
  - Parent Item 处于 Highlighted 时按 Right Arrow
- 从 Parent Item 移向 Submenu 的路径属于同一交互区域，不因跨越菜单边缘立即关闭。
- Hover Parent Menu 的其他 Item 时关闭当前 Submenu，并正常更新 Parent Menu 的 Highlighted Item。
- 点击 Parent Menu 的其他 Item 时关闭 Submenu，并执行被点击的命令。
- 点击 Parent Menu 和 Submenu 以外区域时同时关闭两级 Menu。
- Left Arrow 关闭 Submenu 并将键盘当前项返回 Parent Item。
- Escape 关闭两级 Menu。
- 点击 Submenu Item 后执行该命令并关闭两级 Menu。
- Disabled Parent Item 不打开 Submenu。

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
- 所有 Library Card Context Menu 均包含 `Change Cover`。
- `Change Cover` 位于 `Open Folder` 下方，Leading Icon 使用上箭头托盘图标。
- `Change Cover` 打开 Finder；选择图片后打开 Edit Cover Dialog。
- Workbench 中的其他 Menu Item 由所属 Card Layout 定义。
- Playback 复用所属 Card Layout 定义的 Menu Item 和动作，但不显示 `Context` Menu Item。
- Playback 中打开 Menu 后，锁定右键所在卡片为动作目标，直到 Menu 关闭。
- 菜单锚定右键位置并限制在可见区域内。
- 点击菜单外关闭。
- 不显示系统 Popover Arrow。

#### Shiori List Card Context Menu

- 用途：显示 Shiori List Card 的列表级操作。
- Menu 视觉和定位规则复用 Library Card Context Menu。
- 在完整 Shiori List Card 区域右键触发。
- Action 顺序：
  1. `Edit List`
  2. `Delete List`
- `Edit List` 使用 Edit Icon，打开 Shiori List Editor Dialog 的 Edit 模式。
- `Delete List` 使用 Delete Icon，打开 Delete List Confirmation Dialog。
- `Delete List` 不使用特殊的 Menu Item 样式。
- 当前只有一个 Shiori List 时，`Delete List` 为 Disabled。
- 打开 Menu 后锁定右键所在卡片为 Command Target，直到 Menu 关闭。

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
- Table Row 必须在当前可见列的最终列宽确定后计算内容布局和行高。
- Display Title、Cues、Time Range 和 Date Added 按各自最终列宽自动换行，并显示完整内容。
- Language Tags 按最终列宽使用水平换行布局，并形成完整内容块。
- 设本行显示的 Cue Item 数量为 `N`，每个 Cue Item 的自然高度为 `Hᵢ`：

  `Cue Block Height = ΣHᵢ + (N - 1) × --padding-table-row-y`

- 最终行高：

  `Row Height = max(--min-height-table-row, max(All Visible Column Content Block Heights) + 2 × --padding-table-row-y)`

- Table Viewport Width 或可见列发生变化时，按照新的最终列宽重新计算换行和行高。
- 行高更新时保留当前滚动锚点，不改变当前行或 Primary Cue 身份，不产生可见位置跳动。
- 所有列的完整内容块在行内垂直居中。
- Metadata 不再对齐 Primary Cue 第一视觉行。
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Display Title、Language Tag 文字、Time Range 和 Date Added 使用 `--color-text-muted`。
- Normal 和 Content Changed Shiori Row 的 Primary Cue 使用 `--color-text-secondary`，其它文字内容使用 `--color-text-muted`。
- Unavailable Shiori Row 的 Display Title、Primary Cue、Extra Cues、Time Range 和 Date Added 统一使用 `--color-text-muted`。
- Unavailable 不属于 Disabled，不使用 `--color-bg-disabled`，不增加整行背景或透明度。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
- 所有 Cue 保留源换行和自动换行，不裁剪、不截断、不显示省略号。
- 普通模式下，Row Hover 使用 `--color-row-hover`。
- 普通模式不显示 Full-row Selected 背景。
- Select 状态下，已选择行使用 `--color-row-selected`。
- Select 状态下，Hover 未选择行继续使用 `--color-row-hover`。
- Select 状态下，Hover 已选择行时不叠加 `--color-row-hover`。
- 只显示水平 Divider，不显示垂直列分隔线。
- 普通模式下，左键不选择整行。
- Select 状态下，点击行内任意非 Overlay、非 Scrollbar 区域切换该行的选择状态。
- 普通模式下，行级右键交互使用 Row Action Menu。
- Select 状态下，禁用 Row Action Menu。

#### Sortable Header Cell

- 用途：显示列名、当前排序方向并打开 Column Header Menu。
- Token：`--height-table-header`、`--padding-header-trigger-x`、`--color-bg-hover`、`--font-size-table-header`、`--color-text-secondary`、`--color-icon-default`。
- 排序状态：Unsorted、Sorted Asc、Sorted Desc。
- Indicator 分别为 `chevrons-up-down`、`arrow-up`、`arrow-down`。
- 交互状态：Default、Hover、Menu Open、Disabled / Not Sortable。
- Hover、Focus 和 Menu Open 只作用于 Trigger Surface。
- 不绘制垂直 Divider 或 Boxed Cell。
- Header 文字可以拖拽选择。
- 普通单击执行排序；发生文字拖拽时不执行排序。

#### Row Selection Checkbox

- 用途：在 Select 状态下明确控制单行或整个结果范围的批量选择。
- Token：`--size-checkbox`、`--radius-checkbox`、`--color-border-checkbox`、`--color-border-focus`、`--color-bg-checkbox-unchecked`、`--color-bg-checkbox-checked`、`--color-checkbox-icon`。
- 只在 Select 状态下显示。
- 非 Select 状态下，相同列宽位置显示动态序号。
- 行状态：Unchecked、Checked、Disabled。
- Header 状态：Unchecked、Checked、Indeterminate、Disabled。
- Header Checkbox 不排序，也不打开 Column Header Menu。
- `Cmd+A` 不改变 Checkbox 状态。

#### Interactive Text Cell

- 用途：为可播放 Cue 文字提供文字选择和表格正文中唯一的普通文字左键动作。
- Token：`--color-text-primary`、`--padding-table-cell-hover-x`、`--padding-table-cell-hover-y`、`--width-interactive-text-underline`、`--offset-interactive-text-underline`。
- 下划线使用当前文字色。
- Normal 和 Content Changed Cue 使用完整 Interactive Text Cell 交互。
- Hover Region 覆盖当前完整显示的 Cue 内容，但不包含 Cue State Indicator。
- Show Cue Group 开启时，所有显示的 Cue 共用一个 Hover Region。
- Hover 不绘制独立背景。
- Hover 时 Primary Cue 使用 `--color-text-primary`，所有显示的 Cue 文字使用当前文字色显示下划线。
- 无拖拽的普通单击从 Primary Cue 播放。
- 从 Cue 文字开始拖拽时进入文字选择并抑制播放。
- Unavailable Cue 不显示 Hover 下划线，不响应普通左键播放，也不使用 `pointer` Cursor。
- Unavailable Cue 文字仍然允许选择和复制。
- Cue State Indicator 是独立 Hover Target，不属于 Interactive Text Cell。
- Display Title、Language Tags 中的文字、Time Range 和 Date Added 不使用 Interactive Text Cell。
- 右键交给所属行的 Row Action Menu。

#### Table Scrollbar

- 用途：控制表格水平或垂直滚动位置。
- Token：`--scrollbar-size`、`--scrollbar-radius`、`--scrollbar-min-thumb-length`。
- Thumb 使用 `--color-scrollbar-thumb-default` 和 `--color-scrollbar-thumb-interactive`。
- Track 使用 `--color-scrollbar-track`。
- 状态：Vertical Default、Vertical Hover / Dragging、Horizontal Default、Horizontal Hover / Dragging。
- 只显示 Thumb，不显示箭头按钮。
- Track 保持透明。

#### Selection Action Overlay

- 用途：在 Select 状态下显示已选择数量和批量操作。
- Token：`--spacing-2`、`--spacing-3`、`--radius-control`、`--color-bg-popover`、`--color-border-muted`、`--shadow-popover`、`--font-size-control`、`--color-text-muted`。
- 背景必须完全不透明。
- 内容顺序：`{N} selected`、Anki、Copy Deep Link(s)、Copy Table。
- `{N} selected` 只读，其余项目复用现有操作按钮。
- Selected Count 大于 `0` 时显示；清空选择后隐藏。

### 3.5 展示与状态

#### Cue State Indicator

- 用途：在 Workbench Shiori Table 中显示被持久引用 Cue 的当前状态。
- 状态：Content Changed、Unavailable。
- Content Changed 使用 Cue Content Changed Icon。
- Unavailable 使用 Cue Unavailable Icon。
- Normal 不显示 Cue State Indicator。
- Icon 使用 `--size-control-icon` 和 `--color-icon-muted`。
- Indicator 使用透明背景和无边框外观，不响应普通左键动作。
- Indicator 不属于 Cue 文字选择和复制内容。
- Pointer Hover Indicator 时显示 Cue State Tip。
- Pointer 离开 Indicator 时关闭 Cue State Tip。
- 右键 Indicator 时继续打开所属 Table Row 的 Row Action Menu。

#### Cue State Tip

- 用途：解释 Content Changed 或 Unavailable 的具体状态。
- 背景、边框、圆角和阴影使用 `--color-bg-popover`、`--color-border-muted`、`--radius-control` 和 `--shadow-popover`。
- Tip 固定锚定 Cue State Indicator。
- 默认显示在 Indicator 右侧。
- 右侧可见区域不足以完整显示 Tip 时，改为显示在 Indicator 左侧。
- Tip 与 Indicator 垂直居中。
- Tip 与 Indicator 的间距使用 `--spacing-2`。
- Title 使用 `--color-text-primary` 和 semibold。
- `Previous`、`Current` Label 使用 `--color-text-muted`。
- Message、Previous Value、Current Value 和 Unavailable Reason 使用 `--color-text-secondary`。
- Tip 内文字允许自然换行。

- Content Changed：
  - Title：`Content Changed`
  - Message：`This cue changed after reindexing.`
  - 按顺序显示 `Previous`、Previous Value、`Current`、Current Value
  - Previous Value 显示上一次成功索引保存的文字
  - Current Value 显示当前文字

- Unavailable：
  - Title：`Unavailable`
  - 根据当前不可用层级显示一条明确的 Reason
  - Library Source 暂时无法访问：`The library source is currently unavailable.`
  - 视频缺失但字幕仍可访问：`The video file is missing. The subtitle file is still available.`
  - 视频仍在但字幕缺失或无法重新关联：`The subtitle file is missing or could not be reconnected.`
  - 视频和字幕均缺失：`The video and subtitle files are missing.`
  - 文件仍在但 Cue 已删除或无法确认继承：`This cue could not be found in the current subtitle file.`

#### Chip / Tag

- 用途：只读显示 Language。
- Token：`--radius-chip`、`--padding-chip-x`、`--padding-chip-y`、`--font-family-base`、`--font-size-caption`。
- Language 使用 `--color-chip-language-bg`、`--color-chip-language-text`。
- Disabled 使用 `--color-bg-disabled`、`--color-text-disabled`。
- Table 内的 Language Tag 文字可以拖拽选择。
- Language Tag 不单独定义表格中的左键或右键动作。

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

#### Toast

- 用途：显示不要求用户立即操作的短暂反馈。
- 默认位置为 App Center。
- 默认持续时间为 `5s`。
- 文案、位置、持续时间和动画可以由 `Toast Usage Registry` 中的调用场景覆盖。
- 内容只包括文字，不显示图标、关闭按钮、进度条或 Action。
- 使用 `--font-family-base`、`--font-size-body`、`--color-text-primary`。
- 背景、边框、圆角和阴影使用 `--color-bg-popover`、`--color-border-muted`、`--radius-control` 和 `--shadow-popover`。
- 垂直内边距使用 `--spacing-3`，水平内边距使用 `--spacing-4`。
- 宽度随内容变化，但不得超出 App 可见区域；左右至少保留 `--spacing-6`。
- 文字自然换行，不限制行数。
- Toast 不获取键盘焦点，不响应点击关闭。
- Hover Toast 时只暂停该 Toast 的计时，移开后继续剩余时间。
- App 失去激活状态时暂停全部 Toast 计时，重新激活后继续。
- 每次调用产生独立 Toast，不根据相同文案或 Scenario ID 自动去重。
- Toast 使用无障碍通知语义，但不移动当前键盘焦点。

- Default Animation：
  - Enter：Opacity 从 `0` 变为 `1`，同时从下方 `--spacing-2` 移动到最终位置
  - Exit：Opacity 从 `1` 变为 `0`，同时向上移动 `--spacing-2`
  - Stack Reflow：剩余 Toast 平滑移动到新位置
  - Enter、Exit 和 Stack Reflow 使用 `--duration-toast-motion` 与 `--easing-toast-motion`

- App Center Stack：
  - 同一时间最多显示 `4` 个 Toast
  - Toast 间距使用 `--spacing-4`
  - 最新 Toast 位于 Stack 最下方，并占据 App Center 锚点
  - 更早的 Toast 依次向上排列
  - 新 Toast 不替换已有 Toast
  - 超过 `4` 个时进入 FIFO Queue
  - Queue 中的 Toast 在出现可用位置后按产生顺序显示
  - Toast 的持续时间从进入可见 Stack 时开始计算
  - Toast 消失后，剩余 Toast 使用 Default Animation 补位

### 3.6 Library Media

#### Library Cover

- 用途：显示视频、文件夹或 Shiori List 封面。
- Token：`--aspect-library-cover`、`--radius-library-cover`、`--color-library-cover-placeholder-bg`。
- 状态：No Cover、Shiori Default、Loaded。
- 图片填满容器并保持比例裁切。
- Shiori Default 使用 Library Cover Placeholder 背景，并在中央显示现有 Shiori 图形。
- 本组件不定义点击动作，交互由所属卡片或编辑界面决定。

#### Library Cover Crop Editor

- 用途：调整图片的封面裁剪区域。
- Token：`--aspect-library-cover`、`--color-library-cover-crop-accent`、`--color-library-cover-crop-mask`、`--color-bg-surface`。
- 裁剪区域固定使用 `--aspect-library-cover`。
- 初始裁剪框为图片范围内最大的 `--aspect-library-cover` 区域。
- 裁剪框仅显示四个角柄，角柄视觉中心与裁剪框顶点重合并完整显示；拖动任一角柄时保持固定比例。
- 裁剪框边框和四个角柄边框使用 `--color-library-cover-crop-accent`。
- 四个角柄内部使用 `--color-bg-surface`。
- 拖动裁剪框内部移动完整裁剪区域。
- 裁剪框不得超出图片范围，并具有最小尺寸。
- 裁剪框外的图片区域使用 `--color-library-cover-crop-mask`。
- 移动或缩放裁剪框时，遮罩随当前裁剪区域同步更新；裁剪框内部不显示遮罩。

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

- 用途：承载 Search、Recent、Library 和 Shiori 一级导航。
- Token：`--height-app-sidebar-item`、`--radius-app-sidebar-item`、`--padding-app-sidebar-item-x`、`--color-app-sidebar-item-selected-bg`、`--spacing-3`。
- 文字使用 `--font-family-base`、`--font-size-app-sidebar-item`、`--color-text-primary`、`--color-text-disabled`。
- 图标使用 `--size-app-sidebar-item-icon`、`--color-icon-default`、`--color-icon-disabled`。
- Recent 和 Shiori 显示 Disclosure Indicator。
- Search 和 Library 不显示 Disclosure Indicator。
- 状态：Default、Selected、Expanded、Collapsed、Disabled。
- 点击 Label 或 Leading Icon 进入对应一级页面。
- 点击 Disclosure Indicator 只展开或收起二级导航，不执行页面导航。
- 点击当前 Selected Item 不重复导航。

#### App Sidebar Child Item

- 用途：承载 Recent Videos、Recent Shioris 和具体 Shiori List。
- 文字和高度复用 App Sidebar Navigation Item。
- 不显示 Leading Icon。
- 使用缩进表达与所属一级 Item 的层级关系。
- 状态：Default、Selected、Disabled。
- 同一时刻只有当前页面入口处于 Selected。
- 点击当前 Selected Item 不重复导航。

#### App Sidebar Settings Item

- 用途：打开 Settings。
- Token 与 App Sidebar Navigation Item 相同。
- 图标固定使用 `gearshape`。
- Label 固定为 `Settings`。
- 状态：Default、Disabled。
- 它是独立命令，不参与主要导航项的 Selected 状态。

#### Playback View Tab

- 用途：在 Playback Overlay 的 Current 和 Playlist 之间切换。
- Label 固定为 `Current` 或 `Playlist`。
- 文字使用 `--font-family-base` 和 `--font-size-app-sidebar-item`。
- 状态仅包括 Unselected 和 Selected。
- Selected 使用 Primary 文字颜色，并在文字下方显示短 Accent 下划线。
- Unselected 使用 Muted 文字颜色。
- 背景始终透明。
- 不显示选中背景、边框或 Focus Ring。
- 同一时刻只有一个 Playback View Tab 处于 Selected。
- 点击 Unselected Tab 切换对应视图。
- 点击当前 Selected Tab 不重复切换。

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

### 3.9 Playback Overlay

#### Subtitle Focus Cue

- 用途：在 Current 中显示一个完整 Cue，并表达当前键盘动作目标。
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`、`--gap-subtitle-focus-internal-line`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- 将源换行和自动换行展开为一个按显示顺序排列的 Visual Line Stack。
- 每个 Visual Line 的 typographic bounds 使用实际解析后的 Font Runs 的 Ascender 和 Descender 计算，不使用随具体字形变化的 Ink Bounds。
- 从第二个 Visual Line 开始，按下式排列：
  `Next Visual Line Top = Previous Visual Line Bottom + --gap-subtitle-focus-internal-line`
- 不将每个 Visual Line 分别居中到固定 Line Slot。
- Resolved Content Height：
  `max(Visual Line Count × --line-height-subtitle-focus-cue, Visual Line Stack Height)`
- Visual Line Stack 在 Resolved Content Region 内整体垂直居中。
- Natural Height：
  `Resolved Content Height + 2 × --padding-subtitle-focus-cue-y`
- Resolved Height 不超过 Cue Reel Viewport Height。
- Oversized Cue 从第一视觉行开始显示，只裁掉底部超出内容。
- 不显示省略号。
- 完整 Cue 原文继续作为 S、X、C 和 Enter 的动作值。
- Cue 本身没有 Hover 或点击动作。
- 点击不得改变选择，也不得穿透到底层 Video。
- Wheel Event 交给所属 Cue Reel。

#### Playback Cue Information Badge

- 用途：在 Current、字幕型 Playlist 和 Command Panel Search Result 的每个 Cue 上方显示识别信息。
- Token：`--height-playback-cue-information-badge`、`--spacing-2`、`--padding-chip-x`、`--padding-chip-y`、`--radius-chip`、`--font-size-caption`、`--color-playback-information-badge-bg`、`--color-playback-information-badge-text`、`--color-playback-information-badge-unselected-bg`、`--color-playback-information-badge-unselected-text`。
- 每项信息使用一个独立 Badge，并按所属 Module 定义的顺序水平排列。
- Badge 高度固定使用 `--height-playback-cue-information-badge`，不根据文字、字幕内容或选择状态临时计算。
- Badge 之间使用 `--spacing-2`。
- Badge 与下方 Primary Cue 之间使用 `--spacing-2`。
- 文字使用 Semibold。
- 全部 Badge 保持在同一行；可用宽度不足时压缩 Badge 宽度并在尾部截断文字。
- Selected 使用 `--color-playback-information-badge-bg` 和 `--color-playback-information-badge-text`。
- Unselected 使用 `--color-playback-information-badge-unselected-bg` 和 `--color-playback-information-badge-unselected-text`。
- Selected 的背景和文字视觉均强于 Unselected。
- 使用 Playback 专用的中性灰色，不复用 Watch Status Badge 或任何 `--color-watch-status-*` Token。
- Selected 和 Unselected 显示相同的 Badge 内容、数量和高度；选择变化只改变配色。

#### Playback Cue Result

- 用途：在字幕型 Playlist 和 Command Panel Search Result 中显示一个 Primary Cue，以及可选的 Cue Group。
- Result 使用 `--padding-subtitle-focus-cue-y`。
- Primary Cue 使用 `--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue` 和 `--font-weight-subtitle-focus-cue`。
- Cue Group 使用 `--font-size-subtitle-focus-cue-group`、`--line-height-subtitle-focus-cue-group` 和 `--font-weight-subtitle-focus-cue-group`。
- Show Cue Group 为 On 时，Primary Cue 位于上方，全部 Additional Cues 位于下方。
- Show Cue Group 为 Off 时，只显示 Primary Cue。
- Primary Cue Identity 不因 Show Cue Group 改变。
- Selected：
  - Primary Cue 使用 `--color-subtitle-focus-cue-selected`
  - Cue Group 使用 `--color-subtitle-focus-cue-group-selected`
  - 所属 Module 提供信息时，在 Primary Cue 上方显示 Playback Cue Information Badge，并使用 Selected Badge 配色
- Unselected：
  - Primary Cue 和 Cue Group 均使用 `--color-subtitle-focus-cue-unselected`
  - 所属 Module 提供信息时，在 Primary Cue 上方显示相同内容和数量的 Playback Cue Information Badge，并使用 Unselected Badge 配色
- 状态仅包括 Unselected 和 Selected。
- 所有 Cue 保留源行序和源换行，并按可用宽度自动换行。
- 将 Primary Cue 和全部 Additional Cues 展开为一个按显示顺序排列的 Visual Line Stack。
- 每个 Visual Line 的 typographic bounds 使用实际解析后的 Font Runs 的 Ascender 和 Descender 计算，不使用随具体字形变化的 Ink Bounds。
- 从第二个 Visual Line 开始，按下式排列：

  `Next Visual Line Top = Previous Visual Line Bottom + --gap-subtitle-focus-internal-line`

- 上述间距同样适用于：
  - 同一个 Cue 的源换行
  - 同一个 Cue 的自动换行
  - Primary Cue 与第一个 Additional Cue 的交界
  - 两个 Additional Cue 的交界
- Cue 边界不增加额外 Padding、Paragraph Spacing 或 Cue Item Gap。
- Nominal Content Height：

  `Primary Visual Line Count × --line-height-subtitle-focus-cue + Cue Group Visual Line Count × --line-height-subtitle-focus-cue-group`

- Resolved Content Height：

  `max(Nominal Content Height, Visual Line Stack Height)`

- Visual Line Stack 在 Resolved Content Region 内整体垂直居中。
- Base Result Natural Height：

  `Resolved Content Height + 2 × --padding-subtitle-focus-cue-y`

- 所属 Module 提供信息时：

  `Result Natural Height = Base Result Natural Height + --height-playback-cue-information-badge + --spacing-2`

- 信息行使用固定高度，不改变 Primary Cue 和 Cue Group 的 Base Result Natural Height。
- Selected 和 Unselected Result 使用相同的 Result Natural Height；选择变化不改变 Reel Geometry。
- 两个独立 Result 之间使用 `--gap-subtitle-focus-cue`。
- 不显示独立 Sequence Number 或序号区域。
- Playback Cue Result 本身不绑定键盘快捷键。
- 所属 Module 提供的字幕动作均以 Primary Cue 为目标。
- 具体快捷键和播放行为由所属 Module Layout 定义。

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
- Navigation Region 从上到下包括：
  1. Search
  2. Recent
     - Recent Videos
     - Recent Shioris
  3. Library
  4. Shiori
     - 当前存在的 Shiori List
- Recent 和 Shiori 支持展开与收起。
- Recent 展开后固定显示 Recent Videos 和 Recent Shioris。
- Shiori 展开后按当前 Shiori List 默认顺序显示 App Sidebar Child Item。
- Shiori List 超出可用高度时，Shiori 二级区域独立纵向滚动。
- Search 和 Library 不显示二级导航。
- 二级导航只显示名称，不显示封面、字幕、Resume 位置或其他富信息。
- Settings Region 包含 App Sidebar Settings Item。
- Expanded 为默认状态，显示图标和 Label。
- Collapsed 隐藏 Sidebar 内容，并从主内容区移除 Sidebar 宽度。
- Sidebar Toggle 在 Collapsed 状态下仍显示。
- 点击 Navigation Item 切换工作台页面。
- 点击 Settings 打开 Settings Window。
- Sidebar Expanded / Collapsed 状态跨 App 启动保留。

#### Settings Deep Link Layout

- Settings Window Sidebar Category Label 固定为 `Deep Link`，Leading Icon 使用 `link`。
- 选中后 Page Title 固定为 `Deep Link`。
- Page Description 固定为 `Choose how CueSeeker handles Deep Links.`。
- 不显示 `URL Scheme` 用户可见文字。
- 设置项 `Play First Search Result` 继续控制 Deep Link 搜索是否自动播放完整搜索第一页中的第一条结果。

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
- 内容从上到下包括：
  1. Cover Region
  2. Folder Name
  3. Meta Row
- Cover Region 包括：
  - Library Cover
  - Library Cover Progress Overlay
  - Library Cover Badge / Time
- Folder Name 使用 `--font-size-library-title`、`--color-text-primary`，单行显示。
- Meta Row 使用水平布局，包括 Episode Label 和 Watch Status Badge。
- Episode Label 与 Watch Status Badge 位于同一行并紧邻排列。
- Episode Label 使用 `--font-size-library-meta`、`--color-text-muted`。
- Watch Status 必须使用 Watch Status Badge，不得降级为普通彩色文字或使用圆点分隔。
- 左键从保存的播放位置打开视频。
- 右键打开 Library Card Context Menu，不触发播放。
- Context Menu 可以包含：
  - Open Folder
  - Mark as Finished
  - Mark as Unwatched
  - Mark as Watching
  - Context
- 文件缺失或 Disabled 时降低透明度并禁用点击。

#### Recent Overview Layout

- App Topbar Title 为 `Recent`。
- 页面从上到下包括：
  1. Recent Videos Section
  2. Recent Shioris Section
- 每个 Section Header 包括：
  - Section Title
  - 完整二级页总数
  - 进入完整二级页的箭头
- Section Title 使用 Primary 文字颜色。
- 总数使用 Secondary 文字颜色。
- 总数表示完整二级页的总数，不表示一级页当前预览数量。
- Section Header 箭头用于进入完整二级页，不承担 Sidebar 展开或收起动作。

#### Recent Videos Section Layout

- Workbench Recent 一级页的 Recent Videos 预览、Workbench Recent Videos 完整二级页和 Command Panel Recent Videos 复用 Recent Watching Card Layout 与同一个自适应卡片 Grid。
- 三个界面均保留 Library Cover Progress Overlay、Library Cover Badge / Time、Episode Label 和 Watch Status Badge。
- Workbench Recent Videos 完整二级页显示全部 Recent Videos，不增加 Search、Filter、Sort 或批量操作。
- Workbench Recent 一级页和完整二级页不建立持久 Selected Card，不支持卡片键盘导航，通过 Pointer 执行卡片操作。
- Command Panel Recent Videos 建立持久 Selected Card；Selected 复用 Recent Watching Card 的 Hover Region 和 Hover 视觉。

#### Recent Shiori Resume Row Layout

- Row 使用水平布局并占满可用内容宽度。
- 左侧显示 Shiori List 的 Library Cover。
- 右侧从上到下显示：
  1. List Name
  2. Description
  3. `Resume {Current Position} / {Total Count}`
  4. 最近播放的字幕文本
- Library Cover 保持 `--aspect-library-cover`，不得拉伸或变形。
- List Name 使用 Primary 文字样式。
- Description 使用 Muted 文字样式。
- Resume 位置使用 Secondary 文字样式。
- 最近播放字幕文本使用 Primary 文字样式。
- Description 为空时保留整体对齐，不增加替代文案。
- Row 之间使用间距或轻量 Divider，不使用独立 Card Border 或 Shadow。

#### Recent Shioris Section Layout

- Workbench Recent 一级页的 Recent Shioris 预览、Workbench Recent Shioris 完整二级页和 Command Panel Recent Shioris 复用同一个 Recent Shiori Resume Row List。
- Workbench Recent Shioris 完整二级页和 Command Panel Recent Shioris 显示全部 Recent Shioris。
- Workbench Recent 一级页和完整二级页不建立持久 Selected Row。
- Command Panel Recent Shioris 建立持久 Selected Row；Selected 复用 Recent Shiori Resume Row 的 Hover Region 和 Hover 视觉。
- Workbench Recent Shioris 完整二级页不显示 Search、Filter、Sort、管理按钮或批量操作。

#### Library / Shiori Overview Layout

- Workbench Library 一级界面和 Workbench Shiori 一级界面复用同一个 Overview Layout。
- 页面从上到下包括：
  1. Summary Row
  2. Adaptive Media Card Grid
- 页面水平和垂直内边距使用 `--spacing-6`。
- Summary Row 与 Media Card Grid 的间距使用 `--spacing-4`。
- Summary Row：
  - 使用水平布局和 `space-between`
  - 高度使用 `--height-control`
  - 子项间距使用 `--spacing-3`
  - 左侧显示当前界面的数据统计
  - 右侧使用 Inline Add Button
- Adaptive Media Card Grid：
  - Card Width 位于 `--width-library-recent-card-min` 和 `--width-library-recent-card-max` 之间
  - Grid 间距使用 `--gap-library-recent-grid`
- Library Folder Card 和 Shiori List Card 复用相同的 Card Width、内容间距、Hover Container、Pressed 动画和 Title 样式。
- Library Folder Card 不显示 Description。
- Shiori List Card 在 Title 下方增加 Description。
- Workbench Library：
  - App Topbar Title 为 `Library`
  - Summary Row 左侧显示 `N Folders · M Videos · K Subtitles`
  - `N Folders` 为当前 Library 一级界面展示的 Folder 数量
  - `M Videos` 和 `K Subtitles` 按这些 Folder 中的 Library Episode 统计
  - 每个 Library Episode 对应一个 Video 和一个 Subtitle
  - Summary Row 右侧 Inline Add Button 的 Label 为 `Add Content`
  - 点击 `Add Content` 打开 Settings，并显示 Library 分类
- Workbench Shiori：
  - App Topbar Title 为 `Shiori`
  - Summary Row 左侧显示 `N Lists · M Cues`
  - Summary Row 右侧 Inline Add Button 的 Label 为 `New List`

#### Library Folder Card Layout

- 是 Library / Shiori Overview Card Structure 的无 Description 变体。
- 卡片为纵向 Media Card。
- 卡片宽度位于 `--width-library-recent-card-min` 和 `--width-library-recent-card-max` 之间。
- 内容间距使用 `--spacing-2`。
- Hover 外围使用 `--padding-library-media-card-hover`。
- Hover 圆角使用 `--radius-library-media-card-hover`。
- Hover 背景使用 `--color-library-media-card-hover-bg`。
- 内容从上到下包括：
  1. Library Cover 和 Library Cover Badge / Count
  2. Folder Name
- 不显示 Description。
- Folder Name 使用 `--font-size-library-title`、`--color-text-primary`，单行显示，溢出显示省略号。
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

- 同时用于 Workbench Library Folder Detail 和 Playback 视频型 Playlist。
- 两个界面复用相同的 Grid、Episode Card、内容排列、数据顺序、Hover Region 和点击区域。
- Workbench 与 Playback 的选择差异遵循 Playback Media Selection，不建立第二套 Episode Card Layout。
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

#### Shiori List Overview Layout

- 完整复用 Library / Shiori Overview Layout。
- App Topbar Title 为 `Shiori`。
- Summary Row：
  - 左侧显示 `N Lists · M Cues`
  - `M Cues` 包含 Normal、Content Changed 和 Unavailable Shiori
  - `M Cues` 按 CueID 去重
  - 右侧使用 Inline Add Button，Label 为 `New List`
  - 点击 `New List` 打开 Shiori List Editor Dialog 的 New 模式
- Shiori List Grid：
  - Shiori List 按创建时间倒序排列
  - 初始 Shiori List 名称为 `Default`
  - 初始 Shiori List 使用 Shiori Default Cover

#### Shiori List Card Layout

- 是 Library / Shiori Overview Card Structure 的 Description 变体。
- 卡片为纵向 Media Card。
- 卡片宽度、内容间距、Hover 外围、Hover 圆角、Hover 背景、Pressed 动画和 Title 样式复用 Library Folder Card Layout。
- 内容从上到下包括：
  1. Library Cover 和 Library Cover Badge / Count
  2. List Name
  3. Description
- Library Cover Badge 位于封面右下角，格式为 `{count} Cues`。
- `{count}` 包含当前 Shiori List 中的 Normal、Content Changed 和 Unavailable Shiori。
- List Name 使用 `--font-size-library-title`、`--color-text-primary`，单行显示，溢出显示省略号。
- Description 使用 `--font-size-library-meta`、`--color-text-muted`，单行显示，溢出显示省略号。
- Description 为空时不显示文字，但保留 Description 行高度。
- 左键点击卡片进入对应 Shiori List Detail。
- 右键打开 Shiori List Card Context Menu，不进入 Shiori List Detail。

#### Shiori List Detail Layout

- App Topbar Title 保持为 `Shiori`。
- 只显示当前 Shiori List 中的 Shiori。
- 完整复用：
  - Search / Shiori Toolbar Layout
  - Filter Data Panel Layout
  - Filter Data Card
  - Selection Action Overlay Layout
  - Search / Shiori / Context Table Layout
- Filter Data Panel 的数据范围限定为当前 Shiori List。
- 本需求不增加当前列表身份 Header。
- 当前列表没有 Shiori 时继续使用现有 Shiori Empty Hint。

#### Search / Shiori Toolbar Layout

- 使用单行水平 Toolbar。
- Toolbar 和其下方内容使用 `--spacing-8` 作为左右页面留白，并保持左右边界对齐。
- 子项垂直居中。
- 间距使用 `--spacing-3`。
- Search Box 为主要 Flexible 区域。
- Filter、View 和 Select / Exit Select 为固定内容宽度。
- 基本顺序：

  `Search Box → Filter → View → Select / Exit Select`

- Select 使用 Edit Icon `square.and.pencil`。
- 进入 Select 状态后，Select 的 Label 改为 `Exit Select`。
- Search 与 Shiori 只有当前 Query 结果和 Filter Data Panel 的筛选投影完整计算完成后 Select 才可用；其余计算阶段为 Disabled。
- Search 与 Shiori 的 Filter Button 均用于显示或隐藏当前 Filter Data Panel。
- Search 与 Shiori 的 Filter Button 均不显示数字或 Filter Count Badge。
- Search 与 Shiori 复用相同的 Search Box、Placeholder 和输入即搜索机制。
- Query 只匹配 Primary Cue，不匹配 Display Title 或 Additional Cues。
- Shiori 的 Query 只筛选当前 Shiori List。
- 输入 Query 后，在最后一次输入变化的 `100ms` 后自动更新结果。
- Query 后续发生变化时，以最新输入内容更新结果。
- Enter 不用于提交 Search。
- View Menu 控制列显示。
- Cues 始终显示，不允许隐藏。
- Result Count Text 只显示在 Search Box 内，不显示独立的结果数量栏或 Shiori 总数量。

#### Filter Data Panel Layout

- Search 与 Shiori 二级页面从上到下排列：
  1. Search / Shiori Toolbar
  2. 可选 Filter Data Panel
  3. Search / Shiori / Context Table
- Toolbar、Filter Data Panel 和 Table Viewport 保持相同左右边界。
- Toolbar、Filter Data Panel 和 Table Viewport 之间使用 `--spacing-3`。
- Filter Data Panel 不绘制独立背景或边框，不设置固定高度，也不使用横向滚动。
- Search 的 Filter Data Panel 默认显示；Shiori 二级页面的 Filter Data Panel 默认隐藏。
- Filter Data Panel 的显示或隐藏状态不持久化。
- 隐藏 Filter Data Panel 不清除 Filter Data Card 的选择，也不改变筛选结果。
- Filter Data Card 的选择状态持久化。
- Search 使用一份独立的持久化选择状态；每个 Shiori List 分别使用自己的持久化选择状态，彼此互不影响。
- 没有已保存状态时，所有 Option 默认不选中。
- Filter Data Card 内部允许单选、多选、全部选中或全部取消，不显示 `All` Option。
- 没有选中任何 Option 与选中全部可用 Option 时，该 Filter Data Card 均不限制结果。
- 勾选一个或多个但未覆盖全部可用 Option 时，该 Filter Data Card 只保留已勾选的分类。
- 同一 Filter Data Card 内的多个 Option 使用 OR；不同 Filter Data Card 之间使用 AND。
- 持久化保存实际 Checked 集合，不在未选中与全部选中之间转换显示状态。
- 当前数据范围中不存在的 Option 不参与筛选；没有已保存状态的新可用 Option 默认不选中。
- 当前内置 Filter Data Card 顺序为：
  1. Duration
  2. Character
  3. Language
  4. Watch Status
- Duration Options：`<1s`、`1–2.999s`、`3–4.999s`、`≥5s`。
- Character Options：`1–10`、`11–20`、`21–30`、`31+`。
- Search 的 Language 显示当前数据库中存在的单个语言以及 `Unknown`。
- Shiori 的 Language 只显示当前 Shiori List 中实际存在的语言；`Unknown` 仅在当前列表存在 Unknown Cue 时显示。
- 多语言 Cue 可以同时计入多个 Language Option，因此 Language Option Count 之和可以大于 Cue 总数。
- Watch Status Options：`Finished`、`Watching`、`Unwatched`。
- Watch Status 直接读取观看状态，不根据观看进度推导。
- Search 的 Option Count 基于当前 Search Term exact 命中的完整结果计算。
- Shiori 的 Option Count 基于当前 Shiori List 的完整结果计算。
- 每张 Filter Data Card 的 Option Count 忽略所属卡片自身的选择，只应用其他 Filter Data Card 的选择；因此不随本卡片的选择变化，但会随其他卡片的选择变化。
- Search Term 为空时，所有 Option Count 固定显示 `0`，且不显示结果表格。
- 输入 Search Term 后到 exact 完成前，Search 的全部 Filter Data Card 进入 Calculating 状态。
- Shiori 当前列表的分布快照尚未完成时，Shiori 的全部 Filter Data Card 进入 Calculating 状态。
- Calculating 状态下全部 Option 禁止交互和修改，但保持原有 Checked 或 Unchecked 视觉，不显示 Disabled 视觉。
- Select 状态下，已显示的全部 Filter Data Card 进入 Disabled 状态。
- Filter Data Panel 使用基于可用宽度的响应式 Grid，不假设 Filter Data Card 数量固定为 `4`。
- Filter Data Card 最小宽度使用 `--min-width-filter-data-card`。
- Grid 的水平和垂直间距使用 `--spacing-3`。
- Grid 最少保持 `2` 列，允许 `3` 列及更多列。
- 同一行使用等宽列；末行不足当前列数时保持相同列宽。
- 同一行 Filter Data Card 使用该行自然内容高度最高 Card 的高度；不同行分别计算高度。

#### Selection Action Overlay Layout

- Overlay 悬浮在表格底部中央，不占用正常文档流空间。
- Overlay 使用完全不透明的 `--color-bg-popover`。
- 边框、圆角和阴影使用 `--color-border-muted`、`--radius-control` 和 `--shadow-popover`。
- 内部间距使用 `--spacing-2` 和 `--spacing-3`。
- Checkbox Selected Count 大于 `0` 时显示。
- 内容顺序：

  `{N} selected → Anki → Copy Deep Link(s) → Copy Table`

- `Copy Deep Link(s)` 使用 `doc.on.doc`。
- 按当前表格顺序复制全部已选行的 Primary Cue Deep Link，每行一个。
- 单条格式与 Row Action Menu 的 `Copy Deep Link` 相同。
- Selection Action Overlay 不显示 Screenshot 或 Collage；Playback 内的 Screenshot 与 Editing Collage 保持不变。

#### Search / Shiori / Context Table Layout

- 适用于 Search、Shiori 和 Search-hosted Context。
- Header 固定，正文独立滚动。
- Header 和正文保持相同水平偏移。
- Table 不绘制外部框线。
- 不显示垂直列分隔线。
- 只显示水平 Row Divider，Divider 长度等于 Table Content Width。
- Header 和正文默认使用 `--color-bg-surface`。
- 不为 Header 增加独立 Tint。
- Header 文字使用 `--color-text-secondary`。

- Search / Context 列顺序：
  1. Selection
  2. Cues
  3. Display Title
  4. Time Range

- Shiori 列顺序：
  1. Selection
  2. Cues
  3. Display Title
  4. Time Range
  5. Date Added

- Selection Column：
  - 非 Select 状态下，Header 显示 `#`，正文显示当前结果列表中从 `1` 开始的动态序号。
  - 序号只反映当前列表中的实际位置，不作为结果数据保存。
  - `#` 使用 `--color-text-secondary`，正文序号使用 `--color-text-muted`。
  - Select 状态下，Header 和正文原位切换为 Checkbox。
  - Selection Column 始终保留固定宽度，不因进入或退出 Select 状态改变其它数据列宽度。
  - Selection Column 不出现在 View Menu 中。

- Select 状态：
  - Search Box 为 Disabled，不允许编辑 Query。
  - Filter 和 View 为 Disabled。
  - Select 保持可用，Label 为 `Exit Select`。
  - Sortable Header Cell 和其它 Header Button 为 Disabled。
  - Header 和正文显示 Row Selection Checkbox。
  - 点击正文行任意非 Overlay、非 Scrollbar 区域切换该行的选择状态。
  - 禁用 Cue 播放。
  - 禁用 Row Action Menu。
  - 禁用 Interactive Text Cell Hover 文字色和下划线。
  - 禁用表格文字选择。
  - 允许滚动表格、拖动 Scrollbar、选择或取消结果、操作 Selection Action Overlay，以及退出 Select 状态。
  - 已选择行使用 `--color-row-selected`。
  - Hover 未选择行使用 `--color-row-hover`。
  - Hover 已选择行时不叠加 Hover 背景。

- Column Width：
  - Selection：`50pt`，固定，不参与权重分配
  - Display Title：权重 `3`，最小 `180pt`
  - Cues：权重 `6`，最小 `240pt`
  - Time Range：权重 `2`，最小 `140pt`
  - Date Added：权重 `2`，最小 `120pt`，仅 Shiori

- Column Width Resolution：
  1. 只有当前可见的数据列参与宽度计算；隐藏列完全退出计算。
  2. 可分配宽度为 Table Viewport Width 减去 Selection Column Width。
  3. 数据列首先按照各自权重计算候选宽度。
  4. 候选宽度小于最小宽度的列固定为最小宽度。
  5. 使用剩余宽度和剩余列权重重新计算，直到所有可见数据列均满足最小宽度。
  6. 当 Table Viewport Width 小于全部可见列的最小宽度总和，Table Content Width 使用最小宽度总和，并启用水平滚动。
  7. Header 和正文使用相同的最终列宽及水平滚动偏移。

- Cues / Primary Cue：
  - 主要内容
  - `--color-text-secondary`
  - Hover 使用 `--color-text-primary`
  - `--font-size-table`
  - `--line-height-table-cue-primary`
  - Font Weight `500`

- Cues / Extra Cues：
  - Show Cue Group 开启时显示
  - 位于 Primary Cue 下方
  - 保持稳定 Source Display Order
  - Cues Cell 的显示、文字选择和结构化复制顺序均为 Primary Cue → Extra Cues
  - `--color-text-muted`
  - `--font-size-caption`
  - `--line-height-table-cue-secondary`
  - Font Weight `400`

- Cues / Cue State Indicator：
  - 仅用于 Shiori
  - Normal 不显示
  - Content Changed 显示 Content Changed Indicator
  - Unavailable 显示 Unavailable Indicator
  - 同时满足 Content Changed 和 Unavailable 时，只显示 Unavailable Indicator
  - Indicator 以内联方式位于 Primary Cue 最后一个可见字符之后
  - Primary Cue 自动换行时，Indicator 跟随最后一条视觉行
  - Indicator 与 Primary Cue 的间距使用 `--spacing-2`
  - Indicator 不创建独立 Status Column

- Display Title：
  - Secondary Context
  - `--color-text-muted`
  - Font Weight `500`

- Time Range 和 Date Added：
  - Metadata
  - `--color-text-muted`
  - Font Weight `500`
  - 使用 `tabular-nums`

- Time Range 格式：

  `hh:mm:ss - hh:mm:ss`

- 当开始和结束的小时均为 `00` 时：

  `mm:ss - mm:ss`

- Time Range 按 Cue Start Time 排序。

- Table Row 的垂直几何遵循 Table Row Component。

- Show Cue Group：
  - 设置位置：Settings / Search
  - Control：macOS native switch
  - Label：`Show Cue Group`
  - Default：Off
  - 跨 App 启动保留
  - 适用于 Workbench Search、Workbench Shiori 和 Context
  - 同一设置同时适用于字幕型 Playlist 和 Command Panel Search Result
  - Workbench Search、Workbench Shiori 和 Context：
    - Off：只显示 Primary Cue
    - On：在 Primary Cue 下方显示全部 Additional Cues
  - 字幕型 Playlist 和 Command Panel Search Result：
    - Off：只显示 Primary Cue
    - On：在 Primary Cue 下方显示全部 Additional Cues
  - Playback Current 始终不显示 Cue Group
  - Primary Cue Identity 不变
  - 所有默认动作继续以 Primary Cue 为目标
  - Workbench Table 中所有显示的 Cue 共用一个 Hover 和点击区域
  - Workbench Table 中 Primary Cue 与 Extra Cues 只通过字体和颜色区分
  - 字幕型 Playlist 和 Command Panel Search Result 的显示规则使用 Playback Cue Result

- 文字选择遵循 `2.5 文字选择与复制`。

- 正文左键：
  - Normal 和 Content Changed Cues 使用 Interactive Text Cell。
  - Unavailable Cues 只允许文字选择和复制，不响应播放。
  - Display Title、Time Range 和 Date Added 文字只负责选择和复制。
  - Checkbox 只改变批量选择。
  - Cue State Indicator 不响应普通左键动作。
  - 普通空白区域无动作。
  - 文字拖选可以从非标题栏且非顶栏的任意非交互区域开始（非交互区域 = 点击没有效果的区域）。手势进入表格后才建立新选区。
  - 选区内容始终只有表格文字。

- 正文 Hover：
  - 普通模式下，Row Hover 使用 `--color-row-hover`，不显示 Full-row Selected。
  - Normal 和 Content Changed Cue Hover 使用 Interactive Text Cell；只改变文字色和下划线，不绘制独立背景。
  - Unavailable Cue 不显示 Interactive Text Cell Hover。
  - Cue State Indicator Hover 显示 Cue State Tip。
  - Display Title、Time Range 和 Date Added 不显示可点击 Hover。
  - Pointer Cursor 只出现在可播放 Cue 的直接点击区域。

- 行右键交互使用 Row Action Menu。

- Search / Context Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Deep Link`
  6. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  7. `Copy Time Range`

- Shiori Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Deep Link`
  6. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  7. `Copy Time Range`
  8. `Move to ...`
  9. `Duplicate to ...`
  10. `Remove Shiori`

- Normal 和 Content Changed Shiori Row 使用现有 Action 可用性。

- Unavailable Shiori Row：
  - `Play` 为 Disabled
  - `Open Subtitle Folder` 仅在当前 Subtitle File 仍可访问时可用，否则为 Disabled
  - `Context` 为 Disabled
  - `Copy Cue Text` 可用，复制最后保存的 Cue Snapshot
  - `Copy Deep Link` 为 Disabled
  - `Copy Cue Group Text` 在显示时可用，复制最后保存的 Cue Group Snapshot
  - `Copy Time Range` 可用，复制当前行显示的 Time Range
  - `Move to ...` 为 Disabled
  - `Duplicate to ...` 为 Disabled
  - `Remove Shiori` 可用

- Divider：
  - `Context` 与 `Copy Cue Text` 之间显示 Divider。
  - Shiori 的 `Copy Time Range` 与 `Move to ...` 之间显示 Divider。
  - Shiori 的 `Duplicate to ...` 与 `Remove Shiori` 之间显示 Divider。

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

- `Copy Deep Link`：
  - 只复制 Primary Cue 的 Deep Link，不复制 Cue Group。
  - 格式为 `[Cue text](cueseeker://cue?id={CueID})`。
  - 只发布 Plain Text，不发布 HTML 或 RTF。

- `Copy Cue Group Text`：
  - 仅 `Show Cue Group = On` 时显示。
  - 按稳定 Source Display Order 复制当前显示的完整 Cue Group。
  - 保留每个 Cue 的源行序和换行。

- `Copy Time Range`：
  - 复制当前行 Primary Cue 显示的 Time Range。
  - 输出格式遵循本 Layout 的 Time Range 格式。

- `Move to ...`：
  - 仅用于 Shiori。
  - 使用 Move Icon 和 Action Submenu。
  - Submenu 按 Shiori List 默认顺序显示目标列表。
  - Submenu 不显示当前 Shiori List。
  - 没有可用目标列表时为 Disabled。
  - 选择目标列表后，先向目标列表写入当前 Shiori。
  - 只有目标写入成功后才从来源列表移除当前 Shiori。
  - 移动后保留 Time Added。
  - 操作结果按照 `Toast Usage Registry` 调用对应 Toast 场景。

- `Duplicate to ...`：
  - 仅用于 Shiori。
  - 使用 Duplicate Icon 和 Action Submenu。
  - Submenu 按 Shiori List 默认顺序显示目标列表。
  - Submenu 不显示当前 Shiori List。
  - 没有可用目标列表时为 Disabled。
  - 选择目标列表后创建新的 ShioriID，其他 Shiori 数据保持一致。
  - 复制后保留 Time Added。
  - 操作结果按照 `Toast Usage Registry` 调用对应 Toast 场景。

- `Remove Shiori`：
  - 仅用于 Shiori。
  - 打开 Confirmation Dialog。
  - 不直接移除。

- View Menu：
  - Cues 始终 Checked 且 Disabled。
  - 其他数据列可以隐藏。
  - Selection Column 是 `#` / Checkbox 状态列，不出现在 View Menu 中。

- Search Empty Hint：
  - 文案：`Enter a search term to show cues.`
  - 条件：没有 Search Term。
  - Filter Data Card 的选择状态不改变 Search Empty Hint。
  - Search Filter Data Panel 继续显示，所有 Option Count 固定显示 `0`。

- Shiori Empty Hint：
  - 文案：`Save cues from playback to collect Shiori.`
  - 条件：没有已保存的 Shiori Row。

### 4.4 Dialogs 与 Popovers

#### Edit Cover Dialog Layout

- 从上到下包括：
  1. Title
  2. Library Cover Crop Editor
  3. Hint
  4. Actions
- Title：`Edit Cover`。
- Hint：`Support: JPG, JPEG, PNG, and GIF no more than 20 MB.`
- Actions：
  - Neutral Button：`Cancel`
  - Primary Button：`Save`

#### Shiori List Editor Dialog Layout

- 使用 Modal Overlay。
- Panel 居中显示。
- Main Content 使用左右两列布局，间距使用 `--spacing-6`。
- 左侧为 Cover Region，右侧为 Form Region。
- 点击 Dialog 外部不关闭。

- Title：
  - New 模式：`New List`
  - Edit 模式：`Edit List`

- Cover Region：
  - 使用 Library Cover 和 Library Cover Crop Editor
  - 没有自定义封面时显示 Shiori Default Cover
  - 没有自定义封面时显示 Neutral Button：`Choose Image`
  - 已有自定义封面时显示 Neutral Button：`Change Image`
  - 选择有效图片后在当前 Dialog 中显示 Library Cover Crop Editor
  - 不打开嵌套的 Edit Cover Dialog
  - Hint：`Support: JPG, JPEG, PNG, and GIF no more than 20 MB.`
  - 本版本不提供恢复默认封面的命令

- Form Region 从上到下包括：
  1. List Name Form Text Field
  2. Description Form Text Area

- List Name：
  - Label：`List Name`
  - Placeholder：`Enter a list name`
  - 最多 `30` 个字符
  - 允许继续输入超过限制的内容
  - 空值错误：`Enter a list name`
  - 长度错误：`List name must be 30 characters or fewer. You entered {Current Count}.`
  - 重复错误：`A list with this name already exists. Choose a different name.`

- Description：
  - Label：`Description (optional)`
  - Placeholder：`Add a description (optional)`
  - 最多 `100` 个字符
  - 允许为空
  - 允许继续输入超过限制的内容
  - 长度错误：`Description must be 100 characters or fewer. You entered {Current Count}.`

- Validation：
  - 只在点击当前模式的 Primary Action 时首次执行
  - 名称按 Empty、Length、Duplicate 的顺序检查
  - 名称字符数合法后才检查重复
  - 名称和描述同时不合法时，同时显示两个错误
  - Validation Message 显示在对应 Input 上方
  - 同时存在多个错误时聚焦第一个错误字段
  - 错误已经显示后，继续编辑该字段时重新校验
  - 字段恢复合法后立即清除对应错误

- Actions：
  - New 模式：Neutral Button `Cancel`、Primary Button `Create`
  - Edit 模式：Neutral Button `Cancel`、Primary Button `Save`

- Cancel：
  - 没有未保存修改时直接关闭 Dialog
  - 存在未保存修改时打开 Save Changes Confirmation Dialog

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
- Actions 可以组合 Neutral Button、Primary Button 和 Destructive Button。
- Action 数量不固定为两个。
- 每个具体 Dialog 定义自己的默认焦点动作。
- Escape 等同于当前 Dialog 的 Cancel。
- 点击 Dialog 外部不关闭。
- Enter 激活当前默认焦点动作。

- Remove Shiori：
  - Title：`Remove Shiori`
  - Message：`This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.`
  - Cancel：Neutral Button，`Cancel`
  - Confirm：Destructive Button，`Remove`

- Delete List：
  - Title：`Delete List`
  - Message：`The list “{List Name}” and its Shiori entries will be deleted. The original subtitle and video files will not be deleted.`
  - Cancel：Neutral Button，`Cancel`
  - Confirm：Destructive Button，`Delete`
  - 默认焦点为 Cancel

- Save Changes：
  - Title：`Save Changes?`
  - Message：`You have unsaved changes. Do you want to save them before closing?`
  - Actions 从左到右：
    1. Destructive Button：`Don’t Save`
    2. Neutral Button：`Cancel`
    3. Primary Button：`Save`
  - 默认焦点为 Save
  - Escape 等同于 Cancel
  - `Don’t Save` 放弃未保存修改并关闭 Shiori List Editor Dialog
  - `Cancel` 关闭当前 Confirmation Dialog，并返回 Shiori List Editor Dialog
  - `Save` 执行 Shiori List Editor Dialog 当前模式的 Primary Action
  - Validation 失败时关闭当前 Confirmation Dialog，保留 Shiori List Editor Dialog，并显示对应字段错误

- Confirm 只执行当前明确的 Command Target。
- Cancel 不产生数据变更。

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
- Close 关闭 Playback Page，并按 Playback Enter Context 返回对应 Workbench Feature。
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
  - Screenshot
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

#### Playback Pointer Visibility

- Playback Page 初始化时隐藏 Pointer。
- 只有 Pointer Move 恢复 Pointer 显示。
- Wheel 不恢复 Pointer 显示。
- 任意键盘按键隐藏 Pointer。
- Pointer 隐藏时不允许 Pointer 命中目标改变 Playback Media Selection。
- Pointer 恢复显示后，各组件定义的 Hover 和 Cursor 规则继续生效。
- Pointer 显示时，内容滚动导致 Pointer 命中的卡片变化，属于有效的 Hover 目标变化。

#### Playback Overlay Layout

- 覆盖完整 Playback Stage。
- 不是独立原生窗口。
- 位于 Video 和 Playback Chrome 之上。
- 位于现有 Playback Feedback Overlay 之下。
- 背景使用 `--color-subtitle-focus-overlay-bg`。
- 跟随 CueSeeker 当前有效 Appearance。
- Appearance Mode 为 Auto 时，跟随当前 macOS 系统 Appearance。
- Appearance Mode 为 Light 或 Dark 时，使用对应的强制 Appearance。
- Overlay 显示期间 Appearance 发生变化时，更新当前可见 View、Native Reel 和 Scrollbar 的颜色。
- Appearance 更新不重建 Overlay Session，不改变当前 View、选择位置或滚动位置。
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。
- Overlay 显示期间 Playback 保持暂停，直到执行播放动作或退出 Overlay。

- Playlist Source Host：
  - Playlist 可以来源于 Search Result、Shiori 或 Library
  - 通过 Recent Videos 或 Library 入口播放视频时，均使用当前视频所在文件夹对应的 Library Playlist
  - Playlist 复用对应 Workbench Feature 的数据顺序和正式操作结果
  - Playback 不提供 Checkbox 批量操作、导出、添加文件夹、Context、Filter 控件或复制表格入口
  - Playback 只提供 Current 和当前 Playlist Source 在本 Layout 中明确列出的操作
  - Current 不属于 Workbench Feature Host，只显示当前视频及其完整 Cue 集合

- Playback Enter Context：
  - 生命周期覆盖整个 Playback Page，并跨越同一 Playback Page 内的多次 Overlay Session
  - 只有 Search、Shiori、Recent 和 Library 四种返回目标
  - 打开 Playback Page 时，以进入 Playback 前的 Workbench Feature 初始化
  - 从 Search Result Playlist 成功播放 Result 时更新为 Search
  - 从 Shiori Playlist 成功播放 Result 时更新为 Shiori
  - 通过 Recent Videos 入口打开 Playback Page 时初始化为 Recent
  - 通过 Library Folder Detail 入口打开 Playback Page 时初始化为对应的 Library Folder Detail
  - 在 Library Playlist 中成功播放其他视频时，保持当前的 Recent 或 Library Playback Enter Context
  - 从 Search Result 或 Shiori Playlist 成功播放后，新的返回目标替换当前 Playback Enter Context
  - 只切换 Current 与 Playlist、浏览 Playlist、打开或关闭 Command Panel，不更新 Playback Enter Context
  - 关闭 Playback Page 时，根据当前 Playback Enter Context 返回 Workbench
  - Playback Enter Context 只决定返回目标，不保存、删除或回滚其他 Feature 状态
  - 返回 Search 时显示 Search Feature 当前 Query，而不是 Playback Enter Context 创建时的 Query 快照
  - 完成返回后销毁 Playback Enter Context

- 基本结构：
  1. Playback Overlay Topbar
  2. View Content Region

- Playback Overlay Topbar：
  - 固定在 Overlay 顶部并横跨完整内容宽度
  - 不显示独立背景、边框或 Divider
  - 普通状态下，居中排列 Current 和 Playlist 两个 Playback View Tab
  - 当前 View 使用 Selected 状态
  - Current 左侧显示 Collage Neutral Button，使用 Edit Icon `square.and.pencil`
  - Collage Button 与 Topbar 左边界的间距使用 `--spacing-4`
  - Playlist 不显示 Collage Button
  - 点击 Collage Button 或在 Current 按无修饰 `P` 进入 Editing Collage
  - 普通状态下，无修饰 `Tab` 在 Current 和 Playlist 之间循环切换
  - 普通状态下，无修饰 `Tab` 不执行原生焦点遍历
  - Editing Collage 状态下，左侧 Collage Button 的 Label 改为 `Exit`
  - Editing Collage 状态下，隐藏 Current 和 Playlist 两个 Playback View Tab
  - Editing Collage 状态下，Topbar 中央显示 Edit Icon `square.and.pencil` 和 `Editing Collage`
  - Edit Icon 与 `Editing Collage` 的间距使用 `--spacing-2`
  - `Editing Collage` 复用 Selected Playback View Tab 的文字颜色和字体样式
  - Editing Collage 状态下，禁止通过点击或无修饰 `Tab` 切换 Current 和 Playlist
  - Editing Collage 状态下，无修饰 `Tab` 被当前界面消费，不执行原生焦点遍历
  - 点击 `Exit`、按无修饰 `P` 或按 `Escape` 返回 Current 普通状态
  - Editing Collage 状态下，其他无修饰 Playback 快捷键不执行原动作
  - Editing Collage 状态下，`Up` 和 `Down` 保留给字幕阅读列表滚动

- View Content Region：
  - 占据 Playback Overlay Topbar 下方的全部可用区域
  - 内容内边距使用 `--spacing-8`
  - Current、Playlist 和 Editing Collage 共用同一 View Content Region
  - 状态切换只替换 View Content Region 内容
  - Current 和 Playlist 之间切换不关闭 Overlay
  - View Content Region 内不显示独立背景、边框或 Divider

- 打开：
  - Playback Page 活跃时按 `Enter`
  - 每次打开创建一个新的临时 Overlay Session
  - 立即暂停 Playback
  - 默认 View 由当前 Playlist 类型决定：
    - 当前为视频型 Playlist 时，默认进入 Current
    - 当前为字幕型 Playlist 时，默认进入 Playlist
    - 没有可用 Playlist 时，默认进入 Current
  - 新增 Playback 入口或 Playlist Source 时，必须兼容上述默认 View 规则
  - 初始 Cue 准备期间保留暂停的视频画面
  - 不显示 Loading Spinner 或 Progress Bar
  - 初始 Cue 准备完成后显示 Overlay

- Session：
  - 每次打开 Playback Overlay 创建一个新的 Overlay Session
  - Current 和 Playlist 的切换属于同一次 Overlay Session
  - View 切换期间保留 Current 和 Playlist 各自的选择与滚动位置
  - Current 或 Playlist 普通状态下，Escape、播放动作、关闭 Playback Page或其他关闭 Overlay 的路径结束并销毁当前 Overlay Session
  - Editing Collage 状态下，Escape 只退出 Editing Collage 并返回 Current，不结束 Overlay Session
  - Overlay Session 结束时同时清除 Editing Collage 临时状态
  - Session 结束后不保留当前 View、选择位置、滚动位置或临时显示内容
  - 再次打开 Playback Overlay 时，根据当前 Playlist 类型重新决定默认 View，并重新初始化两个 View 的局部状态
  - Session 销毁不删除 Playlist、Playback History、Search Query、Shiori、Recent、Library 或其他持久 Feature 状态
  - Session 生命周期以 Playback Overlay 的打开和关闭为边界，不以单个 View 的出现或消失为边界

- Current：
  - 只显示占满 View Content Region 的 Subtitle Region
  - 不显示左侧 Context Region、Library Cover 或视频识别信息
  - Subtitle Region 维持现有 Subtitle Focus Cue Reel
  - Cue Reel 最大宽度使用 `--width-subtitle-focus-content-max`，并在 Subtitle Region 中水平居中
  - 纵向排列 Subtitle Focus Cue
  - Cue Gap 使用 `--gap-subtitle-focus-cue`
  - Current 始终只显示 Primary Cue，不显示 Cue Group
  - 每个 Cue 上方显示两个独立的 Playback Cue Information Badge：
    1. Display Title
    2. Time Range
  - Selected Cue 使用 Selected Badge 配色
  - Unselected Cue 显示相同内容和数量的信息行，并使用 Unselected Badge 配色
  - 允许顶部和底部出现部分可见的相邻 Cue
  - 不显示卡片、边框、背景或可见 Focus Marker

- Editing Collage / Subtitle Selection Region：
  - View Content Region 左右等分；左侧保留给 Collage Preview Region，右侧显示 Subtitle Selection Region
  - Subtitle Selection Region 直接复用 Current 的 Subtitle Focus Cue Reel、虚拟化布局、焦点交互和 Table Scrollbar，不建立独立字幕列表或滚动条
  - Cue 数据、排列顺序、Display Title 和 Time Range 继承 Current
  - Cue Reel 在右侧 Subtitle Selection Region 中水平居中
  - 进入 Editing Collage 时保持 Current 的焦点和滚动位置，并默认勾选焦点字幕
  - 退出 Editing Collage 后保留退出前的焦点和滚动位置
  - 每个 Cue 增加 Leading Checkbox Slot；Checkbox 使用 `--size-playback-collage-checkbox`，与 Cue 内容间距使用 `--spacing-4`
  - Checkbox 与 Primary Cue 第一条视觉行垂直居中对齐
  - Display Title 和 Time Range 继续由现有 Playback Cue Information Badge 布局统一排列，不单独定位
  - Unchecked 使用 `circle` 和 `--color-border-checkbox`
  - Checked 使用强制 Monochrome 的 `checkmark.circle.fill` 和 `--color-text-muted`
  - Disabled 使用 `--color-icon-disabled`
  - Light 和 Dark Appearance 均复用 Filter Data Card Checkbox 的对应动态颜色
  - Checkbox 不显示 Hover、Pressed、Click 动画或 Focus Ring，也不获得独立键盘焦点
  - 整个 Cue Placement 都是 Checkbox 的点击区域，包括 Checkbox、Display Title、Time Range 和 Primary Cue
  - 点击 Cue Placement 只切换 Checkbox，不改变焦点
  - 无修饰 `Enter` 切换焦点字幕的 Checkbox
  - `Up`、`Down`、Wheel、Trackpad 和 Table Scrollbar 继续使用 Current 的焦点导航
  - 焦点状态与 Checkbox 状态彼此独立
  - 只有焦点决定 Subtitle Focus Cue 和 Playback Cue Information Badge 的 Selected / Unselected 样式
  - Checkbox 的 Checked / Unchecked 变化不改变字幕或 Badge 样式
  - 最多勾选 `50` 条；达到上限后，未勾选项进入 Disabled，已勾选项仍可取消勾选

- Editing Collage / Collage Preview Region：
  - 位于 View Content Region 左半部分，与右侧 Subtitle Selection Region 等宽
  - 从上到下排列 Section Title `Collage Preview`、Collage Image Viewport 和 Action Row
  - Region 内边距使用 `--spacing-8`；三个区域之间使用 `--spacing-4`
  - `Collage Preview` 复用 Section Title
  - Action Row 显示两个 Neutral Button，按钮间距使用 `--spacing-3`
  - `Copy Collage` 使用 `doc.on.doc`
  - `Export Collage` 使用表格 Anki 操作相同的 `square.and.arrow.up`
  - Section Title 和 Action Row 固定，只有 Collage Image Viewport 可以滚动
  - Collage 显示为一张连续画布，不按时间戳分组显示独立图片
  - 图片保持原始宽高比并适配 Viewport 的完整可用宽度，不横向滚动
  - 图片高度超过 Viewport 时显示纵向 Table Scrollbar；未超过时不显示滚动条
  - 不显示 macOS 原生滚动条、外框或 Focus Ring
  - 进入 Editing Collage 后，根据默认勾选的焦点字幕生成首张实时预览
  - Checkbox 变化后只重新渲染受影响的时间戳分组，未变化分组复用已有渲染结果，再合成为新的连续画布
  - 新的选择状态取代尚未完成的旧渲染任务；过期结果不得替换当前预览
  - 预览异步渲染完成只刷新 Collage Preview Region，不再次刷新右侧 Subtitle Selection Region

- Current / Focus Anchor：
  - 是不可见的 Screen-space Anchor
  - 固定在 Cue Reel Viewport 垂直中心
  - Fit Cue 的完整中心与 Focus Anchor 对齐
  - Oversized Cue 的顶边与 Viewport 顶边对齐
  - 第一和最后一个 Fit Cue 也可以使用相同 Anchor
  - 窗口宽度变化后保留当前 Cue，并恢复对应 Placement

- Current / Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - Visual Line 的测量和排列遵循 Subtitle Focus Cue
  - Nominal Content Height：

    `Visual Line Count × --line-height-subtitle-focus-cue`

  - Base Natural Height：

    `max(Nominal Content Height, Visual Line Stack Height) + 2 × --padding-subtitle-focus-cue-y`

  - 每个 Cue 显示信息行：

    `Natural Height = Base Natural Height + --height-playback-cue-information-badge + --spacing-2`

  - Selected 和 Unselected Cue 使用相同的 Natural Height

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 当前字体度量下，一行 Cue Base Natural Height：`48px`
  - 当前字体度量下，两行 Cue Base Natural Height：`80px`
  - 当前字体度量下，三行 Cue Base Natural Height：`112px`
  - Playback Cue Information Badge 使用固定高度，不参与字幕 Base Natural Height 测量；选择变化只改变配色，不改变 Cue Geometry
  - Fit Cue 显示全部内容
  - Oversized Cue 从信息行和第一视觉行开始显示，只裁剪底部超出内容
  - Oversized Cue 不保留内部阅读 Offset

- Current / Scrollbar：
  - 位于 Subtitle Region Trailing Edge
  - 使用纵向 Table Scrollbar
  - 存在 Cue 时持续可见
  - 完整 Cue 集合可用前可以显示为不可交互状态
  - Position 映射到 Fractional Cue Ordinal
  - 长 Cue 和短 Cue 占用相同的 Ordinal 比例
  - Drag 时在相邻 Cue Placement 之间连续预览
  - Release 时选择最近的稳定 Cue
  - Thumb 不短于 `--scrollbar-min-thumb-length`

- Current / Default Cue：
  - Timestamp 位于 Cue Group 内时，选择该组稳定显示顺序中物理位置最靠下的 Cue
  - Timestamp 不位于 Cue 内时，选择最近的 Previous Cue
  - 没有 Previous Cue 时选择第一个 Cue

- Current / Cue Navigation：
  - Up 选择 Previous Cue
  - Down 选择 Next Cue
  - 到达边界时无动作
  - Discrete Wheel 在允许方向上至少移动一个 Cue
  - Precise Scroll 和 Momentum 在相邻 Placement 之间连续移动
  - Scroll 结束后 Fit Cue Center 回到 Focus Anchor
  - Scroll 结束后 Oversized Cue 回到 Top Placement
  - Wheel、Trackpad 和 Scrollbar Navigation 不执行 Seek

- Current / Cue Pointer：
  - Cue 不显示 Hover
  - Cue 不响应左键动作
  - 点击不改变 Selected Cue
  - 点击不穿透到底层 Video
  - Wheel 和 Scrollbar 仍可使用
  - Cursor 使用 `default`

- Playback Cue Result Reel：
  - 适用于字幕型 Playlist 和 Command Panel Search Result
  - 使用 Playback Cue Result 作为纵向排列单元
  - 不显示左侧 Library Cover 或独立 Sequence Number 区域
  - Focus Anchor、Scrollbar、Up、Down、Wheel、Trackpad、Scrollbar Drag 和 Settle 语义复用 Current Cue Reel
  - Result Natural Height 代替 Current Cue Natural Height 参与 Placement 计算
  - Show Cue Group 为 On 时，每条 Result 都在 Primary Cue 下方显示 Cue Group
  - Show Cue Group 为 Off 时，每条 Result 只显示 Primary Cue
  - 每个 Result 均显示三个独立的 Playback Cue Information Badge：
    1. `[x/y]`
    2. Display Title
    3. Time Range
  - Selected Result 使用 Selected Badge 配色
  - Unselected Result 显示相同内容和数量的 Badge，并使用 Unselected Badge 配色
  - 选择变化不改变 Badge 内容、数量或 Result Natural Height
  - `[x/y]` 中 `x` 表示当前 Result 在完整结果集合中的位置，`y` 表示完整结果集合的 Result 数量
  - Command Panel Search 的 `50` 条预览限制不改变 `[x/y]` 使用的完整结果数量
  - 字幕型 Playlist 在本次 Session 首次初始化时默认选择第一条 Result
  - Command Panel Search Result 首屏结果出来后默认选择第一条 Result，且除非用户操作不修改选中 Result
  - 到达列表边界时继续导航无动作
  - 字幕型 Playlist 和 Command Panel Search Result 均不显示 Hover，不响应左键动作
  - 没有 Result 时不存在 Selected Result
  - 不存在 Selected Result 时，所有字幕动作均无动作
  - 从 Current 切换回字幕型 Playlist 后，恢复本次 Session 内的选择和滚动位置

- Playback Media Selection：
  - 适用于从 Recent Videos 或 Library 进入的视频播放
  - 视频型 Playlist 中的 Item 统一复用 Library Episode Layout
  - Workbench 中的 Library Episode 只使用所属 Layout 定义的 Hover，不建立持久 Selected Item
  - Playback 的 Selected Item 完整复用 Library Episode Layout 的 Hover Region 和 Hover 视觉
  - Selected Item 不显示额外 Focus Ring、边框或独立 Selected 背景
  - Library Episode 的 Selected 视觉只作用于 Cover Region
  - 视频型 Playlist 不显示 Library Folder Card 或 Library 层级导航
  - 方向键选择对应视觉方向上最近的可用 Item
  - Pointer 显示时，Hover 到可用的非 Selected Item 会将其设为 Selected Item
  - Pointer 显示时，滚动内容使静止 Pointer 下的 Hover 目标发生变化，也按新的 Hover 目标更新 Selected Item
  - Pointer 离开卡片或移到空白区域时不清空 Selected Item
  - 不可用 Item 不允许成为 Selected Item，方向键和 Hover 均跳过
  - Selected Item 始终滚动到可见区域
  - Selected Item 因数据刷新消失后，选择当前 Playlist 的第一条可用 Item
  - Enter 执行 Selected Item 在 Library Episode Layout 中定义的左键主操作
  - 鼠标左键和右键动作继续由 Library Episode Layout 定义
  - 没有可用 Item 时不存在 Selected Item，Enter 无动作
  - 从 Current 切换回视频型 Playlist 后，恢复本次 Session 内的选择和滚动位置

- Playlist：
  - Playlist 的视觉布局由当前 Playlist Source 决定
  - Playlist 始终保留完整数据集合，不受 Command Panel 首屏显示数量限制
  - 本次 Session 首次进入 Playlist 时默认选择第一条可用 Item
  - 再次返回 Playlist 时恢复本次 Session 内的选择和滚动位置

- 字幕型 Playlist：
  - 适用于 Search Result 和 Shiori
  - 只显示占满 View Content Region 的 Subtitle Region
  - 不显示左侧 Context Region、Library Cover 或视频识别信息
  - Subtitle Region 使用 Playback Cue Result Reel
  - 整体信息密度可以高于 Current
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、X、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue

- 视频型 Playlist：
  - 适用于从 Recent Videos 或 Library 进入的视频播放
  - Recent Videos 和 Library 只是进入视频播放的不同入口，不产生不同的 Playlist
  - 两个入口均显示当前视频所在文件夹的完整视频列表
  - Recent Videos 和 Library 只决定退出视频播放后返回的位置，不决定 Playlist 的内容或布局
  - 统一复用现有 Library Folder Detail 的 Episode 列表、条目和选择视觉
  - 不显示 Library 一级界面、Library Folder Card、返回按钮或页面顶部 Title
  - Item 顺序与视频播放界面的上一个、下一个使用同一份当前文件夹视频顺序
  - Selected 视觉复用 Library Episode 的选择区域和视觉规则
  - 方向键选择 Previous Item 或 Next Item
  - Enter 执行当前 Selected Item 的主操作

- Playback Overlay Cue Keyboard Actions：
  - 适用于 Current 和字幕型 Playlist
  - 所有动作以已经 Settled 的 Selected Primary Cue 为目标
  - Cue 正在移动时接受的动作，在当前目标 Settled 后执行一次
  - 不存在 Selected Primary Cue 时，S、X、C 和 Enter 均无动作

- `S`：
  - 保存 Selected Primary Cue
  - 目标为 Shiori List 当前默认顺序中的第一个列表
  - 已保存判断只针对当前目标列表
  - 目标列表已经存在同一 CueID 时不删除、不重复创建
  - 新保存显示 `Shiori Saved`
  - 已存在显示 `Shiori Already Saved`
  - Overlay 保持显示
  - Playback 保持暂停
  - 当前选择和位置不变

- `X`：
  - 复制 Selected Primary Cue 的 Markdown Deep Link
  - 格式为 `[Cue text](cueseeker://cue?id={CueID})`
  - 只发布 Plain Text，不发布 HTML 或 RTF
  - 显示 `Deep Link Copied`
  - Overlay 保持显示
  - Playback 保持暂停
  - 当前选择和位置不变

- `C`：
  - 复制 Selected Primary Cue 的完整多行文字
  - 不复制完整 Cue Group
  - 保留源行序和换行
  - 显示 `Cue Text Copied`
  - Overlay 保持显示
  - Playback 保持暂停
  - 当前选择和位置不变

- `Enter`：
  - Seek 至 Selected Primary Cue Start Time
  - 关闭 Overlay
  - 销毁当前 Overlay Session
  - 从该位置连续播放
  - 显示 `Play`

- Escape：
  - 关闭 Overlay
  - 销毁当前 Overlay Session
  - 恢复打开前的 Playback State
  - 不执行隐式 Seek

- Motion：
  - Current Cue Reel Duration 使用 `--duration-subtitle-focus-scroll`
  - Current Cue Reel Easing 使用 `--easing-subtitle-focus-scroll`
  - 动画距离由当前 Cue 和目标 Cue 的 Resolved Height 决定
  - Reduce Motion 下立即到达最终 Placement
  - Reduce Motion 不改变选择、Oversized Cue Placement 或 Scrollbar Drag 语义

#### Playback Command Panel Layout

- Command Panel 是 Playback 中的快速搜索、跳转和恢复界面。
- Command Panel 位于 Playback Overlay 和 Playback Content 之上。
- Command Panel 打开后取得唯一键盘焦点。
- 下层 Playback Overlay 或 Playback Content 保持可见，但降低对比、变暗或轻微模糊，并且不可交互。
- Command Panel 不显示 macOS Traffic Light Buttons。
- Panel 内不显示不承担操作的顶部或左右 Divider。
- Panel 使用内容排列、留白和所属内容布局自然划分区域。

- 打开：
  - Playback Page 活跃时按反引号键（`` ` ``，Esc 下方、数字 `1` 左侧）
  - Playback Overlay 活跃时也可以打开
  - 只有无修饰键的 `` ` `` 打开 Command Panel；`Shift` + `` ` `` 不打开 Command Panel
  - 文本输入状态下，`` ` `` 作为正常文本输入，不打开 Command Panel
  - 打开后暂停 Playback
  - 通过 `` ` `` 打开时，默认进入一级界面，Command Panel Search Box 默认获得输入焦点。
  - 视频播放界面的 Deep Link 搜索可以直接进入 Search Result 二级界面。
  - `Play First Search Result` 关闭时，使用 Deep Link Query 执行与一级界面 Search Action 相同的搜索。
  - `Play First Search Result` 开启但不存在结果时，进入显示 `0 results` 的 Search Result 二级界面。

- 一级界面 / Empty Query：
  - 第一项为 Recent Videos，并默认处于 Selected
  - 第二项为 Recent Shioris
  - 每项包括 Leading Icon 和 Label

- 一级界面 / Filled Query：
  - 第一项变为 Search Action，并默认处于 Selected
  - Search Action 包括 Search Icon、`Search` 和当前 Query
  - Recent Videos 和 Recent Shioris 继续显示在 Search Action 下方

- 一级界面 Footer：
  - 不显示左下角 App Icon
  - 右侧依次显示：
    - `↑`、`↓`、`Navigate`
    - `Open`
    - `Enter`
  - 不显示 Actions 或对应快捷键提示

- 二级界面 Header：
  - 左上角显示 Back Button
  - 标题在 Header 中水平居中
  - Recent Videos 标题为 `Recent Videos`
  - Recent Shioris 标题为 `Recent Shioris`
  - Search Result 标题为当前 Query
  - 二级界面隐藏 Command Panel Search Box

- Search Result：
  - 复用 Playback Cue Result Reel 的布局、选择、滚动和键盘操作
  - 不显示 Context Region、Library Cover 或 Playback Overlay Topbar
  - Result Reel 占据 Header 与 Footer 之间的完整内容区域
  - 默认选择第一条 Result
  - Show Cue Group 为 On 时，每条 Result 都在 Primary Cue 下方显示 Cue Group
  - Show Cue Group 为 Off 时，每条 Result 只显示 Primary Cue
  - 每个 Result 均显示 `[x/y]`、Display Title 和 Time Range 三个独立的 Playback Cue Information Badge
  - Selected Result 使用 Selected Badge 配色
  - Unselected Result 显示相同内容和数量的信息行，并使用 Unselected Badge 配色
  - Command Panel 最多显示前 `50` 条 Result
  - `[x/y]` 使用当前 Result 在完整搜索结果中的位置和完整搜索结果数量
  - 完整结果数小于等于 `50` 时，Footer 左侧显示 `{N} results`
  - 完整结果数大于 `50` 时，Footer 左侧显示 `Showing first 50 results`
  - `50` 条限制只作用于 Command Panel 当前结果预览
  - 按 `Enter` 后进入包含完整结果集合的 Playlist，并从 Selected Primary Cue 开始播放
  - Search Result 二级界面没有可编辑输入焦点
  - Search Result 支持 Playback Overlay 当前全部 Cue 快捷键，包括 `S`、`X`、`C` 和 `Enter`
  - Cue 快捷键以已经 Settled 的 Selected Primary Cue 为目标

- Recent Videos：
  - 复用 Recent Watching Card Layout 和自适应卡片 Grid，不使用纵向单列 Row
  - 卡片布局、内容、Hover、Selected、Disabled、左键和右键行为均复用 Recent Watching Card Layout
  - Selected 视觉作用于完整卡片，并复用卡片的 Hover 视觉
  - Footer 左侧显示 `{N} videos`
  - 二级界面显示完整 Recent Videos 列表

- Recent Shioris：
  - 复用 Recent Shiori Resume Row Layout
  - Selected 视觉作用于完整 Row
  - Footer 左侧显示 `{N} shioris`
  - 二级界面显示完整 Recent Shioris 列表

- 二级界面 Footer：
  - Recent Videos 右侧依次显示：
    - `←`、`→`、`↑`、`↓`、`Navigate`
    - `Open`
    - `Enter`
  - Search Result 和 Recent Shioris 右侧依次显示：
    - `↑`、`↓`、`Navigate`
    - `Open`
    - `Enter`
  - 不显示 Actions 或对应快捷键提示

- 导航与关闭：
  - 一级界面、Search Result 和 Recent Shioris 使用 `Up` 选择 Previous Item，使用 `Down` 选择 Next Item
  - Recent Videos 支持 `Left`、`Right`、`Up` 和 `Down`
  - Recent Videos 根据当前自适应卡片 Grid 的实际视觉位置，选择对应方向最近的卡片
  - Recent Videos 到达对应方向边界时不移动、不循环
  - Recent Videos 的 Selected Card 始终滚动到可见区域
  - `Enter` 执行 Selected Item 的主操作
  - 二级界面按 `Escape` 返回一级界面
  - 一级界面按 `Escape` 关闭 Command Panel
  - 从 Playback Overlay 打开的 Command Panel 关闭后返回原 Overlay
  - 下层仍存在 Playback Overlay 时继续保持暂停
  - 下层不存在其他模态界面时，根据打开第一层模态界面前的 Playback State 决定是否恢复播放
