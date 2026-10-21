# 说明
1. 本文档由人类维护，定义业务与反馈组件（`C-08` ~ `C-13`）：Data Display、Feedback、Dialogs、Media、Player Controls、Playback Content。
2. 所有组件默认遵守 `/docs/human/design/ui/UI Design Rules.md` 与 `/docs/human/design/ui/UI Interaction Rules.md`。

# 2. Components（Part 2：Domain `C-08` ~ `C-13`）

## 2.8 Data Display

### C-08.1 Watch Status Badge

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

- Unwatched
  - Background：`--color-watch-status-unwatched-bg`
  - Text Color：`--color-watch-status-unwatched-text`
- Watching
  - Background：`--color-watch-status-watching-bg`
  - Text Color：`--color-watch-status-watching-text`
- Finished
  - Background：`--color-watch-status-finished-bg`
  - Text Color：`--color-watch-status-finished-text`
- Disabled
  - Background：`--color-bg-disabled`
  - Text Color：`--color-text-disabled`

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
  - Time
  - Count
  - Hidden

##### Task Count Badge

- Placement：Task Entry 与 Filter Trigger 内图标右侧，按钮随之变宽；与图标字形墨迹的间距为 `--spacing-1`，右侧留白与图标上方留白相同；Filter Dialog 的 Section Header 内名称右侧
- Shape：1 位数为圆形，宽与高相等；2 位及以上为胶囊形，两端为正半圆
- Size：`--size-control-icon`；在 Section Header 内为 `--size-task-count-badge-compact`
- Padding Inline：1 位数为 0；2 位及以上为 `--spacing-2`，在 Section Header 内为 `--padding-task-count-badge-compact-x`
- Background：`--color-badge-neutral-bg`；按钮 Hover 或 Open 时不变
- Font Family：`--font-family-base`
- Font Size：`--font-size-task-count-badge`；在 Section Header 内为 `--font-size-caption`
- Font Weight：`--font-weight-task-count-badge`
- Text Color：`--color-text-secondary`；按钮 Disabled 时为 `--color-text-disabled`
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
- Usage：File `Last Updated`、Search `xx results`、Library `xx folders`、Excerpt `xx lists  yy cues`

##### Cue State Indicator

- Icon Size：`--size-control-icon`
- Icon Color：`--color-text-muted`
- Gap：`--spacing-2`
- States
  - Content Changed：位于目标字幕末行右侧，Hover 显示 `--color-row-selected` 圆角底块
  - Unavailable：占据 `Cues` 列左侧纵向槽位并与目标字幕首行垂直居中，目标字幕与 Cue Group 附加字幕统一右移对齐；Hover 仅填充图标圆圈内部为 `--color-row-selected`

### C-08.6 Tooltip

#### Shared

##### Anatomy

- Container
  - Background：`--color-toast-bg`
  - Border Color：`--color-toast-border`
  - Border Width：`--border-width-control`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Font Weight：`--font-weight-control`
  - Color：`--color-player-text-primary`
- Shortcut
  - Presence：Optional
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Font Weight：`--font-weight-control`
  - Color：`--color-player-text-secondary`
- Content Gap：`--spacing-2`

##### Sizes

- Single-line Height：`--height-control`（多行折行时上下边距与单行一致）
- Padding Inline：`--padding-control-x`
- Maximum Width：`--width-tooltip-max`（仅截断补全文本，超出换行）

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
  - Color：`--color-text-muted`

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
  - 跟随所属 Shortcut Action Button
- Pressed
  - 跟随所属 Shortcut Action Button

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

## 2.9 Feedback

### C-09.1 Toast

#### Shared

##### Anatomy

- Container
  - Background：`--color-toast-bg`
  - Border Color：`--color-toast-border`
  - Border Width：`1px`
  - Radius：`--radius-playback-feedback`
  - Shadow：None
- Icon
  - Presence：Optional
  - Color：`--color-player-text-primary`（纯白色 `#FFFFFF`）
  - 与 Message 第一行垂直居中
- Message
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-toast`
  - Font Weight：`--font-weight-control`
  - Color：`--color-text-primary`
  - 超出最大宽度换行，各行左对齐，不进入 Icon 所占宽度

##### Motion

- Duration：`--duration-toast-motion`
- Easing：`--easing-toast-motion`

##### Presentation Inputs

- Position
  - Default：App Center
- Duration
  - Default：`5s`
- Motion
  - Default：Toast Motion

##### Sizes

- Icon Size：`--size-toast-icon`
- Padding Inline：`--spacing-4`
- Padding Block：`--spacing-3`
- Icon to Message Gap：`--spacing-3`
- Maximum Width：`--width-toast-max`
- Viewport Margin Inline：`--spacing-6`

##### States

- Entering
- Visible
- Exiting

### C-09.2 Empty State

#### Shared

##### Anatomy

- Title
  - Presence：Optional
- Message
- Action
  - Presence：Optional

##### Sizes

##### States

- Default

#### Variants

##### Empty Hint

- Font Family：`--font-family-base`
- Font Size：`--font-size-library-meta`
- Text Color：`--color-text-muted`
- Alignment：Center

##### Info Page State

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
  - Background：`--color-toast-bg`
  - Border Color：`--color-toast-border`
  - Radius：`--radius-playback-feedback`
  - Shadow：None
- Icon
  - Presence：Optional
  - Color：`--color-player-text-primary`
  - 与 Label 第一行垂直居中
- Label
  - Presence：Optional
  - Font Size：`--font-size-playback-feedback`
  - Font Weight：`--font-weight-control`
  - Color：`--color-player-text-primary`
  - 数字等宽；超出最大宽度换行，各行左对齐，不进入 Icon 所占宽度

##### Motion

- Duration：`--duration-toast-motion`
- Easing：`--easing-toast-motion`

##### Presentation Inputs

- Duration
- Motion
  - Default：Toast Motion

##### Sizes

- Minimum Height：`--height-playback-feedback`
- Icon Size：`--size-playback-feedback-icon`
- Padding Inline：`--spacing-4`
- Padding Block：`--spacing-2`
- Icon to Label Gap：`--spacing-3`
- Maximum Width：`--width-playback-feedback-max`
- Viewport Margin Inline：`--spacing-6`

##### States

- Hidden
- Entering
- Visible
- Exiting

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
  - 覆盖整个窗口，红绿灯除外；系统文件选择框与系统警告框打开期间改由系统压暗
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

- 打开：历时 `--duration-dialog-motion`。Scrim 线性淡入；Container 从上方 `--distance-dialog-motion` 处按 `--easing-dialog-motion` 滑入，`--duration-dialog-fade-in` 内完全显示
- 关闭：历时 `--duration-dialog-motion`。Scrim 线性淡出；Container 按同一曲线反向滑回上方，全程淡出
- Container 连同阴影与边线整体淡入淡出

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

- Action Gap：`--spacing-3`

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
- Loading：Skeleton Shimmer (anti-flicker delay `--delay-cover-anti-flicker`)
- Loaded：Crossfade (`--duration-cover-crossfade`)
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
- Action Row Gap：`--spacing-2`
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
  - Color：Split Form `--color-text-secondary`；Backdrop Form `--color-cover-summary-text` with `--opacity-cover-summary-description`
  - Text Hierarchy：Secondary
  - Each Item Maximum Lines：`1`
  - Each Item Overflow：Tail Truncation
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
- Disabled：没有可播放内容。

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
  - Pointer：Grab
- Content Slot

##### Sizes

- Interaction Padding：`--padding-library-media-card-hover`

##### States

- Default
- Selected
  - Background：`--color-library-media-card-hover-bg`
  - Hover 与 Selected 是同一个状态，同一界面内同时只有一张卡片处于该状态
  - 指针真实移动后落在卡片上时随之移动；滚动与布局变化不移动它
  - Workbench 界面允许一张都没有，Playback 界面始终保持一张
  - 菜单或对话框打开期间不随指针移动；右键菜单的关联卡片保持选中
- Disabled

## 2.12 Player Controls

### C-12.1 Player Speed Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Label
  - Font Size：`--font-size-player-time`
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
- Interaction Suppressed

### C-12.2 Player Time Display

#### Shared

##### Anatomy

- Current Time
  - Font Design：Monospaced
  - Color：`--color-player-text-primary`
- Remaining Time
  - 带前导负号 `-`
  - Font Design：Monospaced
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

- Container
  - Background：`--color-player-menu-bg`
  - Radius：`--radius-field`
- Time Label
  - Font Size：`--font-size-player-progress-time`
  - Color：`--color-player-text-primary`

##### Sizes

- Height：`--height-player-progress-time-capsule`
- Padding Inline：`--padding-player-progress-time-capsule-x`
- Bottom to Hit Area Gap：`--spacing-1`

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
- Low
- Medium
- High
- Dragging
- Disabled
- Interaction Suppressed

### C-12.6 Player Title

#### Shared

##### Anatomy

- Label
  - Font Size：`--font-size-body`
  - Color：`--color-player-text-primary`
  - Shadow：`--shadow-player-topbar-title`

##### Sizes

- Maximum Width：`--width-player-topbar-title-max`，且不超过顶栏的居中元素可用宽度

##### States

- Default
- Truncated：中间截断，尾部的 ` - 序号` 不省略

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
  - Pointer：I-beam（可拖选的字幕文字上）
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
