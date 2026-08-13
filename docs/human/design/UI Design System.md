# 说明
1. 本文档由人类维护，作为UI/UX的设计文档。一些细节说明放在/docs/human/design/UI Application Rules.md。约束AI的工程文档和具体代码实现。

# 1. Core Tokens

## 1.1 颜色

### Text

- `--color-text-primary`: Light `#0F172A`; Dark `#F4F4F5`
- `--color-text-secondary`: Light `#404040`; Dark `#D4D4D4`
- `--color-text-muted`: Light `#667085`; Dark `#A1A1AA`
- `--color-text-placeholder`: Light `#98A2B3`; Dark `#71717A`
- `--color-text-disabled`: Light `#98A2B3`; Dark `#71717A`

### Icon

- `--color-icon-default`: Light `#667085`; Dark `#A1A1AA`
- `--color-icon-muted`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-disabled`: Light `#98A2B3`; Dark `#71717A`
- `--color-icon-on-dark`: Light `#FFFFFF`; Dark `#FFFFFF`

### Background

- `--color-bg-surface`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-hover`: Light `#F3F4F6`; Dark `#27272A`
- `--color-bg-disabled`: Light `#F3F4F6`; Dark `#202024`
- `--color-bg-popover`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-app-sidebar-bg`: Light `#F6F7F9`; Dark `#202024`
- `--color-app-sidebar-item-selected-bg`: Light `#FFFFFF`; Dark `#303036`
- `--color-app-topbar-bg`: Light `#FFFFFF`; Dark `#18181B`
- `--color-keycap-bg`: Light `#F3F4F6`; Dark `#27272A`

### Border

- `--color-border-control`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-border-control-hover`: Light `#D1D5DB`; Dark `#52525B`
- `--color-border-muted`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-border-divider`: Light `#E5E7EB`; Dark `#303036`
- `--color-border-disabled`: Light `#E5E7EB`; Dark `#303036`
- `--color-border-checkbox`: Light `#D0D5DD`; Dark `#52525B`

### Accent

- `--color-accent`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-text-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-icon-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-border-active`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-bg-active`: Light `#EBF5FF`; Dark `#14275A`
- `--color-bg-active-hover`: Light `#E1EBFF`; Dark `#1B3470`
- `--color-bg-active-clear-hover`: Light `#D8E8FD`; Dark `#243F7F`

### Focus

- `--color-border-focus`: macOS accent color
- `--color-focus-ring`: macOS accent color with opacity
  - Light Alpha: `0.22`
  - Dark Alpha: `0.30`
- `--focus-ring-width`: `2px`
- `--focus-ring-offset`: `2px`

### Control

- `--color-primary-button-bg`: macOS accent color
- `--color-primary-button-bg-hover`: macOS accent color with native hover emphasis
- `--color-primary-button-text`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-bg-checkbox-unchecked`: Light `#FFFFFF`; Dark `#18181B`
- `--color-bg-checkbox-checked`: Light `#667085`; Dark `#A1A1AA`
- `--color-checkbox-icon`: Light `#FFFFFF`; Dark `#18181B`
- `--color-danger-text`: Light `#B42318`; Dark `#FCA5A5`
- `--color-danger-bg-hover`: Light `#FEF3F2`; Dark `#3A1717`

### Table

- `--color-row-hover`: Light `#F9FAFB`; Dark `#202024`
- `--color-row-selected`: Light `#F3F4F6`; Dark `#27272A`

### Status

- `--color-chip-language-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-chip-language-text`: Light `#0040FF`; Dark `#93C5FD`
- `--color-watch-status-unwatched-bg`: Light `#F3F4F6`; Dark `#27272A`
- `--color-watch-status-unwatched-text`: Light `#667085`; Dark `#A1A1AA`
- `--color-watch-status-watching-bg`: Light `#DBEAFE`; Dark `#172A4A`
- `--color-watch-status-watching-text`: Light `#0040FF`; Dark `#93C5FD`
- `--color-watch-status-finished-bg`: Light `#D1FAE5`; Dark `#123A2A`
- `--color-watch-status-finished-text`: Light `#047857`; Dark `#6EE7B7`

### Scrollbar

- `--color-scrollbar-thumb-default`: Light `#CBD5E1`; Dark `#52525B`
- `--color-scrollbar-thumb-interactive`: Light `#94A3B8`; Dark `#71717A`
- `--color-scrollbar-track`: Light `transparent`; Dark `transparent`

### Library Media

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

### Cover Summary

- `--color-cover-summary-scrim`: Light `#000000`; Dark `#000000`
- `--color-cover-summary-text`: Light `#FFFFFF`; Dark `#FFFFFF`

### Player Chrome

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

### Subtitle Focus

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

## 1.2 字体与文本

### Typography

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
- `--font-size-cover-summary-title`: `28px`
- `--font-weight-cover-summary-title`: `700`

### Text Decoration

- `--width-interactive-text-underline`: `1px`
- `--offset-interactive-text-underline`: `2px`

## 1.3 尺寸

### Height

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
- `--height-cover-summary`: `252px`
- `--height-cue-facet-filter-panel-pinned`: `244px`
- `--height-keycap`: `22px`

### Size

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
- `--min-width-cover-summary-content`: `448px`
- `--max-width-cover-summary-content`: `720px`
- `--preferred-width-cover-summary-content`: `50%`
- `--width-library-recent-card-min`: `180px`
- `--width-library-recent-card-max`: `220px`
- `--width-library-episode-row-min`: `380px`
- `--width-library-list-cover`: `204px`
- `--width-library-folder-cover`: `120px`
- `--min-height-library-folder-card`: `96px`

## 1.4 间距

### Spacing

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
- `--gap-cover-summary-to-toolbar`: `24px`

### Padding

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
- `--padding-cover-summary-content`: `40px`

## 1.5 形状与效果

### Radius

- `--radius-control`: `8px`
- `--radius-field`: `8px`
- `--radius-search`: `9999px`
- `--radius-inline-clear-button`: `9999px`
- `--radius-checkbox`: `9999px`
- `--radius-menu`: `16px`
- `--radius-select-menu-item`: `8px`
- `--radius-action-menu-item`: `8px`
- `--radius-row-action`: `8px`
- `--radius-table-cell-hover`: `8px`
- `--radius-chip`: `6px`
- `--radius-keycap`: `4px`
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
- `--radius-cover-summary`: `16px`

### Shadow

- `--shadow-popover`:
  - Light: `0 12px 24px rgba(15,23,42,0.12)`
  - Dark: `0 12px 24px rgba(0,0,0,0.36)`
- `--shadow-player-overlay`:
  - Light: `0 12px 24px rgba(0,0,0,0.42)`
  - Dark: `0 12px 24px rgba(0,0,0,0.42)`
- `--shadow-player-topbar-title`:
  - Light: `0 1px 2px rgba(0,0,0,0.50)`
  - Dark: `0 1px 2px rgba(0,0,0,0.50)`

### Cover Summary Scrim

- Color：`--color-cover-summary-scrim`
- Direction：Left to Right
- `--cover-summary-scrim-leading`: Location `0%`; Opacity `62%`
- `--cover-summary-scrim-strong`: Location `24%`; Opacity `54%`
- `--cover-summary-scrim-middle`: Location `43%`; Opacity `34%`
- `--cover-summary-scrim-trailing`: Location `58%`; Opacity `12%`
- `--cover-summary-scrim-transparent`: Location `70%`; Opacity `0%`

### Cover Summary Content Opacity

- `--opacity-cover-summary-description`: `76%`
- `--opacity-cover-summary-button-bg`: `14%`
- `--opacity-cover-summary-button-bg-hover`: `24%`
- `--opacity-cover-summary-button-border`: `35%`
- `--opacity-cover-summary-button-disabled`: `55%`

## 1.6 动效

### Interaction Motion

- `--scale-library-media-card-pressed`: `0.98`
- `--scale-library-cover-hover`: `1.02`
- `--duration-library-cover-hover`: `0.12s`

### Toast Motion

- `--duration-toast-motion`: `0.20s`
- `--easing-toast-motion`: `cubic-bezier(0.22, 1, 0.36, 1)`

### Spinner Motion

- `--duration-spinner-motion`: `1s`
- `--easing-spinner-motion`: `linear`

### Subtitle Focus Motion

- `--duration-subtitle-focus-scroll`: `0.22s`
- `--easing-subtitle-focus-scroll`: `cubic-bezier(0.22, 1, 0.36, 1)`

# 2. Components

## 2.1 Inputs

### Shared

#### Focus Treatment

- Indicator：Border Color Only
- Focus Ring：None
- Focused Geometry：Same size, radius, padding, and layout as unfocused state
- Error Priority：Danger Border overrides Focus Border

### Text Field

#### Shared

##### Anatomy

- Label
- Validation Message
  - Presence：Optional
- Container
  - Background：`--color-bg-surface`
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

### Text Area

#### Shared

##### Anatomy

- Label
- Validation Message
  - Presence：Optional
- Container
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Radius：`--radius-field`
- Multiline Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
- Placeholder
  - Color：`--color-text-placeholder`
- Text Content Origin
  - Applies To：Placeholder, Insertion Point, First Text Line
  - Rule：Shared
- Vertical Scrollbar
  - Component：Scrollbar / Vertical
  - Visibility：Inherit Scrollbar Visibility

##### Sizes

- Height：`--height-form-text-area`
- Padding Inline：`--padding-field-x`
- Padding Block：`10px`

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

### Search Field

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Radius：`--radius-search`
- Search Icon
  - Size：`--size-control-icon`
  - Color：`--color-icon-default`
- Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
- Placeholder
  - Color：`--color-text-placeholder`
- Result Count
  - Presence：Optional
  - Font Size：`--font-size-control`
  - Color：`--color-text-muted`
- Clear Action
  - Presence：Optional
  - Component：Icon Button
- Content Gap：`--spacing-2`

##### Sizes

- Height：`--height-filter-bar-control`
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
  - Icon Color：`--color-icon-disabled`

### Number Field

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Radius：`--radius-field`
- Numeric Input
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Color：`--color-text-primary`
  - Text Alignment：Trailing
  - Digit Style：Monospaced
- Unit Label
  - Presence：Optional
  - Placement：Inside Container
  - Current Value：`ms`
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

## 2.2 Selection Controls

### Checkbox

#### Shared

##### Anatomy

- Control
  - Shape：Circle
  - Rendering：SF Symbols / Monochrome
  - Symbol Weight：Regular
  - Size：`--size-checkbox`
- Indicator
- Label
  - Presence：Optional

##### Sizes

- Control Size：`--size-checkbox`
- Symbol Size：Control Size

##### States

- Unchecked
  - System Symbol：`circle`
  - Background：`--color-bg-checkbox-unchecked`
  - Border Color：`--color-border-checkbox`
- Checked
  - System Symbol：`checkmark.circle.fill`
  - Background：`--color-bg-checkbox-checked`
  - Indicator Color：`--color-checkbox-icon`
- Indeterminate
  - System Symbol：`minus.circle.fill`
  - Background：`--color-bg-checkbox-checked`
  - Indicator Color：`--color-checkbox-icon`
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Control Color：`--color-icon-disabled`
  - Label Color：`--color-text-disabled`

#### Variants

##### Filter Checkbox

- Hit Area：Option Row
- Hover：None
- Focus Ring：None

##### Table Selection Checkbox

- Hit Area：Containing Row

##### Playback Selection Checkbox

- Hit Area：Entire Playback Cue Item
- Hover：None
- Focus Ring：None
- Control Size：`--size-playback-collage-checkbox`

### Switch

#### Shared

##### Anatomy

- Platform Native Switch
- Label
  - Presence：Optional

##### Sizes

- Platform Native

##### States

- Platform Native

## 2.3 Buttons

### Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Leading Icon
  - Presence：Optional
  - Size：`--size-button-icon`
  - Weight：`--weight-button-icon`
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
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-icon-default`
- Hover
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Focused
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

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
  - Icon Color：`--color-icon-disabled`

##### Destructive

- Default
  - Background：Transparent
  - Border：None
  - Label Color：`--color-danger-text`
  - Icon Color：`--color-danger-text`
- Hover
  - Background：`--color-danger-bg-hover`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

### Icon Button

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

##### States

- Default
  - Background：Transparent
  - Icon Color：`--color-icon-default`
- Hover
  - Background：`--color-bg-hover`
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Background：Transparent
  - Icon Color：`--color-icon-disabled`

### Toolbar Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-control`
- Leading Icon
  - Size：`--size-button-icon`
  - Weight：`--weight-button-icon`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-control`
  - Font Weight：`--font-weight-control`
- Trailing Indicator
  - Presence：Optional
- Content Gap：`--spacing-2`

##### Sizes

- Height：`--height-filter-bar-control`
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

##### Action

- Trailing Indicator：None
- Default
  - Background：Transparent
  - Border：None
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-icon-default`
- Hover
  - Background：`--color-bg-hover`
- Disabled
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

##### Panel Trigger

- Trailing Indicator
  - Size：`--size-select-indicator`
  - Weight：`--weight-select-indicator`
- Default
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-icon-default`
- Hover
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Open
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Focused
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

##### Mode Toggle

- Trailing Indicator：None
- Default
  - Background：`--color-bg-surface`
  - Border Color：`--color-border-control`
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-icon-default`
- Hover
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
- Active
  - Background：`--color-bg-hover`
  - Border Color：`--color-border-control-hover`
  - Label Color：`--color-text-primary`
  - Icon Color：`--color-icon-default`
- Focused
  - Border Color：`--color-border-focus`
- Disabled
  - Background：`--color-bg-disabled`
  - Border Color：`--color-border-disabled`
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

## 2.4 Menus

### Menu

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

##### Sizes

- Padding：`--padding-menu-item`

##### States

- Closed
- Open

#### Variants

##### Dropdown Menu

##### Context Menu

### Submenu

#### Shared

##### Anatomy

- Trigger：Menu Item / Submenu Trigger
- Menu Surface：Menu

##### States

- Closed
- Open
- Highlighted
- Disabled

### Menu Item

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

- Padding Inline：`--padding-menu-item`

##### States

- Default
  - Label Color：`--color-text-primary`
- Highlighted
  - Background：`--color-bg-hover`
- Disabled
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

#### Variants

##### Action Menu Item

- Leading Slot：Icon / Empty
- Trailing Slot：Shortcut / Empty
- Height：`--height-action-menu-item`
- Radius：`--radius-action-menu-item`

##### Radio Menu Item

- Leading Slot：Selection Indicator
- Indicator Slot：Always Reserved
- Selected：Indicator Visible
- Unselected：Indicator Hidden
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
  - Icon Color：`--color-icon-disabled`

##### Submenu Trigger

- Trailing Slot：Submenu Indicator

### Menu Divider

#### Shared

##### Anatomy

- Divider
  - Color：`--color-border-divider`

##### Sizes

##### States

## 2.5 Navigation

### Sidebar

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

### Sidebar Toggle

#### Shared

##### Anatomy

- Container：Icon Button
- Icon：Platform Native Sidebar Toggle

##### Sizes

- Width：`--size-icon-button`
- Height：`--size-icon-button`
- Icon Size：`--size-control-icon`

##### States

- Default
- Hover
- Focused
- Disabled

### Sidebar Item

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-app-sidebar-item`
- Leading Icon
  - Presence：Optional
  - Size：`--size-app-sidebar-item-icon`
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-app-sidebar-item`
- Trailing Indicator
  - Presence：Optional
- Content Gap：`--spacing-3`

##### Sizes

- Height：`--height-app-sidebar-item`
- Padding Inline：`--padding-app-sidebar-item-x`

##### States

- Default
- Hover
- Selected
  - Background：`--color-app-sidebar-item-selected-bg`
- Expanded
- Collapsed
- Disabled
  - Label Color：`--color-text-disabled`
  - Icon Color：`--color-icon-disabled`

#### Variants

##### Primary

- Leading Icon：Required
- Trailing Indicator：Optional

##### Child

- Leading Icon：None
- Indentation：Required

##### Action

- Leading Icon：Required
- Selection：None

### Tabs

#### Shared

##### Anatomy

- Tab List
- Selection Indicator

##### Sizes

##### States

- Default
- Disabled

### Tab

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-app-sidebar-item`
- Leading Icon
  - Presence：Optional
- Selection Indicator

##### Sizes

##### States

- Unselected
  - Label Color：`--color-text-muted`
- Hover
- Selected
  - Label Color：`--color-text-primary`
  - Indicator Color：`--color-accent`
- Focused
- Disabled
  - Label Color：`--color-text-disabled`

## 2.6 Tables

### Table

#### Shared

##### Anatomy

- Header
- Body Viewport
- Rows
- Vertical Scrollbar：Scrollbar / Vertical
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

##### Vertical

- Position Domain：Body Content Offset
- Extent Domain：Body Content Length

##### Horizontal

- Position Domain：Content Offset
- Extent Domain：Content Width

### Table Header Cell

#### Shared

##### Anatomy

- Trigger Surface
- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-table-header`
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
- Hover
- Focused
- Disabled

#### Variants

##### Sortable

- Trailing Slot：Sort Indicator
- States
  - Unsorted
  - Ascending
  - Descending

##### Selection

- Checkbox：Checkbox / Table Selection Checkbox
- Alignment：Horizontal Center / Vertical Center
- States
  - None Selected
  - Partially Selected
  - All Selected

### Table Row

#### Shared

##### Anatomy

- Row Container
- Cell Stack
- Selection Slot
  - Presence：Select Mode

##### Sizes

- Minimum Height：`--min-height-table-row`
- Padding Block：`--padding-table-row-y`

##### States

- Default
- Hover
  - Background：`--color-row-hover`
- Selected
  - Background：`--color-row-selected`
- Disabled

### Table Cell

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
- Color：`--color-text-primary`
- Selection：Enabled

##### Interactive Text

- Font Family：`--font-family-base`
- Font Size：`--font-size-table`
- Color：`--color-text-primary`
- Hover Region
  - Padding Inline：`--padding-table-cell-hover-x`
  - Padding Block：`--padding-table-cell-hover-y`
  - Radius：`--radius-table-cell-hover`
- Selection：Enabled
- States
  - Default
  - Hover
  - Focused
  - Disabled

### Selection Action Overlay

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Selected Count Slot
- Action Slots

##### Sizes

- Content Gap：`--spacing-2`
- Padding：`--spacing-3`

##### States

## 2.7 Scrollbars

### Scrollbar

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

## 2.8 Data Display

### Watch Status Badge

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

### Information Badge

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

##### Playback Information Badge

- Height：`--height-playback-cue-information-badge`
- Radius：`--radius-chip`
- Padding Inline：`--padding-chip-x`
- Padding Block：`--padding-chip-y`
- Font Family：`--font-family-base`
- Font Size：`--font-size-caption`
- States
  - Selected
    - Background：`--color-playback-information-badge-bg`
    - Text Color：`--color-playback-information-badge-text`
  - Unselected
    - Background：`--color-playback-information-badge-unselected-bg`
    - Text Color：`--color-playback-information-badge-unselected-text`

### Tag

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

### Status Indicator

#### Shared

##### Anatomy

- Indicator

##### Sizes

##### States

- Default
- Disabled

#### Variants

##### Cue State Indicator

- States
  - Content Changed
  - Unavailable

### Tooltip

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Content

##### Sizes

##### States

- Hidden
- Visible

#### Variants

##### Cue State Tip

- Indicator
- Title
- Message
- Previous Value
  - Presence：Optional
- Current Value
  - Presence：Optional
- Unavailable Reason
  - Presence：Optional
- Content Gap：`--spacing-2`

### Section Title

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

### Keycap

#### Shared

##### Anatomy

- Container
  - Background：`--color-keycap-bg`
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

### Keycap Group

#### Shared

##### Anatomy

- Items：Keycap
- Separator
  - Presence：Optional

##### Sizes

- Item Gap：`--spacing-1`

##### States

- Default

## 2.9 Feedback

### Toast

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Message
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-body`
  - Color：`--color-text-primary`

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

- Padding Inline：`--spacing-4`
- Padding Block：`--spacing-3`
- Viewport Margin Inline：`--spacing-6`

##### States

- Queued
- Entering
- Visible
- Timer Paused
- Exiting

### Empty State

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

### Progress Indicator

#### Shared

##### Anatomy

- Spinner
  - Color：`--color-icon-muted`

##### Sizes

- Size：`--size-control-icon`

##### Motion

- Type：Continuous Rotation
- Duration：`--duration-spinner-motion`
- Easing：`--easing-spinner-motion`

##### States

- Indeterminate

### Playback Feedback

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Icon
  - Presence：Optional
- Label
  - Presence：Optional

##### Motion

- Duration：`--duration-toast-motion`
- Easing：`--easing-toast-motion`

##### Presentation Inputs

- Position
- Duration
- Motion
  - Default：Toast Motion

##### Sizes

##### States

- Hidden
- Entering
- Visible
- Exiting

## 2.10 Dialogs

### Dialog

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-popover`
  - Border Color：`--color-border-muted`
  - Radius：`--radius-control`
  - Shadow：`--shadow-popover`
- Header
- Content
- Footer
- Close Button
  - Presence：Optional
  - Component：Icon Button

##### Sizes

##### States

- Closed
- Open
- Disabled

### Confirmation Dialog

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

### Cover

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

##### States

- No Cover
- Default Cover
- Loaded
- Disabled

### Cover Summary

#### Structure

1. Background Cover
2. Content
   1. Title
   2. Supporting Content
      - Description Variant：Description
      - Metadata Variant：
        1. Primary Metadata
        2. Secondary Metadata
   3. Resume or Play Action
      - Component：Button / Cover Summary

#### Sizes

- Width：Parent Available Width
- Height：`--height-cover-summary`
- Content Width：`min(Padded Available Width, clamp(--min-width-cover-summary-content, --preferred-width-cover-summary-content, --max-width-cover-summary-content))`
- Content Padding：`--padding-cover-summary-content`
- Metadata Item Gap：`--spacing-2`
- Radius：`--radius-cover-summary`

#### Layout

- Background Cover 填满组件边界，并由组件 Radius 裁切。
- Background Cover 保持原始比例，使用 Aspect Fill 与 Center Crop。
- 窗口宽度变化时，背景裁剪、Content 宽度和 Scrim 实时重新计算。
- 禁止拉伸、补边、扩图、镜像、重绘或修改封面文件。
- Content 位于左侧并保持左对齐。
- Scrim 覆盖左侧文字区域，并按照 Cover Summary Scrim 从左向右衰减至透明。
- Scrim 默认在 `--cover-summary-scrim-transparent` 位置完全透明。
- 当 Content 右边缘及其 Padding 超过默认透明位置时，Scrim 终点随 Content 延伸，最大不超过组件右边缘；中间渐变位置同比例延展。
- Outer Background and Border：None
- Light Mode 与 Dark Mode 使用同一套 Cover Summary 视觉规则。

#### Typography

- Title
  - Font Size：`--font-size-cover-summary-title`
  - Font Weight：`--font-weight-cover-summary-title`
  - Color：`--color-cover-summary-text`
  - Maximum Lines：`1`
- Supporting Content
  - Font Size：`--font-size-body`
  - Color：`--color-cover-summary-text` with `--opacity-cover-summary-description`
  - Text Hierarchy：Secondary
- Description Variant
  - Maximum Lines：`2`
  - Overflow：Tail Truncation
- Metadata Variant
  - Each Item Maximum Lines：`1`
  - Each Item Overflow：Tail Truncation

#### States

- Resume：存在最近播放记录。
- Play：不存在最近播放记录。
- Disabled：没有可播放内容。

### Cover Crop Editor

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

### Cover Progress

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

### Media Card

#### Shared

##### Anatomy

- Interaction Surface
  - Radius：`--radius-library-media-card-hover`
- Content Slot

##### Sizes

- Interaction Padding：`--padding-library-media-card-hover`

##### States

- Default
- Hover
  - Background：`--color-library-media-card-hover-bg`
- Disabled

## 2.12 Player Controls

### Player Circle Button

#### Shared

##### Anatomy

- Container
  - Radius：`--radius-player-capsule`
- Icon
  - Size：`--size-player-circle-button-icon`

##### Sizes

- Width：`--size-player-circle-button`
- Height：`--size-player-circle-button`

##### States

- Default
  - Icon Color：`--color-player-text-primary`
- Hover
  - Background：`--color-player-control-bg-hover`
- Selected
  - Icon Color：`--color-player-icon-selected`
- Disabled
  - Icon Color：`--color-player-text-tertiary`
- Interaction Suppressed

#### Variants

##### Standard

##### Transport

##### Primary Transport

### Player Capsule Button

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-control-bg`
  - Radius：`--radius-player-capsule`
- Leading Icon
  - Presence：Optional
- Label
  - Font Size：`--font-size-player-time`
  - Color：`--color-player-text-primary`
- Trailing Indicator
  - Presence：Optional

##### Sizes

- Height：`--height-player-capsule-button`
- Padding Inline：`--padding-player-capsule-button-x`

##### States

- Default
- Hover
  - Background：`--color-player-control-bg-hover`
- Menu Open
- Disabled
  - Text Color：`--color-player-text-tertiary`
- Interaction Suppressed

### Player Time Display

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-control-bg`
  - Radius：`--radius-player-capsule`
- Time Text
  - Current Time
  - Separator
  - Duration
  - Font Design：Monospaced

##### Sizes

- Height：`--height-player-capsule-button`
- Padding Inline：`--padding-player-capsule-button-x`
- Font Size：`--font-size-player-time`
- Content Gap：`--gap-player-time-label`

##### States

- Default
- Hover
  - Background：`--color-player-control-bg-hover`
- Interaction Suppressed

### Player Circle Button Group

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-control-bg`
  - Radius：`--radius-player-capsule`
- Button Stack
  - Component：Player Circle Button

##### Sizes

- Height：`--height-player-capsule-button`
- Item Gap：0

##### States

- Default
- Child Hover
- Child Disabled
- Interaction Suppressed

### Player Progress Scrubber

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
- Radius：`--radius-player-capsule`

##### States

- Default
- Hover
- Dragging
- Disabled
- No Duration

### Player Progress Time Capsule

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-control-bg`
  - Radius：`--radius-player-capsule`
- Time Label
  - Font Size：`--font-size-player-progress-time`
  - Color：`--color-player-text-primary`

##### Sizes

- Height：`--height-player-progress-time-capsule`
- Padding Inline：`--padding-player-progress-time-capsule-x`

##### States

- Hidden
- Visible On Hover
- Visible On Drag

### Player Volume Control

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-control-bg`
  - Radius：`--radius-player-capsule`
- Volume Button：Player Circle Button
- Slider Track
- Slider Fill
- Slider Thumb
- Volume Value
  - Font Design：Monospaced

##### Sizes

- Height：`--height-player-capsule-button`

##### Interaction

- Volume Button Click：Toggle Mute
- Container Hover：Expanded
- Slider Drag：Change Volume

##### States

- Collapsed
- Expanded
- Muted
- Low
- Medium
- High
- Hover
- Dragging
- Disabled
- Interaction Suppressed

### Player Window Control Button

#### Shared

##### Anatomy

- Container
  - Border Color：`--color-player-window-control-border`
  - Radius：`--radius-player-capsule`
- Glyph
  - Size：`--size-player-window-control-glyph`
  - Color：`--color-player-window-control-glyph`

##### Sizes

- Width：`--size-player-window-control-button`
- Height：`--size-player-window-control-button`

##### States

- Default
- Cluster Hover

#### Variants

##### Close

- Background：`--color-player-window-close`

##### Minimize

- Background：`--color-player-window-minimize`

##### Zoom

- Background：`--color-player-window-zoom`

### Player Title

#### Shared

##### Anatomy

- Label
  - Font Size：`--font-size-player-topbar-title`
  - Color：`--color-player-text-primary`
  - Shadow：`--shadow-player-topbar-title`

##### Sizes

- Maximum Width：`--width-player-topbar-title-max`

##### States

- Default
- Truncated

## 2.13 Playback Content

### Subtitle Focus Cue

#### Shared

##### Anatomy

- Cue Container
- Visual Line Stack
- Primary Cue Text

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

### Playback Cue Result

#### Shared

##### Anatomy

- Information Badge Row
  - Presence：Optional
  - Component：Information Badge / Playback Information Badge
- Primary Cue
- Cue Group
  - Presence：Optional

##### Sizes

- Padding Block：`--padding-subtitle-focus-cue-y`
- Primary Font Size：`--font-size-subtitle-focus-cue`
- Primary Line Height：`--line-height-subtitle-focus-cue`
- Primary Font Weight：`--font-weight-subtitle-focus-cue`
- Cue Group Font Size：`--font-size-subtitle-focus-cue-group`
- Cue Group Line Height：`--line-height-subtitle-focus-cue-group`
- Cue Group Font Weight：`--font-weight-subtitle-focus-cue-group`
- Internal Visual Line Gap：`--gap-subtitle-focus-internal-line`
- Badge Gap：`--spacing-2`

##### States

- Unselected
  - Primary Color：`--color-subtitle-focus-cue-unselected`
  - Cue Group Color：`--color-subtitle-focus-cue-unselected`
- Selected
  - Primary Color：`--color-subtitle-focus-cue-selected`
  - Cue Group Color：`--color-subtitle-focus-cue-group-selected`

### Playback Cue Reel

#### Shared

##### Anatomy

- Viewport
- Cue Stack
- Focus Anchor
- Selected Placement
- Vertical Scrollbar：Scrollbar / Vertical

##### Sizes

- Maximum Content Width：`--width-subtitle-focus-content-max`
- Cue Gap：`--gap-subtitle-focus-cue`

##### States

- Empty
- Loading
- Ready
- Scrolling
- Dragging Scrollbar
- Settling

#### Scrollbar Mapping

- Position Domain：Fractional Cue Ordinal
- Cue Weight：Equal

#### Variants

##### Focus Cue Reel

- Item：Subtitle Focus Cue

##### Cue Result Reel

- Item：Playback Cue Result

# 3. Layouts

## 3.1 App Shell

### App Sidebar Layout

#### Structure

1. Top Safe Area
2. Navigation Region
3. Flexible Spacer
4. Settings Region

#### Components

- Sidebar
- Sidebar Toggle
- Sidebar Item / Primary
- Sidebar Item / Child
- Sidebar Item / Action
- Scrollbar / Vertical

#### Sizes

- Width：`--width-app-sidebar`
- Padding Inline：`--padding-app-sidebar-x`
- Padding Block：`--padding-app-sidebar-y`
- Navigation Item Gap：`--spacing-1`

#### States

- Expanded
- Collapsed
- Child Region Scrolling

### App Topbar Layout

#### Structure

1. Sidebar Segment
2. Sidebar Toggle Slot
3. Title Slot
4. Draggable Region

#### Components

- Sidebar Toggle
- Section Title

#### Sizes

- Height：`--height-app-topbar`
- Sidebar Segment Width：`--width-app-sidebar`
- Title Padding Inline：`--padding-app-topbar-title-x`
- Collapsed Title Gap：`--gap-app-topbar-title-after-toggle`

#### States

- Sidebar Expanded
- Sidebar Collapsed
- Hidden On Playback

## 3.2 Settings

### Settings Window Layout

#### Structure

1. Sidebar Region
2. Category Content Region

#### Components

- Settings Sidebar Layout
- Settings Category Layout

#### States

- Open
- Closed

### Settings Sidebar Layout

#### Structure

1. Category List

#### Components

- Sidebar Item / Primary
- Scrollbar / Vertical

#### States

- Default
- Scrolling

### Settings Category Layout

#### Structure

1. Page Title
2. Page Description
3. Settings Group Stack

#### Components

- Section Title
- Text Field
- Text Area
- Number Field
- Checkbox
- Switch
- Button

#### Spacing

- Region Gap：`--spacing-6`
- Group Gap：`--spacing-4`
- Control Gap：`--spacing-3`

## 3.3 Recent

### Recent Overview Layout

#### Structure

1. Recent Videos Section
2. Recent Shioris Section

#### Components

- Recent Videos Section Layout
- Recent Shioris Section Layout
- Section Title
- Information Badge / Count
- Icon Button

#### Spacing

- Page Padding：`--spacing-6`
- Section Gap：`--spacing-6`

### Recent Videos Section Layout

#### Structure

1. Section Header
2. Recent Watching Card Grid

#### Components

- Section Title
- Information Badge / Count
- Icon Button
- Recent Watching Card Layout

#### Sizes

- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Recent Shioris Section Layout

#### Structure

1. Section Header
2. Recent Shiori Resume Row List

#### Components

- Section Title
- Information Badge / Count
- Icon Button
- Recent Shiori Resume Row Layout

#### Spacing

- Row Gap：`--spacing-3`

### Recent Watching Card Layout

#### Structure

1. Cover Region
2. Folder Name
3. Meta Row

#### Components

- Media Card
- Cover
- Cover Progress
- Information Badge / Cover Badge
- Watch Status Badge

#### Sizes

- Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Content Gap：`--spacing-2`

#### States

- Default
- Selected
- Disabled

### Recent Shiori Resume Row Layout

#### Structure

1. Cover Region
2. Content Region
   1. List Name
   2. Description
   3. Resume Position
   4. Recent Cue

#### Components

- Cover

#### Spacing

- Region Gap：`--spacing-3`
- Content Gap：`--spacing-2`

#### States

- Default
- Hover
- Selected
- Disabled

## 3.4 Library

### Library Overview Layout

#### Structure

1. Summary Row
2. Adaptive Folder Card Grid

#### Components

- Section Title
- Button / Neutral
- Library Folder Card Layout

#### Sizes

- Page Padding：`--spacing-6`
- Summary to Grid Gap：`--spacing-4`
- Summary Height：`--height-control`
- Summary Item Gap：`--spacing-3`
- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Library Folder Card Layout

#### Structure

1. Cover Region
2. Folder Name

#### Components

- Media Card
- Cover
- Information Badge / Cover Badge

#### Sizes

- Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Minimum Height：`--min-height-library-folder-card`
- Content Gap：`--spacing-2`

#### States

- Default
- Disabled

### Library Folder Detail Layout

#### Structure

1. Header
   1. Back Action
   2. Folder Title
2. Cover Summary
3. Episode Grid

#### Components

- Icon Button
- Section Title
- Cover Summary / Library Variant
- Library Episode Grid Layout

#### Layout

- Content Page Padding Inline 与 Shiori List Detail 相同。
- Cover Summary 与 Episode Grid 使用相同宽度和水平边界。
- Cover Summary 宽度跟随页面可用宽度变化，并触发其背景裁剪、Content 和 Scrim 的响应式布局。

#### Spacing

- Header Item Gap：`--spacing-2`
- Content Page Padding Inline：`--spacing-8`
- Content Page Padding Block：`--spacing-6`
- Cover Summary to Episode Grid Gap：`--spacing-6`

#### Scrolling

- Vertical Scroll Context：Single Page Viewport
- Cover Summary：Scrollable
- Episode Grid：Scrollable
- Vertical Scrollbar：Page Viewport Trailing Edge

### Library Episode Grid Layout

#### Structure

1. Episode Row List

#### Components

- Library Episode Card Layout
- Scrollbar / Vertical

#### Sizes

- Row Minimum Width：`--width-library-episode-row-min`
- Row Gap：`--gap-library-episode-grid`

### Library Episode Card Layout

#### Structure

1. Cover Region
2. Info Region
   1. Title Row
   2. Subtitle File Row
   3. Media Metadata Row

#### Components

- Cover
- Cover Progress
- Information Badge / Cover Badge
- Watch Status Badge

#### Sizes

- Cover Width：`--width-library-list-cover`
- Cover Height：`--height-library-list-cover`
- Region Gap：`--gap-library-list-item`
- Card Padding：`--padding-library-list-card`
- Card Radius：`--radius-library-list-card`
- Info Row Gap：`--gap-library-list-info-vertical`

#### States

- Default
- Cover Hover
  - Background：`--color-library-media-card-hover-bg`
- Cover Selected
- Disabled

## 3.5 Search and Shiori

### Shiori List Overview Layout

#### Structure

1. Summary Row
2. Adaptive Shiori List Card Grid

#### Components

- Section Title
- Button / Neutral
- Shiori List Card Layout

#### Sizes

- Page Padding：`--spacing-6`
- Summary to Grid Gap：`--spacing-4`
- Summary Height：`--height-control`
- Summary Item Gap：`--spacing-3`
- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Shiori List Card Layout

#### Structure

1. Cover Region
2. List Name
3. Description

#### Components

- Media Card
- Cover
- Information Badge / Cover Badge

#### Sizes

- Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Content Gap：`--spacing-2`

#### States

- Default
- Disabled

### Shiori List Detail Layout

#### Structure

1. Cover Summary
2. Toolbar
3. Filter Panel
   - Presence：Optional
4. Table
5. Selection Action Overlay

#### Components

- Cover Summary
- Search / Shiori Toolbar Layout
- Filter Panel Layout
- Search / Shiori Table Layout
- Selection Action Overlay Layout

#### Layout

- Cover Summary、Toolbar 与 Table Content Region 使用相同宽度和水平边界。
- Cover Summary 宽度跟随页面可用宽度变化，并触发其背景裁剪、Content 和 Scrim 的响应式布局。

#### Spacing

- Page Padding Inline：`--spacing-8`
- Cover Padding Top：`--spacing-6`
- Cover to Toolbar Gap：`--gap-cover-summary-to-toolbar`
- Pinned Region Item Gap：`--spacing-3`

#### Scrolling

- Vertical Scroll Context：Single Page Viewport
- Cover Summary：Scrollable
- Toolbar、打开的 Filter Panel 与 Table Header：Pinned
- Vertical Scrollbar：Page Viewport Trailing Edge

### Search / Shiori Toolbar Layout

#### Structure

1. Search Field
2. Filter Trigger
3. Select Mode Action

#### Components

- Search Field
- Toolbar Button / Panel Trigger
- Toolbar Button / Mode Toggle

#### Sizes

- Height：`--height-filter-bar-control`
- Item Gap：`--spacing-3`
- Width：Fill Parent Content Width

#### States

- Default
- Filter Panel Open
- Select Mode
- Calculating

### Filter Panel Layout

#### Position

- Flow：Overlay
- Width：Adaptive to App Window

#### Structure

1. Filter Group Grid
2. Footer
   1. Reset
   2. Flexible Spacer
   3. Cancel
   4. Apply

#### Components

- Checkbox / Filter Checkbox
- Button / Neutral
- Button / Primary
- Scrollbar / Vertical

#### Sizes

- Group Minimum Width：`--min-width-filter-data-card`
- Grid Gap：`--spacing-3`
- Group Content Gap：`--spacing-2`
- Footer Gap：`--spacing-3`

#### States

- Closed
- Open / Clean Draft
  - Apply Disabled
- Open / Modified Draft
- Calculating
- Applying
- Disabled

#### Focus

- Mode：Non-modal
- Order：Normal
- Boundary：Uncontained

#### State Transition

- Open：Applied State → Draft State
- Edit：Draft State only
- Reset：Draft State → Empty Draft State; Panel remains open
- Cancel：Discard Draft State; Applied State unchanged; Panel closes
- Filter Trigger / Open：Cancel
- Apply：Draft State → Applied State; Panel closes
- Apply Disabled：Draft State = Applied State
- Outside Click：No State Change
- Escape：No State Change

### Selection Action Overlay Layout

#### Position

- Anchor：Table Viewport Bottom Center
- Flow：Overlay

#### Components

- Selection Action Overlay
- Button / Neutral

#### Structure

1. Selected Count
2. Anki
3. Copy Deep Links
4. Copy Table

#### Spacing

- Content Gap：`--spacing-2`
- Padding：`--spacing-3`

#### States

- Hidden：Selected Count = 0
- Visible：Selected Count > 0

### Search / Shiori Table Layout

#### Structure

1. Fixed Header
2. Scrollable Body
3. Vertical Scrollbar
4. Horizontal Scrollbar

#### Components

- Table
- Table Header Cell / Sortable
- Table Header Cell / Selection
- Table Row
- Table Cell / Text
- Table Cell / Interactive Text
- Checkbox / Table Selection Checkbox
- Scrollbar / Vertical
- Scrollbar / Horizontal

#### Sizes

- Header Height：`--height-table-header`
- Row Minimum Height：`--min-height-table-row`
- Row Padding Block：`--padding-table-row-y`
- Cell Padding Leading：`--padding-table-cell-leading`
- Cell Padding Trailing：`--padding-table-cell-trailing`

#### Column Widths

- Selection
  - Mode：Fixed
  - Width：`50pt`
- Display Title
  - Mode：Weighted
  - Weight：`3`
  - Minimum Width：`180pt`
- Cues
  - Mode：Weighted
  - Weight：`6`
  - Minimum Width：`240pt`
- Time Range
  - Mode：Weighted
  - Weight：`2`
  - Minimum Width：`140pt`
- Date Added
  - Presence：Shiori
  - Mode：Weighted
  - Weight：`2`
  - Minimum Width：`120pt`
- Overflow：Horizontal Scroll

#### States

- Empty Query
- Calculating
- Results
- Select Mode
- Empty Results

## 3.6 Dialogs

### Edit Cover Dialog Layout

#### Structure

1. Header
   1. Title
   2. Close Action
2. Cover Crop Editor
3. Footer
   1. Cancel
   2. Apply

#### Components

- Dialog
- Cover Crop Editor
- Icon Button
- Button / Neutral
- Button / Primary

#### Spacing

- Region Gap：`--spacing-4`
- Footer Action Gap：`--spacing-3`

#### States

- No Image
- Image Loaded
- Crop Modified
- Applying

### Shiori List Editor Dialog Layout

#### Structure

1. Header
   1. Title
   2. Close Action
2. Cover Region
   1. Cover
   2. Edit Cover Action
3. Form Region
   1. Name Field
   2. Description Field
4. Footer
   1. Cancel
   2. Save

#### Components

- Dialog
- Cover
- Icon Button
- Text Field
- Text Area
- Button / Neutral
- Button / Primary
- Edit Cover Dialog Layout

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Footer Action Gap：`--spacing-3`

#### States

- New
- Edit
- Validation Error
- Saving

### Confirmation Dialog Layout

#### Structure

1. Header
2. Message
3. Footer
   1. Cancel
   2. Confirm

#### Components

- Confirmation Dialog
- Button / Neutral
- Button / Primary or Destructive

#### Spacing

- Region Gap：`--spacing-4`
- Footer Action Gap：`--spacing-3`

#### States

- Default
- Destructive
- Confirm Disabled
- Submitting

## 3.7 Player

### Player Topbar Layout

#### Structure

1. Window Controls
2. Flexible Spacer
3. Player Title
4. Flexible Spacer
5. Window Action Region

#### Components

- Player Window Control Button / Close
- Player Window Control Button / Minimize
- Player Window Control Button / Zoom
- Player Title
- Player Circle Button

#### Sizes

- Height：`--height-player-topbar`
- Padding Inline：`--padding-player-topbar-x`
- Window Control Gap：`--gap-player-window-controls`

#### Surface

- Gradient Start：`--color-player-topbar-gradient-start`
- Gradient End：`--color-player-topbar-gradient-end`

#### States

- Visible
- Interaction Suppressed
- Pointer Hidden

### Player Bottom Control Bar Layout

#### Structure

1. Progress Region
2. Controls Row
   1. Left Control Group
   2. Flexible Spacer
   3. Right Control Group

#### Components

- Player Progress Scrubber Layout
- Player Circle Button
- Player Circle Button Group
- Player Capsule Button
- Player Time Display
- Player Volume Control

#### Sizes

- Height：`--height-player-bottom-control-bar`
- Controls Row Height：`--height-player-bottom-controls-row`
- Padding Inline：`--padding-player-chrome-x`
- Padding Bottom：`--padding-player-chrome-bottom`
- Progress Top Padding：`--padding-player-progress-top`
- Left Control Gap：`--gap-player-bottom-left-controls`
- Right Control Gap：`--gap-player-bottom-right-controls`

#### States

- Visible
- Interaction Suppressed
- Pointer Hidden

### Player Progress Scrubber Layout

#### Structure

1. Player Progress Scrubber
2. Player Progress Time Capsule
   - Presence：Hover or Dragging

#### Components

- Player Progress Scrubber
- Player Progress Time Capsule

#### Sizes

- Hit Area Height：`--height-player-progress-hit-area`
- Track Height：`--height-player-progress-track`
- Hover Track Height：`--height-player-progress-track-hover`

#### States

- Default
- Hover
- Dragging
- No Duration

### Playback Feedback Overlay Layout

#### Position

- Input：Playback Feedback / Position
- Values
  - Center
  - Leading
  - Trailing
- Anchor：Player Stage
- Layer：Above Video; Below Playback Overlay and Command Panel

#### Timing

- Duration：Playback Feedback / Duration

#### Components

- Playback Feedback

#### States

- Hidden
- Entering
- Visible
- Exiting

## 3.8 Playback Overlay

### Playback Overlay Layout

#### Structure

1. Overlay Surface
2. Playback Topbar
3. View Content Region

#### Components

- Playback Topbar Layout
- Playback Current Layout
- Playback Playlist Layout
- Playback Collage Editor Layout

#### Surface

- Background：`--color-subtitle-focus-overlay-bg`
- Shadow：`--shadow-player-overlay`

#### Sizes

- Content Padding：`--spacing-8`

#### States

- Closed
- Opening
- Current
- Playlist
- Editing Collage
- Closing

### Playback Topbar Layout

#### Structure / Normal

1. Leading Action Region
2. Tabs
3. Flexible Spacer

#### Structure / Editing Collage

1. Exit Action
2. Editing Title
3. Flexible Spacer

#### Components

- Button / Neutral
- Tabs
- Tab
- Section Title

#### Spacing

- Leading Margin：`--spacing-4`
- Editing Title Content Gap：`--spacing-2`

#### Keyboard

- Focused Tab：None
- `Tab`：Switch Current / Playlist

#### States

- Current
- Playlist
- Editing Collage

### Playback Current Layout

#### Structure

1. Subtitle Region
   1. Playback Cue Reel / Focus Cue Reel
   2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Information Badge / Playback Information Badge
- Scrollbar / Vertical

#### Sizes

- Maximum Content Width：`--width-subtitle-focus-content-max`
- Cue Gap：`--gap-subtitle-focus-cue`
- Information Badge Gap：`--spacing-2`

#### Information Badge Order

1. Display Title
2. Time Range

#### States

- Loading
- Ready
- Empty
- Scrolling
- Settling

### Playback Playlist Layout

#### Structure / Subtitle Playlist

1. Subtitle Region
   1. Playback Cue Reel / Cue Result Reel
   2. Vertical Scrollbar

#### Structure / Video Playlist

1. Library Episode Grid

#### Components

- Playback Cue Reel / Cue Result Reel
- Playback Cue Result
- Information Badge / Playback Information Badge
- Scrollbar / Vertical
- Library Episode Grid Layout
- Library Episode Card Layout

#### Information Badge Order / Subtitle Playlist

1. Position
2. Display Title
3. Time Range

#### States

- Subtitle Playlist
- Video Playlist
- Loading
- Ready
- Empty

### Playback Collage Editor Layout

#### Structure

1. Collage Preview Region
2. Subtitle Selection Region

#### Collage Preview Region

1. Section Title
2. Collage Image Viewport
3. Action Row

#### Subtitle Selection Region

1. Playback Cue Reel / Focus Cue Reel
2. Leading Checkbox Slot
3. Vertical Scrollbar

#### Components

- Section Title
- Button / Neutral
- Playback Cue Reel / Focus Cue Reel
- Checkbox / Playback Selection Checkbox
- Information Badge / Playback Information Badge
- Scrollbar / Vertical

#### Sizes

- Region Width：1fr / 1fr
- Region Padding：`--spacing-8`
- Section Gap：`--spacing-4`
- Action Gap：`--spacing-3`
- Checkbox to Cue Gap：`--spacing-4`

#### States

- Loading Preview
- Ready
- Rendering
- Selection Limit Reached
- Exporting

## 3.9 Command Panel

### Command Panel Root Layout

#### Structure / Empty Query

1. Search Field
2. Option List
   1. Recent Videos
   2. Recent Shioris
3. Footer

#### Structure / Filled Query

1. Search Field
2. Option List
   1. Search Action
   2. Recent Videos
   3. Recent Shioris
3. Footer

#### Components

- Search Field
- Menu Item / Action Menu Item
- Keycap
- Keycap Group
- Scrollbar / Vertical

#### States

- Empty Query
- Filled Query
- Navigating
- Opening Secondary

### Command Panel Secondary Layout

#### Structure

1. Header
   1. Back Action
   2. Title
2. Content Region
3. Footer

#### Components

- Icon Button
- Section Title
- Keycap
- Keycap Group
- Scrollbar / Vertical

#### Variants

- Recent Videos
  - Content：Recent Videos Section Layout
- Recent Shioris
  - Content：Recent Shioris Section Layout
- Search Results
  - Content：Command Panel Search Results Layout

### Command Panel Search Results Layout

#### Structure

1. Playback Cue Reel / Cue Result Reel
2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Cue Result Reel
- Playback Cue Result
- Information Badge / Playback Information Badge
- Scrollbar / Vertical

#### Information Badge Order

1. Position
2. Display Title
3. Time Range

#### States

- Loading
- Results
- Empty
- Scrolling
- Settling
