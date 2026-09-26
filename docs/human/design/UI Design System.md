# 说明
1. 本文档由人类维护，作为UI/UX的设计文档。一些细节说明放在/docs/human/design/UI Application Rules.md。约束AI的工程文档和具体代码实现。

# 1. Core Tokens

## 1.1 颜色

Dark 下越上层越亮：Sidebar < 页面 < 表格与设置卡片 < 对话框 < 菜单；播放页为视频 < Playback Overlay < Command Panel < 菜单。菜单始终最亮，包括在对话框与 Command Panel 内打开的菜单。

控件底色、Hover、Disabled、分隔线、Disabled 边框与 Keycap 在 Dark 下为半透明白色，在任何表面上都比该表面亮。

### Text

- `--color-text-primary`: Light `#1F1F1F`; Dark `#E4E4E4`
- `--color-text-secondary`: Light `#494949`; Dark `#B9B9B9`
- `--color-text-muted`: Light `#717171`; Dark `#979797`
- `--color-text-placeholder`: Light `#9A9A9A`; Dark `#606060`
- `--color-text-disabled`: Light `#9A9A9A`; Dark `#606060`

### Icon

- `--color-icon-on-dark`: Light `#FFFFFF`; Dark `#FFFFFF`

### Background

- `--color-bg-surface`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-bg-hover`: Light `#F3F4F6`; Dark `rgba(255,255,255,0.12)`
- `--color-bg-disabled`: Light `#F3F4F6`; Dark `rgba(255,255,255,0.04)`
- `--color-bg-control`: Light `#FFFFFF`; Dark `rgba(255,255,255,0.08)`
- `--color-bg-dialog`: Light `#FFFFFF`; Dark `#2F2F34`
- `--color-bg-popover`: Light `#FFFFFF`; Dark `#36363B`
- `--color-app-sidebar-bg`: Light `#F6F7F9`; Dark `#111113`
- `--color-app-sidebar-item-selected-bg`: macOS accent color
- `--color-app-sidebar-item-selected-content`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-app-topbar-bg`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-settings-group-bg`: Light `#F6F7F9`; Dark `#26262A`
- `--color-overlay-surface-shortcut-button-bg-hover`: Light `#EDEEF2`; Dark `rgba(255,255,255,0.06)`
- `--color-overlay-surface-keycap-bg`: Light `#E1E4E9`; Dark `rgba(255,255,255,0.10)`
- `--color-overlay-surface-keycap-bg-hover`: Light `#D2D6DE`; Dark `rgba(255,255,255,0.16)`
- `--color-popover-surface-shortcut-button-bg-hover`: Light `#F7F8FA`; Dark `rgba(255,255,255,0.06)`
- `--color-popover-surface-keycap-bg`: Light `#EDEFF2`; Dark `rgba(255,255,255,0.10)`
- `--color-popover-surface-keycap-bg-hover`: Light `#E0E3E8`; Dark `rgba(255,255,255,0.16)`

### Border

- `--color-border-control`: Light `#E5E7EB`; Dark `#4A4A52`
- `--color-border-control-hover`: Light `#D1D5DB`; Dark `#52525B`
- `--color-border-muted`: Light `#E5E7EB`; Dark `#4A4A52`
- `--color-border-divider`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.10)`
- `--color-border-disabled`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.10)`
- `--color-border-checkbox`: Light `#D0D5DD`; Dark `#5A5A62`

### Accent

- `--color-accent`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-text-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-icon-active`: Light `#0040FF`; Dark `#8AB4FF`
- `--color-border-active`: Light `#0040FF`; Dark `#7AA2FF`
- `--color-bg-active`: Light `#EBF5FF`; Dark `#14275A`
- `--color-bg-active-hover`: Light `#E1EBFF`; Dark `#1B3470`

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
- `--color-bg-checkbox-checked`: Light `#667085`; Dark `#A1A1AA`
- `--color-segmented-control-selected-bg`: macOS accent color
- `--color-segmented-control-selected-content`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-filter-chip-selected-content`: macOS accent color
- `--color-filter-chip-selected-bg`: Same as `--color-library-media-card-hover-bg`
- `--color-spinner-track`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-spinner-indicator`: Light `#717171`; Dark `#878787`
- `--color-danger-text`: Light `#B42318`; Dark `#FCA5A5`
- `--color-danger-bg-hover`: Light `#FEF3F2`; Dark `#3A1717`
- `--color-success-text`: Light `#047857`; Dark `#6EE7B7`
- `--color-warning-text`: Light `#B45309`; Dark `#FCD34D`

### Tab

- `--color-tab-selected`: Light `#111827`; Dark `rgba(255,255,255,0.94)`
- `--color-tab-unselected`: Light `#667085`; Dark `rgba(255,255,255,0.34)`

### Table

- `--color-table-bg`: Light `#FFFFFF`; Dark `#26262A`
- `--color-row-hover`: Light `#F9FAFB`; Dark `#2E2E33`
- `--color-row-selected`: Light `#F3F4F6`; Dark `#36363C`

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
- `--color-library-cover-edit-overlay`: Same as `--color-library-cover-crop-mask`
- `--color-library-cover-edit-overlay-content`: Same as `--color-icon-on-dark`
- `--color-library-media-card-hover-bg`:
  - Light: macOS accent color with Alpha `0.08`
  - Dark: macOS accent color with Alpha `0.12`

### Cover Summary

- `--color-cover-summary-scrim`: Light `#000000`; Dark `#000000`
- `--color-cover-summary-text`: Light `#FFFFFF`; Dark `#FFFFFF`

### Dialog

- `--color-dialog-scrim`: Light `rgba(170,170,170,0.60)`; Dark `rgba(0,0,0,0.50)`
- `--color-command-panel-scrim`: Light `rgba(0,0,0,0.32)`; Dark `rgba(0,0,0,0.32)`
- `--color-dialog-outline`: Light `rgba(0,0,0,0.19)`; Dark `rgba(0,0,0,0.94)`
- `--color-dialog-edge-highlight`: Light `transparent`; Dark `rgba(255,255,255,0.20)`

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
- `--color-player-topbar-gradient-start`: Light `rgba(18,18,24,0.66)`; Dark `rgba(18,18,24,0.66)`
- `--color-player-topbar-gradient-end`: Light `rgba(18,18,24,0)`; Dark `rgba(18,18,24,0)`
- `--color-player-error-bg`: Light `#B42318`; Dark `#B42318`
- `--color-player-error-content`: Light `#FFFFFF`; Dark `#FFFFFF`

### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#F6F7F9`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `#111827`; Dark `rgba(255,255,255,0.88)`
- `--color-subtitle-focus-cue-group-selected`: Light `#475467`; Dark `rgba(255,255,255,0.62)`
- `--color-subtitle-focus-cue-unselected`: Light `#858B95`; Dark `rgba(255,255,255,0.34)`
- `--color-playback-cue-timeline-focused`: Light `#667085`; Dark `#71717A`
- `--color-playback-cue-timeline-muted`: Light `#D0D5DD`; Dark `#52525B`
- `--color-playback-cue-metadata`: Light `#667085`; Dark `#A1A1AA`

## 1.2 字体与文本

### Typography

- `--font-family-base`: `system-ui, sans-serif`
- `--font-size-body`: `14px`
- `--font-size-control`: `14px`
- `--font-weight-control`: `500`
- `--font-size-segmented-control`: `12px`
- `--font-size-table`: `14px`
- `--font-size-table-header`: `14px`
- `--font-size-caption`: `12px`
- `--line-height-table-cue-primary`: `24px`
- `--line-height-table-cue-secondary`: `20px`
- `--font-size-app-sidebar-item`: `13px`
- `--font-size-player-time`: `12px`
- `--font-size-player-progress-time`: `10px`
- `--font-size-player-speed-menu-check`: `14px`
- `--font-size-player-speed-menu-item`: `13px`
- `--font-size-player-error`: `13px`
- `--line-height-player-error`: `20px`
- `--font-size-playback-feedback`: `18px`
- `--font-size-toast`: `16px`
- `--font-size-subtitle-focus-cue`: `24px`
- `--line-height-subtitle-focus-cue`: `32px`
- `--font-weight-subtitle-focus-cue`: `600`
- `--font-size-subtitle-focus-cue-group`: `20px`
- `--line-height-subtitle-focus-cue-group`: `28px`
- `--font-weight-subtitle-focus-cue-group`: `500`
- `--font-weight-playback-cue-metadata`: `400`
- `--line-height-playback-cue-metadata`: `16px`
- `--font-size-section-title`: `18px`
- `--font-size-page-title`: `20px`
- `--font-weight-page-title`: `600`
- `--font-size-library-title`: `14px`
- `--font-size-library-meta`: `12px`
- `--font-size-library-time-badge`: `10px`
- `--font-size-task-count-badge`: `13px`
- `--font-weight-task-count-badge`: `600`
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
- `--height-segmented-control`: `32px`
- `--height-filter-chip`: `32px`
- `--height-filter-chip-count-placeholder`: `12px`
- `--height-field`: `40px`
- `--height-table-header`: `40px`
- `--min-height-table-row`: `40px`
- `--height-action-menu-item`: `32px`
- `--height-select-menu-item`: `32px`
- `--max-height-menu`: `480px`
- `--height-app-sidebar-item`: `32px`
- `--height-app-topbar`: `45px`
- `--height-workbench-topbar`: `54px`
- `--height-player-bottom-control-bar`: `98px`
- `--height-player-bottom-controls-row`: `52px`
- `--height-player-capsule-button`: `40px`
- `--height-player-speed-menu`: `246px`
- `--height-player-speed-menu-item`: `30px`
- `--height-player-progress-hit-area`: `18px`
- `--height-player-progress-track`: `3px`
- `--height-player-progress-track-hover`: `6px`
- `--height-player-progress-time-capsule`: `22px`
- `--height-playback-feedback`: `52px`
- `--height-library-progress-bar`: `4px`
- `--height-task-progress-bar`: `4px`
- `--height-task-panel`: `500px`
- `--height-filter-dialog`: `600px`
- `--height-library-list-cover`: `115px`
- `--height-cover-summary-backdrop`: `225px`
- `--height-keycap`: `22px`
- `--min-height-playback-footer`: `48px`
- `--height-settings-window`: `640px`
- `--min-height-settings-window`: `420px`
- `--height-settings-titlebar`: `36px`
- `--min-height-settings-row`: `52px`

### Size

- `--size-checkbox`: `21px`
- `--size-spinner`: `16px`
- `--width-spinner-stroke`: `2px`
- `--width-filter-chip-count-placeholder`: `24px`
- `--max-width-filter-chip`: `332px`
- `--size-playback-collage-checkbox`: `31px`
- `--size-playback-cue-timeline-dot`: `8px`
- `--size-inline-clear-button`: `24px`
- `--size-inline-clear-icon`: `16px`
- `--size-inline-clear-symbol-font-size-macos`: `14px`
- `--size-inline-add-symbol-font-size-macos`: `21px`
- `--size-menu-item-symbol-font-size-macos`: `18px`
- `--size-button-icon`: `18px`
- `--size-library-cover-edit-overlay-icon`: `42px`
- `--size-control-icon`: `21px`
- `--size-dialog-close-icon`: `16px`
- `--size-dialog-close-button`: `24px`
- `--size-icon-button`: `32px`
- `--size-row-action-button`: `36px`
- `--scrollbar-size`: `8px`
- `--scrollbar-min-thumb-length`: `24px`
- `--width-page-scrollbar-channel`: `16px`
- `--width-app-sidebar`: `240px`
- `--size-app-sidebar-item-icon`: `23px`
- `--size-task-count-badge-compact`: `18px`
- `--size-task-card-icon`: `31px`
- `--size-player-circle-button`: `40px`
- `--size-player-circle-button-icon`: `23px`
- `--width-player-speed-button`: `54px`
- `--width-player-speed-menu`: `184px`
- `--max-width-player-audio-track-menu`: `300px`
- `--size-player-progress-thumb`: `12px`
- `--width-player-topbar-title-max`: `520px`
- `--size-player-error-icon`: `16px`
- `--size-playback-feedback-icon`: `31px`
- `--width-playback-feedback-max`: `520px`
- `--size-toast-icon`: `23px`
- `--width-toast-max`: `400px`
- `--width-playback-cue-timeline-connector`: `1px`
- `--width-subtitle-focus-content-max`: `960px`
- `--aspect-library-cover`: `16 / 9`
- `--min-width-cover-summary-content`: `448px`
- `--max-width-cover-summary-content`: `720px`
- `--preferred-width-cover-summary-content`: `50%`
- `--width-cover-summary-split-cover`: `320px`
- `--min-width-cover-summary-split-content`: `320px`
- `--width-cover-summary-form-switch`: `664px`
- `--width-library-recent-card-min`: `180px`
- `--width-library-recent-card-max`: `220px`
- `--width-library-episode-row-min`: `380px`
- `--width-library-list-cover`: `204px`
- `--width-library-folder-cover`: `120px`
- `--min-height-library-folder-card`: `96px`
- `--min-width-workbench-page-content`: `480px`
- `--width-dialog-small`: `360px`
- `--width-dialog-medium`: `480px`
- `--width-dialog-large`: `600px`
- `--width-dialog-x-large`: `720px`
- `--width-shortcut-field`: `144px`
- `--width-settings-number-field`: `114px`
- `--width-settings-window`: `880px`
- `--width-settings-sidebar`: `184px`
- `--width-settings-popup`: `180px`
- `--border-width-control`: `1px`

## 1.4 间距

### Spacing

- `--spacing-1`: `4px`
- `--spacing-2`: `8px`
- `--spacing-3`: `12px`
- `--spacing-4`: `16px`
- `--spacing-6`: `24px`
- `--spacing-8`: `32px`
- `--gap-segmented-control`: `2px`
- `--gap-menu-scrollbar-outer`: `6px`
- `--inset-menu-divider`: `--padding-menu` 与 `--padding-menu-item` 之和
- `--gap-menu-divider`: `4px`
- `--gap-subtitle-focus-cue`: `8px`
- `--gap-subtitle-focus-internal-line`: `3px`
- `--gap-player-bottom-left-controls`: `8px`
- `--gap-player-bottom-right-controls`: `6px`
- `--gap-player-time-label`: `4px`
- `--gap-app-topbar-toggle-after-window-controls`: `20px`
- `--gap-app-topbar-content`: `12px`
- `--gap-player-window-controls-return`: `16px`
- `--gap-player-speed-menu-from-button`: `8px`
- `--gap-library-recent-grid`: `16px`
- `--gap-library-episode-grid`: `16px`
- `--gap-library-list-item`: `20px`
- `--gap-library-list-info-vertical`: `8px`
- `--gap-library-folder-card-content`: `12px`
- `--gap-cover-summary-to-toolbar`: `24px`
- `--gap-cover-summary-split`: `24px`
- `--gap-cover-dialog-region`: `20px`

### Padding

- `--inset-dialog`: `24px`
- `--padding-control-x`: `14px`
- `--padding-segmented-control`: `3px`
- `--padding-field-x`: `16px`
- `--padding-menu`: `6px`
- `--padding-menu-item`: `10px`
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
- `--padding-settings-row-y`: `6px`
- `--padding-player-chrome-x`: `24px`
- `--padding-player-chrome-bottom`: `12px`
- `--padding-player-progress-top`: `16px`
- `--padding-player-capsule-button-x`: `16px`
- `--padding-player-speed-menu-item-x`: `8px`
- `--padding-player-progress-time-capsule-x`: `8px`
- `--padding-player-topbar-x`: `16px`
- `--padding-player-error-x`: `12px`
- `--padding-player-error-y`: `10px`
- `--padding-library-folder-card`: `12px 16px`
- `--padding-library-time-badge`: `2px 6px`
- `--padding-task-count-badge-compact-x`: `6px`
- `--padding-library-media-card-hover`: `12px`
- `--padding-library-list-card`: `12px 16px`
- `--padding-cover-summary-backdrop-inline`: `40px`
- `--padding-cover-summary-backdrop-block`: `22.5px`

## 1.5 形状与效果

### Radius

- `--radius-control`: `8px`
- `--radius-field`: `8px`
- `--radius-search`: `9999px`
- `--radius-inline-clear-button`: `9999px`
- `--radius-checkbox`: `9999px`
- `--radius-menu`: `12px`
- `--radius-dialog`: `10px`
- `--radius-select-menu-item`: `6px`
- `--radius-action-menu-item`: `6px`
- `--radius-row-action`: `8px`
- `--radius-table-cell-hover`: `8px`
- `--radius-chip`: `6px`
- `--radius-keycap`: `4px`
- `--scrollbar-radius`: `9999px`
- `--radius-app-sidebar-item`: `8px`
- `--radius-settings-group`: `10px`
- `--radius-player-capsule`: `9999px`
- `--radius-player-speed-menu`: `14px`
- `--radius-playback-feedback`: `16px`
- `--radius-player-error`: `10px`
- `--radius-player-speed-menu-item`: `8px`
- `--radius-library-cover`: `8px`
- `--radius-library-time-badge`: `4px`
- `--radius-library-folder-card`: `8px`
- `--radius-library-media-card-hover`: `20px`
- `--radius-library-list-card`: `16px`
- `--radius-cover-summary`: `16px`

### Shadow

- `--shadow-popover`: Light 与 Dark 相同
  - `0 10px 15px -3px rgba(15,23,42,0.10)`
  - `0 4px 6px -4px rgba(15,23,42,0.10)`
- `--shadow-dialog`:
  - Light: `0 18px 40px rgba(0,0,0,0.25)`
  - Dark: `0 18px 40px rgba(0,0,0,0.43)`
- `--shadow-player-overlay`:
  - Light: `0 12px 24px rgba(0,0,0,0.42)`
  - Dark: `0 12px 24px rgba(0,0,0,0.42)`
- `--shadow-player-topbar-title`:
  - Light: `0 1px 2px rgba(0,0,0,0.50)`
  - Dark: `0 1px 2px rgba(0,0,0,0.50)`

阴影由容器形状投射，容器内部元素不各自投射阴影。
深色下该阴影几乎不可见，浮层与页面的分离由容器边框承担。深色若需更强分层，提亮浮层背景，不加重阴影。

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

- `--scale-library-cover-hover`: `1.02`
- `--duration-library-cover-hover`: `0.12s`
- `--scale-collage-group-hover`: `1.02`
- `--duration-collage-group-hover`: `0.12s`

### Toast Motion

- `--duration-toast-motion`: `0.20s`
- `--easing-toast-motion`: `cubic-bezier(0.22, 1, 0.36, 1)`

### Dialog Motion

- `--duration-dialog-motion`: `0.27s`
- `--duration-dialog-fade-in`: `0.12s`
- `--distance-dialog-motion`: `34px`
- `--easing-dialog-motion`: `cubic-bezier(0.4, 0.2, 0.58, 1)`

### Spinner Motion

- `--duration-spinner-motion`: `1s`
- `--easing-spinner-motion`: `linear`

### Subtitle Focus Motion

- `--duration-subtitle-focus-scroll`: `0.22s`
- `--easing-subtitle-focus-scroll`: `cubic-bezier(0.22, 1, 0.36, 1)`

### Player UI Visibility

- `--duration-player-ui-idle-hide`: `3s`

# 2. Components

## 2.1 Inputs

### Shared

#### Focus Treatment

- Indicator：Border Color Only
- Focus Ring：None
- Focused Geometry：Same size, radius, padding, and layout as unfocused state
- Single-line Placeholder Position：Same in Empty and Focused Empty states
- Error Priority：Danger Border overrides Focus Border

#### Pointer

- I-beam

### Text Field

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

### Text Area

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

### Search Field

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
  - Icon Color：`--color-text-disabled`

### Number Field

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

### Shortcut Field

#### Shared

##### Anatomy

- Container：同 Text Field
- Keycap
  - Component：Keycap / Popover Surface
  - Placement：Leading
  - Gap：`--spacing-1`
  - ⇧ 与主键各占一个 Keycap
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
  - 触发：快捷键冲突，或 Recording 时按下不可用的键
  - Border Color：`--color-danger-text`

## 2.2 Selection Controls

### Checkbox

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
  - 勾为镂空，透出所在表面
- Indeterminate
  - Icon：`minus-circle`（Fill）
  - Control Color：`--color-bg-checkbox-checked`
  - 横线为镂空，透出所在表面
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

### Color Well

#### Shared

##### Anatomy

- Platform Native Color Well
  - 点击打开系统颜色面板，含不透明度

##### Sizes

- Platform Native

##### States

- Platform Native

### Segmented Control

#### Shared

##### Anatomy

- Container
  - Background：`--color-bg-control`
  - Border Color：`--color-border-control`
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
  - Label Color：`--color-text-primary`
- Selected
  - Background：`--color-segmented-control-selected-bg`
  - Radius：`--radius-control` 减 `--padding-segmented-control`
  - Label Color：`--color-segmented-control-selected-content`
- Hover：None

### Filter Chip

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

### Button

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
  - 外观与 Hover 相同
- Focused
  - Ring Color：`--color-focus-ring`
  - Ring Width：`--focus-ring-width`
  - Ring Offset：`--focus-ring-offset`
- Disabled
  - Background：Transparent
  - Icon Color：`--color-text-disabled`

### Shortcut Action Button

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
- File Edit 树 Object Folder 行菜单：Rename Folder
- File Edit 树 Display Title、Video、Subtitle 行菜单：Rename Files
- 存在 Index、Add Folder、Remove Folder、Rename Folder 或 Rename Files 任务期间，以及数据库压缩进行中时，两个 Rename 项为 Disabled

##### Player Speed Menu

- Surface：Player Chrome
- Item：Menu Item / Radio Menu Item
- Highlight On Open：当前生效倍速

##### Player More Menu

- Surface：Player Chrome
- 圆角、Padding 与 Menu Item 高度与 Player Speed Menu 相同；宽度随菜单项内容
- Item：Menu Item / Submenu Trigger：Audio Track、Subtitle、Default Audio Track、Default Subtitle
- 视频没有音轨时 Audio Track 与 Default Audio Track 为 Disabled

### Submenu

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

### Menu Divider

#### Shared

##### Anatomy

- Divider
  - Color：`--color-border-divider`

##### Sizes

- Inset Inline：`--inset-menu-divider`，两端与 Menu Item 的内容对齐
- Margin Block：`--gap-menu-divider`

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
- Icon：`sidebar-simple`

##### Sizes

- Width：`--size-icon-button`
- Height：`--size-icon-button`
- Icon Size：`--size-control-icon`

##### States

- Default
- Hover
- Focused

### Sidebar Item

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

### Tabs

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

### Tab

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

## 2.6 Tables

### Table

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

### Table Header Cell

#### Shared

##### Anatomy

- Label
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-table-header`
  - Font Weight：Medium
  - Color：`--color-text-secondary`
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
  - 菜单或对话框打开期间不随指针移动；右键菜单的关联行保持 Hover
  - 指针真实移动后落在行上时随之移动；滚动与布局变化不移动它
- Selected
  - Background：`--color-row-selected`
  - Select Mode 下 Shift 加左键点击按区间选中：无选中时从第 1 行选到点击行；点击行已选中时只取消该行；点击行未选中时选中它到最近选中行之间的全部行
  - Unavailable 行不可选中：点击不改变勾选，全选与 Shift 区间选中跳过它，表头的全选状态不计入它
  - 最近选中行是最近一次产生选中的操作所选中的最高行；取消选中不改变它，选中清空时它一并清空
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
- Font Weight：Regular
- Color：`--color-text-secondary`
- Selection：Enabled
- Pointer：I-beam

##### Index Text

- Font Family：`--font-family-base`
- Font Size：`--font-size-caption`
- Font Weight：Regular
- Color：`--color-text-muted`
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

### Selection Action Overlay

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

### Task Status Badge

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

##### Task Count Badge

- Placement：Task Entry 与 Filter Trigger 内图标右侧，按钮随之变宽；与图标字形墨迹的间距为 `--spacing-1`，右侧留白与图标上方留白相同；Filter Dialog 的 Section Header 内名称右侧
- Shape：1 位数为圆形，宽与高相等；2 位及以上为胶囊形，两端为正半圆
- Size：`--size-control-icon`；在 Section Header 内为 `--size-task-count-badge-compact`
- Padding Inline：1 位数为 0；2 位及以上为 `--spacing-2`，在 Section Header 内为 `--padding-task-count-badge-compact-x`
- Background：`--color-text-muted`；在 `--color-player-topbar-gradient-start` 上为 `--color-player-text-primary`；按钮 Disabled 时为 `--color-text-disabled`；按钮 Hover 或 Open 时不变
- Font Family：`--font-family-base`
- Font Size：`--font-size-task-count-badge`；在 Section Header 内为 `--font-size-caption`
- Font Weight：`--font-weight-task-count-badge`
- Text Color：`--color-bg-surface`；在 `--color-player-topbar-gradient-start` 上为 `--color-player-icon-selected`
- States
  - Count
  - Hidden：数量为 0

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

#### Variants

##### Player Chrome

- Background：`--color-player-control-bg-hover`
- Text Color：`--color-player-text-secondary`

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

### Workbench Page Title

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

### Keycap

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

#### Variants

##### Overlay Surface

- Default
  - Background：`--color-overlay-surface-keycap-bg`
- Hover
  - Background：`--color-overlay-surface-keycap-bg-hover`

##### Popover Surface

- Default
  - Background：`--color-popover-surface-keycap-bg`
- Hover
  - Background：`--color-popover-surface-keycap-bg-hover`

## 2.9 Feedback

### Toast

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-menu-bg`
  - Border Color：`--color-player-text-tertiary`（30%）
  - Radius：`--radius-playback-feedback`
  - Shadow：None
- Icon
  - Presence：Optional
  - Color：`--color-player-text-primary`
  - 与 Message 第一行垂直居中
- Message
  - Font Family：`--font-family-base`
  - Font Size：`--font-size-toast`
  - Font Weight：`--font-weight-control`
  - Color：`--color-player-text-primary`
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
  - Color：Platform Native

##### Sizes

- Size：`16px`

##### Motion

- Type：Continuous Rotation
- Duration：`--duration-spinner-motion`
- Easing：`--easing-spinner-motion`

##### States

- Indeterminate

#### Variants

##### Bar

- Track Color：`--color-library-progress-track`
- Fill Color：`--color-library-progress-fill`
- Height：`--height-task-progress-bar`
- Radius：Capsule
- States
  - Determinate

### Spinner

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

### Playback Feedback

#### Shared

##### Anatomy

- Container
  - Background：`--color-player-menu-bg`
  - Border Color：`--color-player-text-tertiary`（30%）
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

### Player Error Banner

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

### Dialog

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
- Loaded
- Disabled

### Cover Summary

#### Structure

1. Cover
2. Content
   1. Title
   2. Supporting Content
      - Description Variant：Description
      - Metadata Variant：
        1. Primary Metadata
        2. Secondary Metadata
   3. Resume or Play Action
      - Split Form：Button / Primary
      - Backdrop Form：Button / Cover Summary

#### Sizes

- Width：Parent Available Width
- Form Switch Width：`--width-cover-summary-form-switch`
- Content Height：两种形态相同，等于 Split Form 的 Cover Height
- Metadata Item Gap：`--spacing-2`
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
- Cover 保持原始比例，使用 Aspect Fill 与 Center Crop。
- Backdrop Form 高度固定，最窄宽度下不裁剪，宽度越大上下裁剪越多。
- 两种形态的 Content 高度相同，Title 在上，Resume or Play Action 在左下角。
- 形态切换时组件高度只变化一次，不随宽度连续变化。
- 禁止拉伸、补边、扩图、镜像、重绘或修改封面文件。
- Content 位于左侧并保持左对齐。
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
- Open
  - 触发：挂靠的菜单打开
  - 外观与 Hover 相同
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

### Player Title

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

### Playback Cue Metadata

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
- Font Size：`--font-size-caption`
- Line Height：`--line-height-playback-cue-metadata`
- Font Weight：`--font-weight-playback-cue-metadata`

##### Appearance

- Text Color：`--color-playback-cue-metadata`
- Background / Border / Radius / Padding：None

##### Layout

- Placement：Below the complete Visual Line Stack

### Subtitle Focus Cue

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

### Playback Cue Result

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

### Playback Cue Reel

#### Shared

##### Anatomy

- Viewport
- Cue Stack
  - Timeline Marker
  - Cue Content
  - Connector
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

- Leading Element：Timeline Marker
- Vertical Alignment：Timeline Marker 与 Primary Cue 第一视觉行的可见字形中心位于同一水平线
- Connector：Connect Adjacent Timeline Markers

#### Cue Timeline States

- Unselected
  - Dot Color：`--color-playback-cue-timeline-muted`
- Selected
  - Dot Color：`--color-playback-cue-timeline-focused`
- Connector Color：`--color-playback-cue-timeline-muted`
- Timeline Visual Priority：Lower than the corresponding Cue Content

#### Timeline Marker Variants

##### Dot

- Size：`--size-playback-cue-timeline-dot`

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

# 3. Layouts

## 3.1 App Shell

### App Sidebar Layout

#### Structure

1. Top Safe Area
2. Navigation Region
   1. Search / Magnifying Glass
   2. Recent / Clock
   3. Library / Grid
   4. File / Folder
   5. Excerpt / Bookmark

#### Components

- Sidebar
- Sidebar Toggle
- Sidebar Item / Primary

#### Sizes

- Width：`--width-app-sidebar`
- Padding Inline：`--padding-app-sidebar-x`
- Padding Block：`--padding-app-sidebar-y`
- Navigation Item Gap：`--spacing-1`

#### States

- Expanded
- Collapsed
  - Auto Collapse：窗口宽度 ≤ `--min-width-workbench-page-content` + `--width-app-sidebar` 时自动收起，收起后不自动展开。只在 Workbench 可见时判定，从播放页返回时判定一次。

### App Topbar Layout

#### Structure

1. Window Controls
2. Sidebar Segment
3. Sidebar Toggle Slot
4. Function Region
   1. Back Action
   2. Forward Action
   3. Page Title
5. Trailing Function Region
   1. Task Entry
   2. Settings Entry
6. Draggable Region

#### Components

- Window Controls：系统原生红绿灯
- Sidebar Toggle
- Icon Button / Back
- Icon Button / Forward
- Workbench Page Title
- Icon Button / Default
- Information Badge / Task Count Badge

#### Sizes

- Height：`--height-workbench-topbar`
- Sidebar Toggle：在 `--height-app-topbar` 内垂直居中，与 Window Controls 同一中线
- Function Region Gap：`--gap-app-topbar-content`
- Back to Forward Gap：`--spacing-1`
- Task to Settings Gap：`--spacing-1`
- Sidebar Segment Width：`--width-app-sidebar`
- Function Region Minimum Width：`--min-width-workbench-page-content`，由 Function Region 与 Trailing Function Region 共用
- Window Controls Inset：`--spacing-6`
- Collapsed Toggle Gap After Window Controls：`--gap-app-topbar-toggle-after-window-controls`

#### Page Title

- 一级页：Search、Recent、Library、File、Excerpt
- 二级页：None
- 页面已不存在：`Unknown Page`
- 宽度：Back、Forward 与 Trailing Function Region 之外的剩余宽度，不足时尾部截断

#### States

- History Start：Back Disabled
- History End：Forward Disabled
- Sidebar Expanded
- Sidebar Collapsed
- Below Function Region Minimum Width：Function Region 与 Trailing Function Region 随页面一起横向滚动，Window Controls 与 Sidebar Toggle 不参与
- Hidden On Playback：Task Entry 与 Settings Entry 改由播放页与 Playback Overlay 的顶栏显示
- Settings Window Open：Settings Entry Open，窗口最小化期间保持

### Workbench Titled Page Layout

#### Usage

- Search
- Recent
- Library
- File
- Excerpt

#### Structure

1. Page Content

#### Components

- Scrollbar / Vertical
- Scrollbar / Horizontal

#### Sizes

- Page Content Minimum Width：`--min-width-workbench-page-content`

#### Spacing

- Page Padding Inline：`--spacing-8`
- Page Scrollbar Channel：`--width-page-scrollbar-channel`，位于 Trailing Padding 之外并恒定预留
- Page Padding Top：`--spacing-1`
- Page Padding Bottom：`--spacing-6`

#### Scrolling

- Vertical Scrollbar：Page Viewport Trailing Edge
- Horizontal Scrollbar
  - Presence：Page Viewport Width < Page Content Minimum Width
  - Position：Page Viewport Bottom Edge
- 与 Table Horizontal Scrollbar 同时存在时，Page Horizontal Scrollbar 占据底部，Table Horizontal Scrollbar 上移一个 Scrollbar 高度。

### Toast Layout

#### Position

- Anchor：App Center，即 App 窗口中心，含 Sidebar 与顶栏
- 最新一条 Toast 的中心与 Anchor 重合；较早的依次向上堆叠，最新一条的位置不随数量变化
- Layer：Above Pages, Page Overlays and Command Panel; Below Dialogs

#### Stacking

- Item Gap：`--spacing-4`
- Maximum Items：4；新的一条出现时，超出的最早一条立即消失
- 新的一条与已显示的某条 Scenario ID 与文案都相同时，不新增，该条移到最新位置并重新计时

#### Timing

- Duration：Toast / Duration，自出现起计时，到时消失；焦点、指针悬停与窗口是否可见都不影响计时

#### Components

- Toast

#### States

- Entering
- Visible
- Exiting

## 3.2 Settings

### Settings Window Layout

#### Structure

1. Full-height Sidebar Region
   1. Platform Native Window Controls
   2. Settings Sidebar Layout
2. Category Content Region

#### Components

- Platform Native Window Controls
- Settings Sidebar Layout
- Settings Category Layout

#### Visual Rules

- Sidebar Extends To Window Top
- Category List 与 Category Content 都从 Titlebar Region 下方开始
- Visible Window Title：None

#### Sizes

- Default Width 与 Minimum Width：`--width-settings-window`
- Default Height：`--height-settings-window`
- Minimum Height：`--min-height-settings-window`
- Titlebar Region Height：`--height-settings-titlebar`
- Sidebar Width：`--width-settings-sidebar`

#### States

- Open
- Closed

### Settings Sidebar Layout

#### Structure

1. Category List：General、Play、Shortcuts、Subtitle、Maintenance、Developer；打开时选中 General

#### Components

- Sidebar Item / Primary
- Scrollbar / Vertical

#### Spacing

- Padding Inline：`--padding-app-sidebar-x`
- Padding Bottom：`--padding-app-sidebar-y`
- Item Gap：`--spacing-1`

#### States

- Default
- Scrolling

### Settings Category Layout

#### Structure

1. Page Title：`--font-size-page-title`，`--font-weight-page-title`，`--color-text-primary`
2. Group Stack
   1. Group Title：`--font-size-body`，Semibold，`--color-text-primary`
   2. Group Description：可选；`--font-size-caption`，`--color-text-muted`
   3. Card：背景 `--color-settings-group-bg`；边框 `--color-border-divider`，宽度 `--border-width-control`；圆角 `--radius-settings-group`；宽度跟随窗口，不设上限

#### Groups

- General：Appearance、Search、Language、Deep Link
- Play：Play、Decode
- Maintenance：Maintenance
- Developer：Developer、FTS Vocabulary Data
- 没有原标题的 Group 使用原分类名；原分类的说明作为 Group Description

#### Row

1. 名称：`--font-size-body`，`--color-text-primary`；说明可选，位于名称下方，`--font-size-caption`，`--color-text-muted`
2. 控件：靠右
- 行与行之间：分隔线 `--color-border-divider`，宽度 `--border-width-control`，左右各内缩 `--spacing-4`
- Min Height：`--min-height-settings-row`

#### Components

- Text Field
- Text Area
- Number Field
- Checkbox
- Switch
- Color Well
- Segmented Control
- Button

#### Spacing

- Page Padding：Leading `--spacing-6`；Trailing `--spacing-6` 加 `--width-page-scrollbar-channel`；Bottom `--spacing-6`
- Page Title 与第一个 Group：`--spacing-4`
- Group 之间：`--spacing-6`
- Group Title 与 Group Description：`--spacing-1`
- Group Title 水平缩进：`--spacing-4`
- Group Title 区与 Card：`--spacing-2`
- Row Padding：水平 `--spacing-4`；垂直 `--padding-settings-row-y`
- 名称与说明：`--spacing-1`
- 名称与控件：至少 `--spacing-4`

#### Layout

- Language 下拉框宽度：`--width-settings-popup`
- Number Field 宽度：`--width-settings-number-field`
- Maintenance 状态颜色：正常 `--color-text-secondary`；建议压缩 `--color-warning-text`；完成 `--color-success-text`；失败 `--color-danger-text`
- Maintenance 的 Refresh、Compact Database 与 Developer 的 Refresh：Button / Neutral，位于所在行右侧
- Maintenance 数据库路径：`--font-size-caption`，`--color-text-muted`，单行，中间省略

### Settings Shortcuts Layout

#### Structure

1. Page Title
2. Group `Shortcuts`：Open Command Panel
3. Group `Playback` 及其功能
4. Group `Playback Overlay & Command Panel` 及其功能

#### Components

- Shortcut Field
- Icon Button / Default：Restore Default

#### Row

1. 功能名称
2. Shortcut Field
3. Restore Default：当前为默认键时 Disabled

#### Layout

- Shortcut Field 与 Restore Default 靠右
- Validation Message 位于 Shortcut Field 下方，左侧与 Shortcut Field 对齐，较长时向功能名称一侧延伸；有提示时行随之变高，功能名称与 Shortcut Field 保持垂直居中对齐

#### Spacing

- Shortcut Field 与 Restore Default：`--spacing-1`

### Settings Subtitle Layout

#### Structure

1. Page Title
2. Group `Text`：Font、Size、Style、Color、Letter Spacing、Line Spacing
3. Group `Border`：Type、Outline Color、Outline Width、Background Color、Blur
4. Group `Shadow`：Shadow Color、Shadow Offset
5. Group `Position`：Horizontal、Margin X、Vertical、Margin Y
6. Restore Defaults

#### Components

- Number Field：Size、Letter Spacing、Line Spacing、Outline Width、Blur、Shadow Offset、Margin X、Margin Y
- Checkbox / Form Checkbox：Bold、Italic
- Color Well：Color、Outline Color、Background Color、Shadow Color
- Segmented Control：Type、Horizontal、Vertical
- Button / Neutral：Choose…、Restore Defaults

#### Row

1. 设置项名称
2. 控件；Font 为当前字体名称与 Choose…，Choose… 打开系统字体面板

#### Layout

- Number Field 宽度：`--width-settings-number-field`
- 当前 Type 用不到的行，控件为 Disabled：Outline 时 Background Color；Opaque Box 时 Outline Color、Outline Width；Background Box 时 Shadow Color、Shadow Offset
- Restore Defaults：位于最后一个 Card 下方，靠右；Leading Icon `arrow-counter-clockwise`；全部为默认值时 Disabled

#### Spacing

- Font 名称与 Choose…：`--spacing-3`
- Bold 与 Italic：`--spacing-6`
- 最后一个 Card 与 Restore Defaults：`--spacing-6`

## 3.3 Recent
### Recent Layout

#### Structure

1. Tabs：`Recent Videos`、`Recent Excerpt Lists`
2. Recent Videos：Recent Watching Card Grid
3. Recent Excerpt Lists：Excerpt List Card Grid

#### Components

- Tabs
- Tab
- Recent Watching Card Layout
- Excerpt List Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Tabs 左对齐，首个标签与页面内容左边界对齐。
- 默认 Tab：Recent Videos。Tab 选择在 App 运行期间保留，重新启动后回到默认。

#### Sizes

- Tabs to Content Gap：`--spacing-4`
- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Recent Watching Card Layout

#### Structure

1. Cover Region
   1. Cover
   2. Playback Progress
   3. Elapsed / Duration
2. Folder Name：`folderTitle`
3. Meta Row
   1. `EPXX`
   2. Watch Status

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

## 3.4 Library and File

### Library Overview Layout

#### Structure

1. Summary Row
2. Tabs：`Video`、`Metadata`
3. Video：Adaptive Folder Card Grid
4. Metadata：Library File Tree Layout / Roots

#### Components

- Section Title
- Button / Primary
- Tabs
- Tab
- Library Folder Card Layout
- Library File Tree Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Tabs 左对齐，首个标签与页面内容左边界对齐。
- 默认 Tab：Video。
- Summary Row 与 Button / Primary 在两个 Tab 下都显示。

#### Sizes

- Summary to Tabs Gap：`--spacing-4`
- Tabs to Content Gap：`--spacing-4`
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

1. Cover Summary
2. Tabs：`Video`、`Metadata`
3. Video：Episode Grid
4. Metadata：Library File Tree Layout / Folder

#### Components

- Cover Summary / Library Variant
- Tabs
- Tab
- Library Episode Grid Layout
- Library File Tree Layout

#### Layout

- Content Page Padding Inline 与 Excerpt List Detail 相同。
- Cover Summary 与 Episode Grid 使用相同宽度和水平边界。
- Cover Summary 宽度跟随页面可用宽度变化，并在 Split Form 与 Backdrop Form 之间切换。
- Tabs 左对齐，首个标签与页面内容左边界对齐。
- 默认 Tab：Video。
- Cover Summary 在两个 Tab 下都显示。

#### Spacing

- Content Page Padding Inline：`--spacing-8`
- Content Page Padding Top：`--spacing-1`
- Content Page Padding Bottom：`--spacing-6`
- Cover Summary to Tabs Gap：`--spacing-6`
- Tabs to Content Gap：`--spacing-4`

#### Scrolling

- Vertical Scroll Context：Single Page Viewport
- Cover Summary：Scrollable
- Episode Grid：Scrollable
- Vertical Scrollbar：Page Viewport Trailing Edge

#### States

- Unknown：文件夹已不在索引中，页面正文为 Empty State / Empty Hint，文案 `This page no longer exists.`

### Library Episode Grid Layout

#### Structure

1. Recent Watching Card Grid

#### Components

- Recent Watching Card Layout

#### Sizes

- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Library File Tree Layout

#### Structure / Roots

1. Root Path
   1. Object Folder
      1. Display Title Object
         1. Video File
         2. Subtitle Files

#### Structure / Folder

1. Object Folder
   1. Display Title Object
      1. Video File
      2. Subtitle Files

#### Structure / Edit

1. Object Folder
   1. Display Title Object
      1. Video File
      2. Subtitle Files

#### Labels

- Root Path：Complete Path Without Leading or Trailing `/`
- Object Folder：Path Relative to Root Without Leading `/`
- Object Folder / Edit：Complete Path
- All Labels：Complete Display / Character Wrapping / No Truncation

#### Rows

- Minimum Height：`--height-control`
- Padding Block：`--spacing-2`
- Hierarchy Indent：`--spacing-6`
- Anatomy：Disclosure Slot + `--spacing-2` + Icon + `--spacing-2` + Label
- Disclosure Slot / Icon Size：`--size-control-icon`
- Disclosure Slot：Reserved For Every Row
- Root Path / Object Folder / Display Title：`--font-size-body` / `--font-weight-control` / `--color-text-primary`
- Video / Subtitle：`--font-size-body` / Regular / `--color-text-secondary`
- Multiline Alignment：Disclosure and Icon align with Label first line

#### Icons

- Root Path / Object Folder：Folder
- Display Title：`stack`
- Video：Video
- Subtitle：Subtitle

#### States

- Default / Roots：Root Paths Expanded / Object Folders Collapsed
- Default / Folder：Object Folder Expanded / Display Title Objects Collapsed
- Default / Edit：Object Folders Collapsed / Display Title Objects Collapsed
- Display Title / Video / Subtitle：Independent Row Hover using `--color-row-hover`
- Root Path / Object Folder Hover：None；Edit 的 Object Folder 与 Display Title 相同
- Object Divider：Between Display Title Objects / Starts At File Icon Column / `--color-border-divider`
- Inside Object Divider：None
- 展开状态与 Tab 选择不跨界面保留：进入或离开 Library Folder Detail Layout、离开 Library 页面后都回到默认。

### File Page Layout

#### Structure

1. Tabs：`Index`、`Edit`
2. Index
   1. Page Description
   2. Action Row：`Add Folder`、`Index Now`
   3. Index Status
   4. Root Folder List
3. Edit：Library File Tree Layout / Edit

#### Components

- Tabs
- Tab
- Button / Neutral
- Button / Destructive
- Empty State
- Confirmation Dialog
- Library File Tree Layout
- Menu / Context Menu
- Rename Dialog Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Tabs 左对齐，首个标签与页面内容左边界对齐。
- 默认 Tab：Index。Tab 选择在 App 运行期间保留，重新启动后回到默认。
- Edit 列出全部 Object Folder，含自身有配对的根目录，不显示 Root Path 层级；有包含关系的根目录归为一组，以最外层根目录为准，组的顺序取组内最早添加的根目录在 Root Folder List 中的位置；展开状态离开页面后回到默认；没有任何配对时显示 Empty State / Empty Hint，文案 `No indexed content.`
- Page Description、Action Row 与 Root Folder List 均左对齐。
- Index Status 只在有状态时出现，没有状态时不占高度。
- 没有根目录时，Root Folder List 的位置显示 Empty State。
- Root Folder List 按添加顺序列出全部根目录，含被其它根目录包含的根目录。
- 移除根目录前弹出 Confirmation Dialog。
- 存在 Index、Add Folder、Remove Folder、Rename Folder 或 Rename Files 任务期间，以及数据库压缩进行中时，Add Folder、Index Now 与 Remove 为 Disabled。

#### Spacing

- Tabs to Content Gap：`--spacing-4`
- Page Description to Action Row：`--spacing-4`
- Action Row to Index Status：`--spacing-4`
- Index Status to Root Folder List：`--spacing-6`
- Action Row Gap：`--spacing-2`

#### Index Status

- Anatomy：Icon + `--spacing-2` + Status Line，Detail Line 与 Status Line 左对齐
- Status Line：`--font-size-body` / Regular，成功为 `--color-success-text`，失败为 `--color-danger-text`
- Detail Line：`--font-size-caption` / Regular / `--color-text-muted`
- Line Gap：`--spacing-1`

#### Root Folder Row

- Anatomy：Folder Name 与 Path 上下两行，尾部为 Button / Destructive
- Folder Name：`--font-size-body` / `--font-weight-control` / `--color-text-primary`
- Path：`--font-size-caption` / Regular / `--color-text-muted`
- Padding Block：`--spacing-3`
- Line Gap：`--spacing-1`
- Divider：`--color-border-divider`

## 3.5 Search and Excerpt

### Excerpt List Overview Layout

#### Structure

1. Summary Row
2. Adaptive Excerpt List Card Grid

#### Components

- Section Title
- Button / Primary
- Excerpt List Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout

#### Ordering

- 按列表创建时间正序排列，最新创建的列表在最后

#### Sizes

- Summary to Grid Gap：`--spacing-4`
- Summary Height：`--height-control`
- Summary Item Gap：`--spacing-3`
- Card Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Grid Gap：`--gap-library-recent-grid`

### Excerpt List Card Layout

#### Structure

1. Cover Region
2. List Name
3. Description

#### Components

- Media Card
- Cover
- Information Badge / Cover Badge
- Menu / Context Menu

#### Sizes

- Width：`--width-library-recent-card-min` to `--width-library-recent-card-max`
- Content Gap：`--spacing-2`

#### Context Menu

1. `Edit List`
2. `Delete List`

只有一个 Excerpt List 时 `Delete List` 为 Disabled。

#### States

- Default
- Selected
- Disabled

### Excerpt List Detail Layout

#### Structure

1. Cover Summary
2. Toolbar
3. Table
4. Selection Action Overlay

#### Components

- Cover Summary
- Search / Excerpt Toolbar Layout
- Search / Excerpt Table Layout
- Selection Action Overlay Layout

#### Layout

- Cover Summary、Toolbar 与 Table Content Region 使用相同宽度和水平边界。
- Cover Summary 宽度跟随页面可用宽度变化，并在 Split Form 与 Backdrop Form 之间切换。

#### Spacing

- Page Padding Inline：`--spacing-8`
- Cover Padding Top：`--spacing-1`
- Cover to Toolbar Gap：`--gap-cover-summary-to-toolbar`
- Pinned Region Item Gap：`--spacing-3`
- Page Padding Bottom：`--spacing-6`，与 Workbench Titled Page Layout 一致

#### Scrolling

- Vertical Scroll Context：Single Page Viewport
- Cover Summary：Scrollable
- Toolbar 与 Table Header：Pinned
- Vertical Scrollbar：Page Viewport Trailing Edge

#### States

- Unknown：列表已删除，页面正文为 Empty State / Empty Hint，文案 `This page no longer exists.`

### Search / Excerpt Toolbar Layout

#### Structure

1. Search Field
2. Filter Trigger
3. Select Mode Action

#### Components

- Search Field
- Icon Button
- Information Badge / Task Count Badge

#### Sizes

- Height：`--height-filter-bar-control`
- Item Gap：`--spacing-3`
- Width：Fill Parent Content Width

#### States

- Default
- Filter Dialog Open
- Select Mode
- Calculating
- Select Unavailable：结果计算中，或当前结果没有可选行时，Select Mode Action 为 Disabled

### Selection Action Overlay Layout

#### Position

- Anchor：Table Viewport Bottom Center
- Flow：Overlay

#### Components

- Selection Action Overlay
- Shortcut Action Button / Popover Surface
- Keycap / Popover Surface

#### Structure

1. Selected Count
2. Export to Anki `A`
3. Copy Deep Links `D`
4. Copy Table `T`
5. Exit `Esc`

#### Layout

- 第 1 项在上，第 2 至 5 项在下；第 2 至 5 项宽度不足时换行
- Exit 位于末位，退出 Select Mode，与工具栏 Select Mode Action 关闭时行为一致

#### Spacing

- Group Gap：`--spacing-2`
- Action Gap：`--spacing-2`
- Line Gap：`--spacing-2`
- Padding Inline：`--spacing-3`
- Padding Block：`--spacing-2`

#### States

- Hidden：Select Mode 关闭
- Visible：Select Mode 开启

### Search / Excerpt Table Layout

#### Structure

1. Fixed Header
2. Scrollable Body
3. Horizontal Scrollbar

#### Components

- Table
- Table Header Cell
- Table Header Cell / Selection
- Table Row
- Table Cell / Text
- Table Cell / Interactive Text
- Checkbox / Table Selection Checkbox
- Scrollbar / Horizontal

#### Layout

- Fixed Header 与 Scrollable Body 使用相同宽度和水平边界，横向滚动时同步移动。
- Horizontal Scrollbar：Page Viewport Bottom Edge，长度与 Table 宽度一致。

#### Ordering

- Search：按 Display Title、字幕路径、Cue 时间的顺序排列；首屏与搜索完成后的顺序一致
- Excerpt：按收藏时间正序排列，最新收藏的在最下方

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
  - Presence：Excerpt
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
   1. Title：`Edit Cover`
   2. Close Button
2. Cover Region
   - Default：Cover / Editor Action
   - Image Selected：Cover Crop Editor
3. Support Text
4. Footer
   1. Cancel
   2. Save

#### Components

- Dialog
- Cover
- Cover Crop Editor
- Button / Neutral
- Button / Primary

#### Sizes

- Width：`--width-dialog-small`
- Cover Region：内容宽度，`--aspect-library-cover`

#### Spacing

- Region Gap：`--gap-cover-dialog-region`
- Footer Action Gap：`--spacing-2`

#### States

- Preview
  - Content：Current Cover or Default Cover
- Hovering Cover Action
- Crop Editing
- Saving

### Excerpt List Editor Dialog Layout

#### Structure

1. Header
   1. Title
   2. Close Button
2. Main Region
   1. Cover Region
      1. Cover / Editor Action
      2. Cover Crop Editor
      3. Support Text
   2. Form Region
      1. Name Field
      2. Description Field
3. Footer
   1. Cancel
   2. Save

#### Components

- Dialog
- Cover
- Cover Crop Editor
- Text Field
- Text Area
- Button / Neutral
- Button / Primary

#### Layout

- Width：窗口宽度不小于 `--width-dialog-x-large` 加两侧 `--spacing-6` 时为 `--width-dialog-x-large`，否则为 `--width-dialog-small`
- Main Region：`--width-dialog-x-large` 时 Two Columns, Top Aligned；`--width-dialog-small` 时 One Column，Cover Region 在上，Form Region 在下，间距为 Column Gap
- Cover Width：`--width-dialog-small` 减两侧 `--inset-dialog`，两种排版相同
- Form Region Width：Two Columns 时为剩余宽度；One Column 时与 Cover Width 相同
- Description Field 的 Container 高度：Two Columns 时底边与 Cover 底边对齐；One Column 沿用同一高度

#### Spacing

- Region Gap：`--gap-cover-dialog-region`
- Column Gap：`--spacing-6`
- Cover to Support Text Gap：`--spacing-3`
- Field Gap：`--spacing-2`
- Footer Action Gap：`--spacing-2`

#### States

- New
- Edit
- Validation Error
- Saving

### Rename Dialog Layout

#### Structure

1. Header
   1. Title：`Rename Folder` 或 `Rename Files`
   2. Close Button
2. Form Region
   1. Current Name：Label 与当前名
   2. New Name Field
3. Footer
   1. Cancel
   2. Rename

#### Components

- Dialog
- Text Field
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-medium`
- Form Region 单列，占满内容宽度；Current Name 与 New Name Field 的右缘与最右侧按钮的右缘对齐。
- Current Name 的 Label 与 Text Field 的 Label 相同；Rename Folder 显示完整路径，Rename Files 显示视频与字幕去掉扩展名后的公共名。

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap：`--spacing-4`
- Label to Current Name Gap：`--spacing-1`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error

### Export to Anki Dialog Layout

#### Structure

1. Header
   1. Title：`Export to Anki`
   2. Close Button
2. Form Region
   1. Cue Text Side：Label 与 Segmented Control（`Front`、`Back`）
   2. Required：Label 与 Checkbox `Cue Text`、`Audio`
   3. Optional：Label 与 Checkbox `Screenshot`、`Cue Group Text`、`Display Title`、`Time Range`、`Deep Link`、`Subtitle File Path`、`Video File Path`
   4. File Name Field
   5. Location：Label、完整文件夹路径与 Icon Button / Default（`folder`）
3. Footer
   1. Cancel
   2. Export

#### Components

- Dialog
- Segmented Control
- Checkbox / Form Checkbox
- Text Field
- Icon Button / Default
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-large`
- Form Region 单列，占满内容宽度；各组 Label 与 Text Field 的 Label 相同。
- Checkbox 每行两个，两列等宽，按 Structure 的顺序从左到右、从上到下排列；Required 的 Checkbox 始终为 Checked + Disabled。
- Location 路径的文字同 Rename 的 Current Name，单行，过长时中间截断；文件夹按钮在路径右侧，字形墨迹右缘与内容右缘对齐。
- 默认：Cue Text Side 为 `Back`，Optional 只勾 `Screenshot`，Location 为 Downloads。这三项的选择重新启动后保留，Search 与 Excerpt 共用；File Name 每次打开时重新生成。

#### Spacing

- Region Gap：`--spacing-4`
- Group Gap：`--spacing-4`
- Label to Content Gap：`--spacing-2`
- Checkbox Row Gap：`--spacing-3`
- Checkbox Column Gap：`--spacing-4`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error

### Filter Dialog Layout

#### Structure

1. Header
   1. Title：`Filter`
   2. Close Button
2. Sections：Duration、Character、Language、Watch Status、Folder，从上到下
   1. Section Header：图标、名称与选中数量
   2. Filter Chip：每个选项一个
3. Footer
   1. Reset
   2. Cancel
   3. Show：Search 为 `Show N results`，Excerpt 为 `Show N excerpts`；总数未知时为 Spinner 与 `Calculating`

#### Components

- Dialog
- Filter Chip
- Information Badge / Task Count Badge
- Spinner
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-x-large`
- Height：`--height-filter-dialog`；Header 与 Footer 不动，Sections 滚动，内容不足时下方留空
- Section Header：图标 `--size-control-icon`；名称 `--font-size-control`、Medium；颜色 `--color-text-secondary`
- Filter Chip 从左到右排列，宽度不足时换行
- Folder 的 Filter Chip：每个已索引文件夹一个，名称与顺序同 Library Overview Layout 的 Video 标签页，Search 与 Excerpt 相同
- Reset 靠左，Cancel、Show 靠右；对话框内没有选中时 Reset 为 Disabled；总数未知时 Show 为 Disabled

#### Spacing

- Region Gap：`--spacing-4`
- Section Gap：`--spacing-4`
- Section Header Content Gap：`--spacing-2`
- Section Header to Chips Gap：`--spacing-2`
- Chip Gap：`--spacing-2`
- Chip Line Gap：`--spacing-2`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Calculating

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

#### Sizes

- Width：`--width-dialog-small`

#### Spacing

- Region Gap：`--spacing-4`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Destructive
- Confirm Disabled
- Submitting

### Task Panel Layout

#### Structure

1. Header
   1. Title：`Task`
   2. Close Button
2. Tabs：`Current`、`Completed`、`Incomplete`，水平居中
3. Task Card List

#### Components

- Dialog
- Tabs
- Tab
- Icon Button / Dialog Close
- Scrollbar / Vertical

#### Sizes

- Width：`--width-dialog-x-large`
- Height：`--height-task-panel`

#### Spacing

- Region Gap：`--spacing-4`
- Card Gap：`--spacing-3`
- Task Card List：卡片与左右边缘相距 `--inset-dialog`，滚到底时最后一张卡片与底边相距 `--inset-dialog`

#### States

- Current
- Completed
- Incomplete
- Empty

### Task Card Layout

#### Structure / Current

1. Icon（Leading，31×31px，Top 16px 对齐）
2. Line 1: Title（动作前缀 + 目标名称，统一字重与字色，单行截断，无路径）
3. Line 2: Progress Text（In Progress 阶段文字 / 导出张数；Queued 状态与数量）
4. Line 3: Progress Bar（仅 In Progress，16px 高度容器居中展示 4px Capsule 进度条）

#### Structure / History

1. Icon（Leading，31×31px，Top 16px 对齐）
2. Line 1: Title（动作前缀 + 目标名称，统一字重与字色，单行截断，无路径）
3. Line 2: 数量与时间（Completed 与 Incomplete 格式一致）
4. Line 3: Error Message（仅 Incomplete，16px 高度容器内单行尾部截断展示）

#### Icon Mapping

- 导出为 Anki：`anki-star`（实心）
- 修改文件夹或文件名称：`pencil-simple`
- Index：`arrow-clockwise`
- Add Folder：`folder-plus`
- Remove Folder：`minus-circle`

#### Components

- Progress Indicator / Bar

#### Sizes

- Padding：`--spacing-4`
- Icon Size：`--size-task-card-icon`
- Icon to Content Gap：`--spacing-4`
- Row Gap：`--spacing-1`
- Dynamic Row Height：`16px`
- Radius：`--radius-control`
- Background：`--color-bg-dialog`
- Border Color：`--color-border-control`

#### Text

- Title Font Size：`--font-size-body`
- Title Font Weight：`--font-weight-control`
- Title Color：`--color-text-primary`
- Detail Font Size：`--font-size-caption`
- Detail Color：`--color-text-muted`
- Error Color：`--color-danger-text`

#### States

- In Progress
- Queued
- Completed
- Incomplete

## 3.7 Player

### Player Topbar Layout

#### Structure

1. Window Controls
2. Return Action
3. Flexible Spacer
4. Player Title
5. Flexible Spacer
6. Trailing Function Region
   1. Task Entry
   2. Settings Entry

#### Components

- Window Controls：系统原生红绿灯
- Icon Button / Default：返回 Workbench
- Player Title
- Icon Button / Default
- Information Badge / Task Count Badge

#### Sizes

- Height：`--height-app-topbar`
- Task to Settings Gap：`--spacing-1`
- Padding Inline：`--padding-player-topbar-x`
- Window Controls：与 App Topbar Layout 同一位置，起点 `--spacing-6`，在 `--height-app-topbar` 内垂直居中
- Return Action：与 Window Controls 同一水平中线
- Return Action Gap：`--gap-player-window-controls-return`
- Fullscreen：Window Controls 由系统标题栏显示，Return Action 起点改为 `--padding-player-topbar-x`
- 居中元素可用宽度：顶栏宽度减去左右占用较大一侧的两倍，居中元素始终在顶栏中线上

#### Surface

- Gradient Start：`--color-player-topbar-gradient-start`
- Gradient End：`--color-player-topbar-gradient-end`

#### States

- Visible
- Interaction Suppressed
- Hidden

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
- Hidden

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

- Anchor：Player Stage Center
- 水平与垂直双向居中，内容变长时以中心为基准向两侧延伸，达到最大宽度后换行并向上下延伸
- Layer：Above Video, Playback Overlay and Command Panel

#### Timing

- Duration：Playback Feedback / Duration
- 列表中没有有效项时导航（上一个、下一个、Auto Switch、视频播完自动播放下一个）：由 Playback Feedback 呈现（持续 1 秒），文案按来源为 `No Available Results`、`No Available Excerpts`、`No Available Videos`

#### Components

- Playback Feedback

#### States

- Hidden
- Entering
- Visible
- Exiting

### Player Error Banner Layout

#### Position

- Anchor：App 窗口左上角，不锚定视频画面
- Padding Top：`--height-app-topbar` 与 `--spacing-3` 之和
- Padding Leading：`--spacing-6`
- 窗口变窄使视频出现黑边时仍在顶栏之下，可落在黑边上；全屏同此规则
- Layer：Above Video, Playback Overlay and Command Panel
- 不随 Player UI 隐藏

#### Lines

| 行 | 出现条件 | 文案 |
| --- | --- | --- |
| 视频 | 视频文件无法加载 | `Couldn’t load the video file: <绝对路径>` |
| 视频 | 播放器的其它错误 | `Playback error: <播放器给出的原因>` |
| 字幕 | 字幕文件无法读取 | `Couldn’t load the subtitle file: <绝对路径>` |
| 无效项 | 播放或打开不在数据库中的项 | `This item is no longer in the library` |

- 文案不区分 ASS 与 SRT，也不出现渲染器等内部名称

#### Timing

- Duration：Player Error Banner / Duration，自出现起计时；对应的视频或字幕被替换时提前消失，两者以先到者为准。视频那一行的来源是当前视频，字幕那一行的来源是当前字幕，切换视频同样视为替换
- 同一行出现新的报错时替换旧的并重新计时
- 焦点、指针与窗口是否可见都不影响计时；暂停、播放、拖动进度、开关 Playback Overlay 同样不影响
- 各行均消失时框消失

#### Components

- Player Error Banner

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
4. Playback Footer

#### Components

- Playback Topbar Layout
- Playback Current Layout
- Playback Playlist Layout
- Playback Collage Editor Layout
- Playback Footer Layout

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
- Covered
  - 触发：Command Panel 打开
  - 内容照常显示，不接受指针、滚轮与键盘
  - 已展开的菜单保持展开
- Closing

### Playback Topbar Layout

#### Structure / Normal

1. Window Controls
2. Return Action
3. Tabs
4. Trailing Function Region
   1. Collage Action：仅 Current
   2. Task Entry
   3. Settings Entry

#### Structure / Editing Collage

1. Window Controls
2. Return Action
3. Editing Title
4. Trailing Function Region
   1. Collage Action：Open
   2. Task Entry
   3. Settings Entry

#### Components

- Window Controls：系统原生红绿灯
- Icon Button / Default：返回 Workbench
- Icon Button / Default
- Information Badge / Task Count Badge
- Tabs
- Tab
- Editing Title：与 Tab / Selected 的 Label 相同，无 Selection Indicator

#### Sizes

- Height：`--height-app-topbar`
- Tabs 与 Editing Title 最大宽度：顶栏的居中元素可用宽度

#### Spacing

- Trailing Margin：`--spacing-4`
- Trailing Gap：`--spacing-1`
- Window Controls 与 Return Action：与 Player Topbar Layout 同一位置

#### Keyboard

- Focused Tab：None
- `Tab`：Switch Current / Playlist

#### States

- Current
- Playlist
- Editing Collage

### Playback Footer Layout

#### Structure

1. Status
2. Action Region

#### Components

- Shortcut Action Button
- Keycap

#### Sizes

- Minimum Height：`--min-height-playback-footer`
- Action Gap：`--spacing-1`

#### Layout

- Status 靠左，动作按钮靠右
- 一行放不下时动作按钮换行并右对齐，区域随之增高，内容不省略

#### Actions

| 所在界面 | Status | 动作 |
| --- | --- | --- |
| Playback Current | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Current / Editing Collage | 字幕条数 | Select `Return` |
| Playback Playlist / Subtitle Playlist | 字幕条数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |
| Playback Playlist / Video Playlist | 视频数 | Play `Return` |
| Command Panel Root | None | Open `Return` |
| Command Panel / Recent Videos | 视频数 | Open `Return` |
| Command Panel / Recent Excerpt Lists | 摘录集数 | Open `Return` |
| Command Panel / Search Results | 结果数 | Save to Excerpt List `S`、Copy Cue Text `C`、Copy Deep Link `X`、Play `Return` |

- Save to Excerpt List 打开 Excerpt Destination Submenu 选择目标列表，不直接保存；结果由 Playback Feedback 呈现，Icon 为实心书签
- 对不在数据库中的项执行 Save to Excerpt List 或 Copy Deep Link 时拦截，由 Playback Feedback 呈现（持续 1 秒），Icon 为 warning，文案 `Not in Library`；执行 Play 时由 Player Error Banner 报错；操作被拦截时 Playback Overlay 与 Command Panel 保持打开
- 在 Command Panel 的 Recent Excerpt Lists 中打开没有有效项的列表时拦截，由 Playback Feedback 呈现（持续 1 秒），文案 `No Available Excerpts`，面板保持打开
- `S`、`C`、`X` 为默认键位，Keycap 显示 Settings / Shortcuts 中的当前键位，⇧ 与主键各占一个 Keycap；快捷键已清空或冲突时不显示 Keycap

#### States

- Default

### Playback Current Layout

#### Structure

1. Subtitle Region
   1. Playback Cue Reel / Focus Cue Reel
   2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Playback Cue Metadata
- Scrollbar / Vertical

#### Sizes

- Maximum Content Width：`--width-subtitle-focus-content-max`
- Cue Gap：`--gap-subtitle-focus-cue`

#### Cue Timeline

- Marker：Dot
- Metadata Ordinal：None

#### States

- Loading
- Ready
- Empty：当前字幕不在数据库中时，显示 Empty State / Empty Hint，文案 `This subtitle is no longer in the library.`
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
- Playback Cue Metadata
- Scrollbar / Vertical
- Library Episode Grid Layout
- Recent Watching Card Layout

#### Cue Timeline / Subtitle Playlist

- Marker：Dot
- Metadata Ordinal：Cue Playlist 1-based Position，形如 `#238`

#### States

- Subtitle Playlist
- Video Playlist
- Loading
- Ready
- Empty：播放列表中没有仍在数据库中的项时，显示 Empty State / Empty Hint，文案 `No items in this playlist are in the library.`

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
2. Vertical Scrollbar

#### Components

- Section Title
- Button / Neutral
- Playback Cue Reel / Focus Cue Reel
- Subtitle Focus Cue
- Checkbox / Playback Selection Checkbox
- Playback Cue Metadata
- Scrollbar / Vertical

#### Sizes

- Region Width：1fr / 1fr
- Region Padding：`--spacing-8`
- Section Gap：`--spacing-4`
- Action Gap：`--spacing-3`

#### Cue Timeline

- Marker：Checkbox / Playback Selection Checkbox
- Metadata Ordinal：None

#### States

- Loading Preview
- Ready
- Rendering
- Selection Limit Reached
- Exporting
- Group Hovered
  - 指针所在的截图组整体放大：Scale `--scale-collage-group-hover`，Duration `--duration-collage-group-hover`，easeOut
  - 放大部分越过图片边缘与相邻组，不被裁切；其余画面不变

## 3.9 Command Panel

### Command Panel Root Layout

#### Structure / Empty Query

1. Search Field
2. Option List
   1. Recent Videos
   2. Recent Excerpt Lists
3. Footer

#### Structure / Filled Query

1. Search Field
2. Option List
   1. Search Action
   2. Recent Videos
   3. Recent Excerpt Lists
3. Footer

#### Components

- Search Field
- Menu Item / Action Menu Item
- Playback Footer Layout
- Scrollbar / Vertical

#### Surface

- Background：`--color-bg-dialog`
- Scrim：`--color-command-panel-scrim`

#### Layer

- 位于 Playback Overlay 之上
- 打开期间独占指针、滚轮与键盘
- 不关闭下层已展开的菜单

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
- Playback Footer Layout
- Scrollbar / Vertical

#### Variants

- Recent Videos
  - Content：Recent Watching Card Grid
- Recent Excerpt Lists
  - Content：Excerpt List Card Grid
- Search Results
  - Content：Command Panel Search Results Layout

### Command Panel Search Results Layout

#### Structure

1. Playback Cue Reel / Cue Result Reel
2. Vertical Scrollbar

#### Components

- Playback Cue Reel / Cue Result Reel
- Playback Cue Result
- Playback Cue Metadata
- Scrollbar / Vertical

#### Cue Timeline

- Marker：Dot
- Metadata Ordinal：Search Result 1-based Position，形如 `#238`

#### States

- Loading
- Results
- Empty
- Scrolling
- Settling