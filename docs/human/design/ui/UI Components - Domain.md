# 说明
1. 本文档由人类维护，定义业务与反馈组件（`C-08` ~ `C-13`）：Data Display、Feedback、Dialogs、Media、Player Controls、Playback Content。
2. 所有组件默认遵守 `/docs/human/design/ui/UI Design Rules.md`、`/docs/human/design/ui/UI Interaction Rules.md` 与 `/docs/human/design/ui/UI Text Selection Rules.md`。

# 2. Components（Part 2：Domain `C-08` ~ `C-13`）

## 2.8 Data Display

### C-08.1 Watch Status Badge

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-chip`
  - Border Width：`--border-width-control`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-caption`
  - Font Weight：`--font-weight-control`

##### Sizes

- Padding Inline：`--padding-chip-x`
- Padding Block：`--padding-chip-y`

##### States

- Unwatched
  - Background：`--color-watch-status-unwatched-bg`
  - Text Color：`--color-watch-status-unwatched-text`
  - Border Color：`--color-watch-status-unwatched-border`
- Watching
  - Background：`--color-watch-status-watching-bg`
  - Text Color：`--color-watch-status-watching-text`
  - Border Color：`--color-watch-status-watching-border`
- Finished
  - Background：`--color-watch-status-finished-bg`
  - Text Color：`--color-watch-status-finished-text`
  - Border Color：`--color-watch-status-finished-border`
- Disabled
  - Background：`--color-bg-disabled`
  - Text Color：`--color-text-disabled`
  - Border Color：`--color-border-disabled`

### C-08.2 Task Status Badge

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-chip`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-caption`

##### Sizes

- Padding Inline：`--padding-chip-x`
- Padding Block：`--padding-chip-y`

##### States

- In Progress
  - Background：`--color-watch-status-watching-bg`
  - Text Color：`--color-watch-status-watching-text`
- Queued
  - Background：`--color-watch-status-unwatched-bg`
  - Text Color：`--color-watch-status-unwatched-text`

### C-08.3 Information Badge

#### Shared

##### Anatomy

- Container
- Label

##### Sizes

##### States

#### Variants

##### Cover Badge

- Radius：`--radius-library-time-badge`
- Padding：`--padding-library-time-badge`
- Background：`--color-library-time-badge-bg`
- Font Family：`--font-family-base`
- Font Size：`--font-size-library-time-badge`
- Text Color：`--color-library-time-badge-text`
- States
  - Time：`MM:SS/MM:SS`（达 1 小时为 `HH:MM:SS`；未知总时长时仅显示已播放时间）
  - Count
  - Hidden

##### Task Count Badge

- Placement：Task Entry 与 Filter Trigger 内图标右侧，按钮随之变宽；与图标字形墨迹的间距为 `--spacing-2`，右侧留白与图标上方留白相同；Filter Dialog 的 Section Header 内名称右侧
- Shape：1 位数为圆形，宽与高相等；2 位及以上为胶囊形，两端为正半圆
- Size：`--size-control-icon`；在 Section Header 内为 `--size-task-count-badge-compact`
- Padding Inline：1 位数为 0；2 位及以上为 `--spacing-2`，在 Section Header 内为 `--padding-task-count-badge-compact-x`
- Background：`--color-badge-neutral-bg`；在 Player Chrome 上为 `--color-player-control-bg-hover`；按钮 Hover 或 Open 时不变
- Font Family：`--font-family-base`
- Font Size：`--font-size-task-count-badge`；在 Section Header 内为 `--font-size-caption`
- Font Weight：`--font-weight-task-count-badge`
- Text Color：`--color-text-secondary`；在 Player Chrome 上为 `--color-player-text-secondary`；按钮 Disabled 时为 `--color-text-disabled`（在 Player Chrome 上为 `--color-player-text-tertiary`）
- States
  - Count
  - Hidden：数量为 0

### C-08.4 Tag

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-chip`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-caption`

##### Sizes

- Padding Inline：`--padding-chip-x`
- Padding Block：`--padding-chip-y`

##### States

- Default
  - Background：`--color-chip-language-bg`
  - Text Color：`--color-chip-language-text`
- Disabled
  - Background：`--color-bg-disabled`
  - Text Color：`--color-text-disabled`

#### Variants

##### Player Chrome

- Background：`--color-player-control-bg-hover`
- Text Color：`--color-player-text-secondary`

### C-08.5 Status Indicator

#### Shared

##### Anatomy

- Indicator

##### Sizes

##### States

- Default
- Hover（仅 File 可点击状态文字：文字颜色不变，显示与文字同色的下划线，Pointer 为 Grab）
- Disabled

#### Variants

##### Workbench Status Indicator

- Anatomy：Optional Leading Icon + Label
- Height：`--height-control`
- Font Family：`--font-family-base`
- Font Size：`--font-size-control`
- Font Weight：`--font-weight-control`
- Text Color：`--color-text-secondary`
- Icon Size：`--size-control-icon`
- Gap：`--spacing-2`
- Selection：Enabled（详见 `UI Text Selection Rules.md`）
- Usage：File `Last Updated`、Search `xx results`、Excerpt `xx excerpts`、Select Mode `xx / yy rows selected`、Library `xx folders`、Excerpt `xx lists  yy cues`

##### Cue State Indicator

- Icon Size：`--size-control-icon`
- Icon Color：`--color-text-muted`
- Gap：`--spacing-2`
- States
  - Content Changed：位于目标字幕末行右侧，Hover 显示 `--color-table-row-selected` 圆角底块
  - Unavailable：占据 `Cues` 列左侧纵向槽位并与目标字幕首行垂直居中，目标字幕与 Cue Group 附加字幕统一右移对齐；Hover 仅填充图标圆圈内部为 `--color-table-row-selected`

### C-08.6 Tooltip

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`；在 Player Chrome 上为 `--color-player-menu-bg`
  - Border Color：`--color-border-control`；在 Player Chrome 上无边框（`None`）
  - Border Width：`--border-width-control`（在 Player Chrome 上无）
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`；在 Player Chrome 上为 `--shadow-player-overlay`
  - Polarity：在 Player Chrome 上使用独立的 Player Chrome 固定样式（不随 Light / Dark Mode 变化）；其余界面（含 Playback Overlay 与 Command Panel）跟随当前 Light / Dark Mode
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Font Weight：`--font-weight-control`
  - Color：`--color-text-secondary`；在 Player Chrome 上为 `--color-player-text-primary`
- Shortcut
  - Presence：Optional
  - Component：Keycap / Popover Surface；在 Player Chrome 上为 Keycap / Player Chrome
  - Gap：`--spacing-1`
  - 修饰键（⌃、⌥、⇧、⌘）与主键各占一个 Keycap
- Content Gap：`--spacing-2`

##### Sizes

- Single-line Height：`--height-control`（多行折行时上下边距与单行一致）
- Padding Inline：`--padding-control-x`
- Maximum Width：`--width-tooltip-max`（仅截断补全文本；单行未超出时按内容宽度自适应包裹，超出时换行）

##### Placement

- Anchor Gap：`--spacing-2`
- Viewport Margin：`--spacing-2`
- Default：目标上方居中；顶部空间不足时翻转至下方居中；左右超出窗口安全边距时水平内移

##### States

- Hidden
- Visible

### C-08.7 Section Title

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-section-title`
  - Color：`--color-text-primary`
  - Font Weight：Semibold

##### Sizes

##### States

- Default
- Disabled
  - Text Color：`--color-text-disabled`

### C-08.8 Workbench Page Title

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-page-title`
  - Font Weight：`--font-weight-page-title`
  - Color：`--color-text-primary`
- Trailing Count：None

##### States

- Default

### C-08.9 Keycap

#### Shared

##### Anatomy

- Container
  - Border：None
  - Radius：`--radius-keycap`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-caption`
  - Font Weight：`--font-weight-control`
  - Color：`--color-text-muted`；在 Player Chrome 上为 `--color-player-text-primary`

##### Sizes

- Height：`--height-keycap`
- Minimum Width：`--height-keycap`
- Padding Inline：`--spacing-1`

##### Interaction

- Hit Testing：None
- Text Selection：None

##### States

- Default
- Hover
  - 跟随所属 Shortcut Action Button 或 Shortcut Field
- Pressed
  - 跟随所属 Shortcut Action Button 或 Shortcut Field

#### Variants

##### Overlay Surface

- Default
  - Background：`--color-overlay-surface-keycap-bg`
- Hover
  - Background：`--color-overlay-surface-keycap-bg-hover`
- Pressed
  - Background：`--color-overlay-surface-keycap-bg-pressed`

##### Popover Surface

- Default
  - Background：`--color-popover-surface-keycap-bg`
- Hover
  - Background：`--color-popover-surface-keycap-bg-hover`
- Pressed
  - Background：`--color-popover-surface-keycap-bg-pressed`

##### Player Chrome

- Default
  - Background：`--color-player-keycap-bg`

## 2.9 Feedback

### C-09.1 Toast

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-control`
  - Border Width：`--border-width-control`
  - Radius：`--radius-toast`
  - Shadow：`--shadow-popover`
- Icon
  - Presence：Optional
  - Color：`--color-text-secondary`
  - 与 Message 第一行垂直居中
- Message
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-toast`
  - Line Height：`--line-height-toast`
  - Font Weight：`--font-weight-toast`
  - Color：`--color-text-secondary`
  - 超出可用宽度换行，各行左对齐，不进入 Icon 所占宽度

##### Motion

- Duration：`--duration-toast-motion`
- Content Duration：`--duration-toast-content`
- Height Duration：`--duration-toast-height`
- Distance：`--distance-toast-motion`
- Easing：`--easing-toast-motion`

##### Presentation Inputs

- Position
  - Default：Bottom Right
- Duration
  - Default：`1.5s`（轻提示）/ `3s`（报错与警示）
- Motion
  - Default：Toast Motion

##### Sizes

- Width：`--width-toast`
- Icon Size：`--size-toast-icon`
- Padding Inline：`--padding-control-x`
- Padding Block：`--spacing-4`
- Icon to Message Gap：`--spacing-2`

##### States

- Entering
- Visible
- Exiting

### C-09.2 Empty State

#### Shared

##### Anatomy

- Icon：68×68px 双色调大图标（`search-hint`、`collage-hint`、`excerpt-hint` 与 `folder-hint` 为系统强调色，其余 9 枚为中性灰色系，角标区域镂空透底，详见 [`Empty State Icon Registry.md`](Empty%20State%20Icon%20Registry.md)）
  - `search-hint`：圆角卡片底板（`--color-empty-icon-search-card`）+ 5 段水平文本线（`--color-empty-icon-search-line`）+ 右下镂空放大镜（镜面 `--color-empty-icon-magnifier-fill`，外圈与手柄 `--color-card-icon-accent-foreground`）
  - `collage-hint`：右上后景叠层圆角框（`--color-empty-icon-collage-back`，被前景框带间隙镂空裁切）+ 左下前景相框底板（`--color-empty-icon-search-card`）+ 左上太阳圆点（`--color-empty-icon-search-line`）+ 底部双峰山脉剪影（`--color-card-icon-accent-foreground`）
  - `excerpt-hint`：强调色单层圆角燕尾书签底板（`--color-empty-icon-collage-back`）
  - `folder-hint`：强调色文件夹后盖顶签（`--color-card-icon-accent-folder-tab`）+ 前盖主体（`--color-card-icon-accent-base`）
  - `search-no-results`：圆角卡片底板（`--color-empty-icon-base`）+ 左上圆头 `✕` 号（`--color-empty-icon-foreground`）+ 右下镂空放大镜（镜面 `--color-empty-icon-badge-fill`，外圈与手柄 `--color-empty-icon-foreground`）
  - `video`：圆角视频框底板（`--color-empty-icon-base`）+ 居中实心播放三角（`--color-empty-icon-foreground`）
  - `excerpt`：单层圆角燕尾书签底板（`--color-empty-icon-mid`）
  - `folder`：文件夹后盖顶签（`--color-empty-icon-mid`）+ 前盖主体（`--color-empty-icon-base`）
  - `folder-question`：`folder` 右下角镂空叠加圆环 `?` 角标（圆内填充 `--color-empty-icon-badge-fill`，外圈与问号 `--color-empty-icon-foreground`）
  - `video-question`：`video` 右下角镂空叠加圆环 `?` 角标
  - `excerpt-question`：`excerpt` 右下角镂空叠加圆环 `?` 角标
  - `subtitle-question`：圆角字幕卡片底板（`--color-empty-icon-base`）+ 两排圆头实心字幕横条（`--color-empty-icon-foreground`）+ 右下镂空叠加圆环 `?` 角标
  - `task-tray`：圆角托盘底板（`--color-empty-icon-base`）+ 中下部内凹折线分割线（`--color-empty-icon-foreground`）
- Message
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-body`
  - Font Weight：`400`
  - Text Color：`--color-text-muted`
- Action
  - Presence：Optional（无文件夹引导空状态、File 一级空状态与 Excerpt 一级无摘录集空状态显示）
  - Component：Button / Neutral

##### Sizes

- Width：跟随所在页面、弹窗或浮层的内容区宽度（不单独设窄上限），高度随内容自适应
- Icon Size：`--size-empty-state-icon`
- Icon to Text Gap：`--gap-empty-state-icon-to-text`
- Message to Action Gap：`--gap-empty-state-icon-to-text`
- Alignment：在承载容器剩余可用空间内水平、垂直居中

##### States

- Default

### C-09.3 Progress Indicator

#### Variants

##### Bar

- Track Color：`--color-library-progress-track`
- Fill Color：`--color-library-progress-fill`
- Height：`--height-task-progress-bar`
- Radius：Capsule
- States
  - Determinate

### C-09.4 Spinner

#### Shared

##### Anatomy

- Track
  - Shape：Ring
  - Color：`--color-spinner-track`
- Indicator
  - Shape：四分之一圆弧
  - Color：`--color-spinner-indicator`

##### Sizes

- Size：`--size-spinner`
- Stroke Width：`--width-spinner-stroke`

##### Motion

- Type：Indicator Continuous Rotation；Track 静止
- Duration：`--duration-spinner-motion`
- Easing：`--easing-spinner-motion`

##### States

- Indeterminate

### C-09.5 Playback Feedback

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-menu-bg`
  - Border：None
  - Radius：`--radius-playback-feedback`
  - Shadow：None
- Icon
  - Presence：Optional
  - Color：`--color-player-text-primary`
  - 与 Label 第一行垂直居中
- Spinner
  - Presence：Optional（仅加载态显示，位于 Label 左侧并与第一行垂直居中）
  - Track Color：`--color-playback-feedback-spinner-track`
  - Indicator Color：`--color-playback-feedback-spinner-indicator`
- Label
  - Presence：Required（加载态文案为 `Loading`）
  - Font Size：`--font-size-playback-feedback`
  - Line Height：`--line-height-playback-feedback`
  - Font Weight：`--font-weight-control`
  - Color：`--color-player-text-primary`
  - 数字等宽；超出最大宽度换行，各行左对齐，不进入 Icon / Spinner 所占宽度

##### Motion

- None（瞬时显隐）

##### Presentation Inputs

- Duration

##### Sizes

- Width：随内容，不超过 Maximum Width
- Icon Size：`--size-playback-feedback-icon`
- Spinner Size：`--size-playback-feedback-spinner`
- Padding Inline：`--padding-control-x`
- Padding Block：`--spacing-2`
- Icon to Label Gap：`--spacing-3`
- Maximum Width：`--width-playback-feedback-max`
- Viewport Margin Inline：`--spacing-6`

##### States

- Hidden
- Visible

### C-09.6 Player Error Banner

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-error-bg`
  - Border：None
  - Radius：`--radius-player-error`
  - Shadow：None
- Line Stack
  - 视频那一行在上，字幕那一行在中间，无效项那一行在最下；只有一条时框内只有一行
- Line
  - Icon
    - Icon：`warning`
    - Size：`--size-player-error-icon`
    - Color：`--color-player-error-content`
    - 与 Message 第一行垂直居中
  - Message
    - Font Family：`--font-family-base`
    - Font Size：`--font-size-player-error`
    - Line Height：`--line-height-player-error`
    - Font Weight：`--font-weight-control`
    - Color：`--color-player-error-content`
    - 完整绝对路径不截断，超出最大宽度换行，各行左对齐，不进入 Icon 所占宽度

##### Motion

- Duration：`--duration-toast-motion`
- Easing：`--easing-toast-motion`

##### Presentation Inputs

- Duration
  - Default：`5s`
- Motion
  - Default：Toast Motion

##### Sizes

- Width：随内容，不超过 Maximum Width
- Maximum Width：窗口宽度减两侧各一个 `--spacing-6`
- Padding Inline：`--padding-player-error-x`
- Padding Block：`--padding-player-error-y`
- Icon to Message Gap：`--spacing-2`
- Line Gap：`--spacing-2`

##### States

- Hidden
- Entering
- Visible
- Exiting

## 2.10 Dialogs

### C-10.1 Dialog

#### Shared

##### Anatomy

- Scrim
  - Color：`--color-dialog-scrim`
  - 覆盖整个窗口，红绿灯除外；系统文件选择框与系统警告框打开期间退让为系统压暗，并在开始收起时同步恢复淡入，保持背景压暗连续
- Container
  - Placement：窗口正中
  - Background：`--color-bg-dialog`
  - Radius：`--radius-dialog`
  - Shadow：`--shadow-dialog`
  - Outline：`--color-dialog-outline`，容器外侧 1 物理像素
  - Edge Highlight：`--color-dialog-edge-highlight`，容器内侧 `1px`
- Header
- Content
- Footer
- Close Button
  - Placement：容器右上角，不占 Header 行
  - Component：Icon Button / Dialog Close

##### Sizes

- Width：`--width-dialog-small`、`--width-dialog-medium`、`--width-dialog-large`、`--width-dialog-x-large` 之一；超过窗口宽度减两侧 `--spacing-6` 时取该值
- Height：Layout 未规定时随内容；超过窗口高度减上下 `--spacing-6` 时取该值，Header 与 Footer 不动，其间内容滚动，滚动条不遮挡内容
- Visual Inset：`--inset-dialog`，四边相等
  - 量到看得见的边：文字的水平边取文本框边缘，文字的上边取 cap 顶；有边框或背景的控件取可见边缘；纯图标按钮取图标字形的墨迹边缘
  - 覆盖：标题与正文的左缘、正文的折行边界、最右侧按钮的右缘、最下方按钮的下缘、关闭按钮字形的右缘与顶缘

##### Motion

- 打开：历时 `--duration-dialog-motion`。Scrim 按 `--easing-dialog-scrim` 淡入；Container 从上方 `--distance-dialog-motion` 处按 `--easing-dialog-enter` 滑入，并在 `--duration-dialog-fade-in` 内按 `--easing-dialog-fade-in` 淡入至完全显示
- 关闭：历时 `--duration-dialog-motion`。Scrim 按 `--easing-dialog-scrim` 淡出；Container 按 `--easing-dialog-exit` 反向滑回上方 `--distance-dialog-motion` 处，并在 `--duration-dialog-fade-out` 内按 `--easing-dialog-fade-out` 淡出
- 叠加同步：Scrim（含系统面板交替时的显隐与 `Covered` 遮罩）均按 `--easing-dialog-scrim` 历时 `--duration-dialog-motion` 平滑过渡
- 减少动态效果：系统开启 Reduce Motion 时，Scrim 与 Container 统一退化为历时 `--duration-dialog-reduce-motion` 的原位纯淡入淡出，不发生位移
- Container 连同阴影、边线与内部内容保持整体统一过渡

##### States

- Closed
- Open
- Covered
  - 触发：上层对话框打开
  - Container 上叠加 Scrim，页面不重复压暗
- Disabled

### C-10.2 Confirmation Dialog

#### Shared

##### Anatomy

- Container：Dialog
- Title
- Message
- Cancel Action：Button / Neutral
- Confirm Action
  - Component：Button
  - Variant：Primary or Destructive

##### Sizes

- Action Gap：`--spacing-4`

##### States

- Closed
- Open
- Confirm Disabled
- Submitting

## 2.11 Media

### C-11.1 Cover

#### Shared

##### Anatomy

- Cover Region
  - Aspect Ratio：`--aspect-library-cover`
  - Radius：`--radius-library-cover`
  - Placeholder Background：`--color-library-cover-placeholder-bg`
- Image
- Placeholder
- Badge Slot
  - Presence：Optional
  - Placement：左下角，距左、下边缘各 `--spacing-2`（位于 Progress Slot 上方）
- More Action Slot
  - Component：Icon Button / Default（Icon `dots-three`（Fill））
  - Placement：右下角，距右、下边缘各 `--spacing-2`（与 Badge Slot 同一水平高度）
  - Presence：仅在所属卡片指针 Hover 或通过该按钮打开菜单期间显示；Disabled 态不显示
- Progress Slot
  - Presence：Optional

##### Sizes

- Aspect Ratio：`--aspect-library-cover`

##### Editor Action

- Default Content：Loaded Cover or Default Cover
- Hover
  - Overlay：Full Cover
  - Overlay Color：`--color-library-cover-edit-overlay`
  - Radius：`--radius-library-cover`
  - Icon：Edit
  - Icon Size：`--size-library-cover-edit-overlay-icon`
  - Label：`Choose Image`
  - Content Color：`--color-library-cover-edit-overlay-content`
  - Content Layout：Icon above Label
  - Content Gap：`--spacing-2`
  - Content Alignment：Center
- Focused
  - Additional Visual：None
- Crop Editing
  - Component：Cover Crop Editor
  - Hover Overlay：None

##### States

- No Cover
- Default Cover
- Loading：透明空白（隐藏 Badge Slot 与 Progress Slot）
- Loaded：底图、Badge Slot 与 Progress Slot 同步显示
- Disabled

### C-11.2 Cover Summary

#### Structure

1. Cover
2. Content
   1. Title
   2. Supporting Content
      1. Primary Metadata
      2. Secondary Metadata
   3. Progress（Optional，仅 Resume 态显示）
      1. Progress Label
      2. Progress Bar
   4. Action Row
      1. Resume or Play Action
         - Split Form：Button / Primary
         - Backdrop Form：Button / Cover Summary
      2. Secondary Action（Optional）
         - Split Form：Button / Neutral
         - Backdrop Form：Button / Cover Summary
      3. More Action
         - Icon：`dots-three`
         - Split Form：Button / Neutral（`--height-control` × `--height-control`）
         - Backdrop Form：Button / Cover Summary（`--height-control` × `--height-control`）

#### Sizes

- Width：Parent Available Width
- Form Switch Width：`--width-cover-summary-form-switch`
- Content Height：两种形态相同，等于 Split Form 的 Cover Height
- Title to Supporting Content Gap：`--gap-cover-summary-title-meta`
- Supporting Content Line Gap：`--gap-cover-summary-meta-lines`
- Progress Label to Track Gap：`--gap-cover-summary-progress-label`
- Progress Width：`--width-cover-summary-progress`
- Progress Track Height：`--height-cover-summary-progress-track`
- Progress to Action Row Gap：`--gap-cover-summary-progress-actions`
- Action Row Gap：`--spacing-4`
- Split Form
  - Cover Size：`--width-cover-summary-split-cover` with `--aspect-library-cover`
  - Cover Radius：`--radius-library-cover`
  - Cover to Content Gap：`--gap-cover-summary-split`
  - Content Minimum Width：`--min-width-cover-summary-split-content`
  - Height：Cover Height
- Backdrop Form
  - Height：`--height-cover-summary-backdrop`
  - Radius：`--radius-cover-summary`
  - Content Width：`min(Padded Available Width, clamp(--min-width-cover-summary-content, --preferred-width-cover-summary-content, --max-width-cover-summary-content))`
  - Content Padding Inline：`--padding-cover-summary-backdrop-inline`
  - Content Padding Block：`--padding-cover-summary-backdrop-block`

#### Layout

- 可用宽度不小于 Form Switch Width 时使用 Split Form，否则使用 Backdrop Form。
- Split Form：Cover 在左并锁定尺寸，Content 在右占满剩余宽度，无背景与 Scrim。
- Backdrop Form：Cover 填满组件边界并由组件 Radius 裁切，Content 压在 Cover 上。
- Cover 保持原始比例，使用 Aspect Fill 与 Center Crop，Hover 时不显示封面编辑遮罩。
- Backdrop Form 高度固定，最窄宽度下不裁剪，宽度越大上下裁剪越多。
- 两种形态的 Content 高度相同，Title 与 Supporting Content 在上，Progress 与 Action Row 在左下角（无 Progress 时 Action Row 保持贴底对齐）。
- 形态切换时组件高度只变化一次，不随宽度连续变化。
- 禁止拉伸、补边、扩图、镜像、重绘或修改封面文件。
- Content 位于左侧并保持左对齐。
- Progress Track 与 Fill 使用 Capsule 圆角；Split Form 下 Track 为 `--color-border-control`、Fill 为 `--color-library-progress-fill`；Backdrop Form 下 Track 为 `--color-cover-summary-text`（`24%` 不透明度）、Fill 为 `--color-cover-summary-text`。
- Backdrop Form 的 Scrim 覆盖左侧文字区域，并按照 Cover Summary Scrim 从左向右衰减至透明。
- Scrim 默认在 `--cover-summary-scrim-transparent` 位置完全透明。
- 当 Content 右边缘及其 Padding 超过默认透明位置时，Scrim 终点随 Content 延伸，最大不超过组件右边缘；中间渐变位置同比例延展。
- Outer Background and Border：None
- Split Form 分别适配 Light Mode 与 Dark Mode；Backdrop Form 两种模式使用同一套视觉规则。

#### Typography

- Title
  - Font Size：`--font-size-cover-summary-title`
  - Font Weight：`--font-weight-cover-summary-title`
  - Color：Split Form `--color-text-primary`；Backdrop Form `--color-cover-summary-text`
  - Maximum Lines：`1`
- Supporting Content
  - Font Size：`--font-size-body`
  - Line Height：`--line-height-cover-summary-description`
  - Color：Split Form `--color-text-secondary`；Backdrop Form `--color-cover-summary-text` with `--opacity-cover-summary-description`
  - Text Hierarchy：Secondary
  - Each Item Maximum Lines：`1`
  - Each Item Overflow：Tail Truncation
  - Interactive Item Hover：可点击文本在 Hover 时显示与当前文字同色的下划线，Pointer 为 Grab（文本选词与拖拽分流详见 `UI Text Selection Rules.md`）
- Description Detail Popover（当 Secondary Metadata 为未完整显示的描述并点击展开时）
  - Position & Size：首行文字起点及折行宽度与展开前第 2 行重合，外框向左右外扩 `--padding-cover-summary-description-popover-x`、向上下外扩 `--padding-cover-summary-description-popover-y`，下外框最高延伸至 Action Row 下外沿；圆角 `--radius-control`，外边框 `--border-width-control`
  - Surface：Split Form 背景 `--color-bg-popover`、边框 `--color-border-control`、阴影 `--shadow-popover`；Backdrop Form 背景 `--color-cover-summary-description-popover-backdrop-bg`、边框 `--color-cover-summary-text`（`--opacity-cover-summary-button-border`）、阴影 `--shadow-player-overlay`
  - Content & Interaction：字号 `--font-size-body`、行高 `--line-height-cover-summary-description`、颜色同 Supporting Content，保留换行，超出最大高度时右侧悬浮显示 `C-07.1 Scrollbar / Vertical`；点击容器外部或按 `Esc` 收起（遵循菜单模态屏蔽规则）
- Progress Label
  - Font Size：`--font-size-caption`
  - Font Weight：`500`
  - Color：同 Supporting Content
  - Maximum Width：`--width-cover-summary-progress`
  - Maximum Lines：`1`
  - Overflow：Tail Truncation

#### States

- Resume：存在最近播放记录，显示 Progress 区域，主按钮为 `Resume`。
- Play：不存在最近播放记录，隐藏 Progress 区域，主按钮为 `Play`。
- Disabled：没有可播放内容，隐藏 Progress 区域，主按钮为 Disabled 状态的 `Play`。

### C-11.3 Cover Crop Editor

#### Shared

##### Anatomy

- Image Region
- Crop Region
  - Aspect Ratio：`--aspect-library-cover`
  - Border Color：`--color-library-cover-crop-accent`
- Corner Handles
  - Border Color：`--color-library-cover-crop-accent`
  - Fill：`--color-bg-surface`
- Outside Mask
  - Color：`--color-library-cover-crop-mask`

##### Sizes

- Crop Aspect Ratio：`--aspect-library-cover`

##### States

- Default
- Moving
- Resizing
- Disabled

### C-11.4 Cover Progress

#### Shared

##### Anatomy

- Track
  - Color：`--color-library-progress-track`
- Fill
  - Color：`--color-library-progress-fill`

##### Sizes

- Height：`--height-library-progress-bar`

##### States

- Hidden
- In Progress
- Finished
- Unknown Duration

### C-11.5 Media Card

#### Shared

##### Anatomy

- Interaction Surface
  - Radius：`--radius-library-media-card-hover`
  - 判定区域为整张卡片的矩形，四角在内；Radius 只作用于背景外观
  - Pointer：Grab（封面右下角 `dots-three` 按钮除外）
- Content Slot

##### Sizes

- Interaction Padding：`--padding-library-media-card-hover`

##### States

- Default
- Hover
  - Background：`--color-library-media-card-hover-bg`（Workbench 界面 Duration `--duration-library-cover-hover`，easeOut；Playback 界面不带动画）
  - 随所在窗口未遮挡暴露区域内且未隐藏指针的当前位置更新（无论窗口是否获焦；滚动期间按 `300ms` 防抖，键盘/手柄移动 Selected 时立即清除并抑制 Hover 直至鼠标实际移动，菜单或上层界面打开期间冻结，关闭解除冻结后无需移动鼠标立即按当前指针位置重算）；右键点击只触发 Hover，不改变 Selected
- Selected
  - Background：`--color-library-media-card-selected-bg`（不带动画）
  - Playback 界面的卡片网格强制始终保持一张卡片处于 Selected（离开网格或退出无障碍后仍保留）；Workbench 界面的卡片网格无强制常驻 Selected，仅在无障碍光圈位于卡片网格内时联动使对应卡片处于 Selected，脱离网格或退出无障碍后立即取消 Selected
  - 同一张卡片同时处于 Selected 与 Hover 时，只显示 Selected 背景，不叠加
  - 仅初始默认 Selected、无障碍进入/移动及方向键/手柄导航改变 Selected 时，若卡片显示不全则最小滚动使其完整可见，不带动画
- Disabled

## 2.12 Player Controls

### C-12.1 Player Speed Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Label
  - Font Size：`--font-size-player-time`
  - Font Weight：`600`
  - Color：`--color-player-text-primary`
  - 数字等宽

##### Sizes

- Height：`--size-icon-button`
- Padding Inline：`--padding-player-speed-button-x`

##### States

- Default
  - Background：Transparent
- Hover
  - Background：`--color-player-control-bg-hover`
- Pressed
  - Background：`--color-player-control-bg-pressed`
- Open
  - 触发：挂靠的倍速菜单打开
  - Background：`--color-player-control-bg-hover`
- Disabled
  - Text Color：`--color-player-text-tertiary`

### C-12.2 Player Time Display

#### Shared

##### Anatomy

- Current Time
  - 格式：`MM:SS`（达 1 小时为 `HH:MM:SS`）
  - Font Design：Monospaced
  - Font Weight：`600`
  - Color：`--color-player-text-primary`
- Remaining Time
  - 格式：`-MM:SS`（达 1 小时为 `-HH:MM:SS`）
  - Font Design：Monospaced
  - Font Weight：`600`
  - Color：`--color-player-text-primary`

##### Sizes

- Font Size：`--font-size-player-time`

##### States

- Default

### C-12.3 Player Progress Scrubber

#### Shared

##### Anatomy

- Hit Area
- Track
  - Color：`--color-player-progress-track`
- Fill
  - Color：`--color-player-progress-fill`
- Preview Track
  - Color：`--color-player-progress-hover-track`
- Thumb
  - Color：`--color-player-progress-fill`
- Time Capsule
  - Presence：Hover or Dragging
  - Component：Player Progress Time Capsule

##### Sizes

- Hit Area Height：`--height-player-progress-hit-area`
- Track Height：`--height-player-progress-track`
- Hover Track Height：`--height-player-progress-track-hover`
- Thumb Size：`--size-player-progress-thumb`
- Radius：Capsule

##### States

- Default
- Hover
- Dragging
- Disabled
- No Duration

### C-12.4 Player Progress Time Capsule

#### Shared

##### Anatomy

- Thumbnail
  - Radius：`--radius-library-cover`
  - Aspect Ratio：当前视频实际宽高比
  - Content：指示时间点所属的关键帧画面（画面就绪前隐藏，切换关键帧时无过渡替换）
- Container
  - Background：`--color-player-menu-bg`
  - Radius：`--radius-field`
- Time Label
  - 格式：`MM:SS`（达 1 小时为 `HH:MM:SS`）
  - Font Size：`--font-size-player-progress-time`
  - Font Weight：`600`
  - Color：`--color-player-text-primary`

##### Sizes

- Thumbnail Width：`--width-player-progress-thumbnail`
- Thumbnail Bottom to Capsule Gap：`--spacing-1`
- Height：`--height-player-progress-time-capsule`
- Padding Inline：`--padding-player-progress-time-capsule-x`
- Bottom to Hit Area Gap：`--spacing-1`
- Window Edge Clamp Inset：`--spacing-1`（缩略图与时间胶囊以指示位置为中心，靠近窗口左右边缘时各自按自身宽度独立限位）

##### States

- Hidden
- Visible On Hover
- Visible On Drag

### C-12.5 Player Volume Control

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Volume Button：Icon Button / Default
- Slider Track
  - Color：`--color-player-progress-track`
- Slider Fill
  - Color：`--color-player-error-content`
- Slider Thumb
  - Color：`--color-player-error-content`
- Volume Value
  - Font Size：`--font-size-player-time`
  - Font Design：Monospaced
  - Font Weight：`600`
  - Color：`--color-player-text-primary`

##### Sizes

- Height：`--size-icon-button`
- Slider Width：`--width-player-volume-slider`
- Track Height：`--height-player-progress-track`
- Thumb Size：`--size-player-volume-thumb`
- Value Width：`--width-player-volume-value`
- Slider to Value Gap：`--spacing-1`
- Trailing Padding：`--padding-player-volume-trailing`

##### Motion

- Expand / Collapse Duration：`--duration-player-volume-expand`

##### Interaction

- Volume Button Click：Toggle Mute
- Container Hover：Expanded
- Slider Drag：Change Volume

##### States

- Collapsed
  - Background：Transparent
- Expanded
  - Background：`--color-player-control-bg-hover`
- Volume Button Pressed
  - 仅左侧静音喇叭按钮区域（`--size-icon-button` × `--size-icon-button`，圆角 `--radius-control`）Background：`--color-player-control-bg-pressed`；拖拽右侧音量滑块不触发按钮 Pressed
- Muted
- Unmuted
- Dragging
- Disabled

### C-12.6 Player Title

#### Shared

##### Anatomy

- Label
  - Font Size：`--font-size-body`
  - Font Weight：`600`
  - Color：`--color-player-text-primary`
  - Shadow：`--shadow-player-topbar-title`

##### Sizes

- Maximum Width：`--width-player-topbar-title-max`，且不超过顶栏的居中元素可用宽度

##### States

- Default
- Truncated：中间截断，尾部的 ` - 序号` 不省略

### C-12.7 Player Cue Queue Control Bar

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-menu-bg`
  - Border：None
  - Radius：`--radius-player-cue-control-bar`
- Toggle Button（`Auto Pause`、`Auto Switch`）
  - Radius：`--radius-player-cue-control`
  - Label：Font Size `--font-size-caption`，Font Weight `600`
- Gap Stepper
  - Step Buttons（`minus`、`plus`）：Width / Height `--height-player-cue-control`，Radius `--radius-player-cue-control`，Icon Size `--size-player-cue-stepper-icon`
  - Value Label：只读等宽数字（`<N> ms`），Font Size `--font-size-player-time`，Font Weight `600`，居中对齐，不接受输入或聚焦

##### Sizes

- Height：`--height-player-cue-control-bar`
- Padding：`--spacing-1`
- Item Gap：`--spacing-1`
- Control Height：`--height-player-cue-control`
- Toggle Padding Inline：`--padding-player-cue-toggle-x`
- Gap Value Width：`--width-player-cue-gap-value`

##### Interaction

- 与 `Settings -> Play` 中的台词队列播放设置实时双向同步，生效时机与联动约束完全一致（切换下一条或上一条台词时生效；`Auto Pause` 关闭时 `Auto Switch` 自动关闭并进入 `Disabled`；`Auto Switch` 关闭时 `Gap Stepper` 整体进入 `Disabled`）
- 步进按钮步长 `100ms`，范围 `0 ~ 10000 ms`
- 操作本组件内任意控件均不触发 `Playback Feedback` 或 `Toast`

##### States

- Toggle Button
  - Default（Off）：Background `Transparent`；Label `--color-player-text-secondary`
  - Hover（Off）：Background `--color-player-control-bg-hover`；Label `--color-player-text-primary`
  - Open（On，含 Hover）：Background `--color-player-control-bg-hover`；Label `--color-player-text-primary`
  - Pressed：Background `--color-player-control-bg-pressed`；Label `--color-player-text-primary`
  - Disabled：Background `Transparent`；Label `--color-player-text-tertiary`
- Gap Stepper
  - Enabled：Value Label `--color-player-text-primary`；两侧按钮 Default `Transparent`、Hover `--color-player-control-bg-hover`、Pressed `--color-player-control-bg-pressed`，到达 `0 ms` 或 `10000 ms` 边界时对应按钮进入 `Disabled`（图标色 `--color-player-text-tertiary`）
  - Disabled（`Auto Switch` 关闭）：两侧按钮与中间 Value Label 均为 `--color-player-text-tertiary`

## 2.13 Playback Content

### C-13.1 Playback Cue Metadata

#### Shared

##### Anatomy

1. Ordinal
   - Presence：Optional
2. Display Title
3. Time Range

##### Sizes

- Cue Gap：`--spacing-2`
- Item Gap：`--spacing-3`
- Font Family：`--font-family-base`
- Font Size：`--font-size-playback-cue-metadata`
- Line Height：`--line-height-playback-cue-metadata`
- Font Weight：`--font-weight-playback-cue-metadata`

##### Appearance

- Background / Border / Radius / Padding：None

##### States

- Unselected
  - Text Color：`--color-playback-cue-metadata-unselected`
- Selected
  - Text Color：`--color-playback-cue-metadata-selected`

##### Layout

- Placement：Below the complete Visual Line Stack

### C-13.2 Subtitle Focus Cue

#### Shared

##### Anatomy

- Cue Container
- Visual Line Stack
  - Primary Cue Text
- Cue Metadata
  - Presence：Optional
  - Component：Playback Cue Metadata

##### Sizes

- Padding Block：`--padding-subtitle-focus-cue-y`
- Font Family：`--font-family-base`
- Font Size：`--font-size-subtitle-focus-cue`
- Line Height：`--line-height-subtitle-focus-cue`
- Font Weight：`--font-weight-subtitle-focus-cue`
- Internal Visual Line Gap：`--gap-subtitle-focus-internal-line`

##### States

- Unselected
  - Text Color：`--color-subtitle-focus-cue-unselected`
- Selected
  - Text Color：`--color-subtitle-focus-cue-selected`

### C-13.3 Playback Cue Result

#### Shared

##### Anatomy

- Visual Line Stack
  - Primary Cue
  - Cue Group
    - Presence：Optional
- Cue Metadata
  - Presence：Optional
  - Component：Playback Cue Metadata

##### Sizes

- Padding Block：`--padding-subtitle-focus-cue-y`
- Primary Font Size：`--font-size-subtitle-focus-cue`
- Primary Line Height：`--line-height-subtitle-focus-cue`
- Primary Font Weight：`--font-weight-subtitle-focus-cue`
- Cue Group Font Size：`--font-size-subtitle-focus-cue-group`
- Cue Group Line Height：`--line-height-subtitle-focus-cue-group`
- Cue Group Font Weight：`--font-weight-subtitle-focus-cue-group`
- Internal Visual Line Gap：`--gap-subtitle-focus-internal-line`

##### States

- Unselected
  - Primary Color：`--color-subtitle-focus-cue-unselected`
  - Cue Group Color：`--color-subtitle-focus-cue-unselected`
- Selected
  - Primary Color：`--color-subtitle-focus-cue-selected`
  - Cue Group Color：`--color-subtitle-focus-cue-group-selected`

### C-13.4 Playback Cue Reel

#### Shared

##### Anatomy

- Viewport
- Cue Stack
  - Timeline Marker
    - Presence：Optional
  - Cue Content
  - Connector
    - Presence：Optional
- Focus Anchor
- Selected Placement
- Vertical Scrollbar：Scrollbar / Vertical

##### Sizes

- Maximum Content Width：`--width-subtitle-focus-content-max`
- Cue Gap：`--gap-subtitle-focus-cue`
- Marker to Cue Gap：`--spacing-6`
- Connector Width：`--width-playback-cue-timeline-connector`
- Connector to Marker Gap：`--spacing-2`

##### Motion

- Scroll：历时 `--duration-subtitle-focus-scroll`，按 `--easing-subtitle-focus-scroll` 过渡
- Focus Fade：导航使焦点字幕改变时，原 `Selected`（或正在淡入）字幕在 `--duration-subtitle-focus-fade-out` 内按 `--easing-subtitle-focus-fade` 过渡为 `Unselected` 颜色；导航期间所有字幕保持 `Unselected` 颜色，停止导航满 `--delay-subtitle-focus-fade-in` 后，目标字幕在 `--duration-subtitle-focus-fade-in` 内按 `--easing-subtitle-focus-fade` 过渡为 `Selected` 颜色（Primary Cue、Cue Group 与 Playback Cue Metadata 同步过渡）；初始呈现与首尾边界原地导航直接显示 `Selected` 颜色，不播放过渡

##### States

- Empty
- Loading
- Ready
- Scrolling
- Dragging Scrollbar
- Settling

#### Cue Timeline Layout

- Presence：仅当配置 `Timeline Marker` 时显示；未配置时 `Cue Content` 直接与行左边缘对齐
- Leading Element：Timeline Marker
- Vertical Alignment：Timeline Marker 与 Primary Cue 第一视觉行的可见字形中心位于同一水平线
- Connector：Connect Adjacent Timeline Markers
- Connector Color：`--color-playback-cue-timeline-muted`

#### Timeline Marker Variants

##### Collage Selection

- Component：Checkbox / Playback Selection Checkbox
- Size：`--size-playback-collage-checkbox`
- Checkbox Appearance and States：Unchanged

#### Scrollbar Mapping

- Position Domain：Fractional Cue Ordinal
- Cue Weight：Equal

#### Variants

##### Focus Cue Reel

- Cue Content：Subtitle Focus Cue

##### Cue Result Reel

- Cue Content：Playback Cue Result
