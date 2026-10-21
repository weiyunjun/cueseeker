# 说明
1. 本文档由人类维护，定义 CueSeeker 的全局设计变量（Core Tokens）：颜色、字体与文本、尺寸、间距、形状与效果、动效。
2. 通用视觉与明暗表面约束见 `/docs/human/design/ui/UI Design Rules.md`，组件与布局索引见 `/docs/human/design/ui/UI Index.md`。

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
- `--color-bg-pressed`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.16)`
- `--color-menu-item-selected-bg`: Light `#E2E8F0`; Dark `rgba(255,255,255,0.16)`
- `--color-badge-neutral-bg`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.20)`
- `--color-bg-disabled`: Light `#F3F4F6`; Dark `rgba(255,255,255,0.04)`
- `--color-bg-control`: Light `#FFFFFF`; Dark `rgba(255,255,255,0.08)`
- `--color-bg-dialog`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-bg-popover`: Light `#FFFFFF`; Dark `#36363B`
- `--color-app-sidebar-bg`: Light `#F6F7F9`; Dark `#111113`
- `--color-app-sidebar-item-selected-bg`: macOS accent color
- `--color-app-sidebar-item-selected-content`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-app-topbar-bg`: Light `#FFFFFF`; Dark `#1C1C1F`
- `--color-file-group-header-bg`: Light `#F8F9FB`; Dark `rgba(255,255,255,0.04)`
- `--color-overlay-surface-shortcut-button-bg-hover`: Light `#EDEEF2`; Dark `rgba(255,255,255,0.06)`
- `--color-overlay-surface-shortcut-button-bg-pressed`: Light `#E1E4E9`; Dark `rgba(255,255,255,0.12)`
- `--color-overlay-surface-keycap-bg`: Light `#E1E4E9`; Dark `rgba(255,255,255,0.10)`
- `--color-overlay-surface-keycap-bg-hover`: Light `#D2D6DE`; Dark `rgba(255,255,255,0.16)`
- `--color-overlay-surface-keycap-bg-pressed`: Light `#C4C9D3`; Dark `rgba(255,255,255,0.22)`
- `--color-popover-surface-shortcut-button-bg-hover`: Light `#F7F8FA`; Dark `rgba(255,255,255,0.06)`
- `--color-popover-surface-shortcut-button-bg-pressed`: Light `#EDEFF2`; Dark `rgba(255,255,255,0.12)`
- `--color-popover-surface-keycap-bg`: Light `#EDEFF2`; Dark `rgba(255,255,255,0.10)`
- `--color-popover-surface-keycap-bg-hover`: Light `#E0E3E8`; Dark `rgba(255,255,255,0.16)`
- `--color-popover-surface-keycap-bg-pressed`: Light `#D2D6DE`; Dark `rgba(255,255,255,0.22)`

### Border

- `--color-border-control`: Light `#E5E7EB`; Dark `#4A4A52`
- `--color-border-control-hover`: Light `#D1D5DB`; Dark `#52525B`
- `--color-border-muted`: Light `#E5E7EB`; Dark `#4A4A52`
- `--color-border-divider`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.10)`
- `--color-border-disabled`: Light `#E5E7EB`; Dark `rgba(255,255,255,0.10)`
- `--color-border-checkbox`: Light `#D0D5DD`; Dark `#5A5A62`

### Accent

- `--color-accent`: macOS accent color
- `--color-text-active`: macOS accent color
- `--color-icon-active`: macOS accent color
- `--color-border-active`: macOS accent color
- `--color-bg-active`:
  - Light: macOS accent color with Alpha `0.12`
  - Dark: macOS accent color with Alpha `0.22`
- `--color-bg-active-hover`:
  - Light: macOS accent color with Alpha `0.18`
  - Dark: macOS accent color with Alpha `0.30`

### Focus

- `--color-border-focus`: macOS accent color
- `--color-focus-ring`: macOS accent color with opacity
  - Light Alpha: `0.22`
  - Dark Alpha: `0.30`
- `--focus-ring-width`: `2px`
- `--focus-ring-offset`: `2px`

### Control

- `--color-primary-button-bg`: macOS accent color
- `--color-primary-button-bg-hover`:
  - Light: macOS accent color blended with `12%` `#000000`
  - Dark: macOS accent color blended with `12%` `#FFFFFF`
- `--color-primary-button-bg-pressed`:
  - Light: macOS accent color blended with `22%` `#000000`
  - Dark: macOS accent color blended with `22%` `#FFFFFF`
- `--color-primary-button-text`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-bg-checkbox-checked`: macOS accent color
- `--color-segmented-control-selected-bg`: macOS accent color
- `--color-segmented-control-selected-content`: Light `#FFFFFF`; Dark `#FFFFFF`
- `--color-filter-chip-selected-content`: macOS accent color
- `--color-filter-chip-selected-bg`: Same as `--color-library-media-card-hover-bg`
- `--color-filter-chip-selected-bg-hover`:
  - Light: macOS accent color with Alpha `0.12`
  - Dark: macOS accent color with Alpha `0.18`
- `--color-filter-chip-selected-bg-pressed`:
  - Light: macOS accent color with Alpha `0.16`
  - Dark: macOS accent color with Alpha `0.24`
- `--color-spinner-track`: Light `#E5E7EB`; Dark `#3F3F46`
- `--color-spinner-indicator`: Light `#717171`; Dark `#878787`
- `--color-danger-text`: Light `#B42318`; Dark `#FCA5A5`
- `--color-danger-bg-hover`: Light `#FEF3F2`; Dark `#3A1717`
- `--color-danger-bg-pressed`: Light `#FEE4E2`; Dark `#4C1D1D`
- `--color-danger-bg-selected`: Light `#FEE2E2`; Dark `#4C1D1D`
- `--color-success-text`: Light `#047857`; Dark `#6EE7B7`
- `--color-warning-text`: Light `#B45309`; Dark `#FCD34D`

### Table

- `--color-table-bg`: Light `#FFFFFF`; Dark `#2E2E34`
- `--color-row-hover`: Light `#F9FAFB`; Dark `#383840`
- `--color-file-folder-card-bg-pressed`: Light `#F3F4F6`; Dark `#3E3E47`
- `--color-row-selected`: Light `#ECEEF2`; Dark `#43434C`
- `--color-row-action-bg-pressed`: Light `#DEE2E8`; Dark `#4E4E58`
- `--color-table-row-hover`: Light `#F9FAFB`; Dark `#26262B`
- `--color-table-row-selected`: Light `#ECEEF2`; Dark `#313137`

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
- `--color-library-cover-placeholder-bg`: Light `#E5E7EB`; Dark `#2E2E33`
- `--color-skeleton-base`: Same as `--color-library-cover-placeholder-bg`
- `--color-skeleton-highlight`: Light `rgba(255,255,255,0.65)`; Dark `rgba(255,255,255,0.08)`
- `--color-library-cover-crop-accent`: macOS accent color
- `--color-library-cover-crop-mask`: macOS shadow color with Alpha `0.55`
- `--color-library-cover-edit-overlay`: Same as `--color-library-cover-crop-mask`
- `--color-library-cover-edit-overlay-content`: Same as `--color-icon-on-dark`
- `--color-library-media-card-hover-bg`: Light `#EEF2F7`; Dark `rgba(255,255,255,0.08)`
- `--color-library-media-card-selected-bg`: Light `#E2E8F0`; Dark `rgba(255,255,255,0.14)`

### Cover Summary

- `--color-cover-summary-scrim`: Light `#000000`; Dark `#000000`
- `--color-cover-summary-text`: Light `#FFFFFF`; Dark `#FFFFFF`

### Dialog

- `--color-dialog-scrim`: Light `rgba(170,170,170,0.60)`; Dark `rgba(0,0,0,0.50)`
- `--color-command-panel-scrim`: Light `rgba(0,0,0,0.32)`; Dark `rgba(0,0,0,0.32)`
- `--color-dialog-outline`: Light `rgba(0,0,0,0.19)`; Dark `rgba(0,0,0,0.94)`
- `--color-dialog-edge-highlight`: Light `transparent`; Dark `rgba(255,255,255,0.20)`
- `--color-toast-bg`: Light `rgba(31,31,31,0.90)`; Dark `rgba(45,45,50,0.92)`
- `--color-toast-border`: Light `rgba(255,255,255,0.15)`; Dark `rgba(255,255,255,0.15)`

### Player Chrome

- `--color-player-stage-bg`: Light `#000000`; Dark `#000000`
- `--color-player-control-bg-hover`: Light `rgba(255,255,255,0.16)`; Dark `rgba(255,255,255,0.16)`
- `--color-player-control-bg-pressed`: Light `rgba(255,255,255,0.24)`; Dark `rgba(255,255,255,0.24)`
- `--color-player-control-bg-active`: macOS accent color with Alpha `0.26`
- `--color-player-menu-bg`: Light `rgba(0,0,0,0.55)`; Dark `rgba(0,0,0,0.55)`
- `--color-player-menu-item-hover-bg`: Light `rgba(255,255,255,0.12)`; Dark `rgba(255,255,255,0.12)`
- `--color-player-menu-item-selected-bg`: Light `rgba(255,255,255,0.16)`; Dark `rgba(255,255,255,0.16)`
- `--color-player-text-primary`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-player-text-secondary`: Light `rgba(255,255,255,0.62)`; Dark `rgba(255,255,255,0.62)`
- `--color-player-text-tertiary`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`
- `--color-player-progress-fill`: macOS accent color
- `--color-player-progress-track`: Light `rgba(255,255,255,0.24)`; Dark `rgba(255,255,255,0.24)`
- `--color-player-progress-hover-track`: Light `rgba(255,255,255,0.38)`; Dark `rgba(255,255,255,0.38)`
- `--color-player-topbar-gradient-start`: Light `rgba(18,18,24,0.66)`; Dark `rgba(18,18,24,0.66)`
- `--color-player-topbar-gradient-end`: Light `rgba(18,18,24,0)`; Dark `rgba(18,18,24,0)`
- `--color-player-error-bg`: Light `#B42318`; Dark `#B42318`
- `--color-player-error-content`: Light `#FFFFFF`; Dark `#FFFFFF`

### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#FAFBFD`; Dark `#18181B`
- `--color-subtitle-focus-cue-selected`: Light `#0F172A`; Dark `#FFFFFF`
- `--color-subtitle-focus-cue-group-selected`: Light `#334155`; Dark `rgba(255,255,255,0.68)`
- `--color-subtitle-focus-cue-unselected`: Light `rgba(15,23,42,0.26)`; Dark `rgba(255,255,255,0.26)`
- `--color-playback-cue-timeline-muted`: Light `#D0D5DD`; Dark `#52525B`
- `--color-playback-cue-metadata-selected`: Light `rgba(15,23,42,0.56)`; Dark `rgba(255,255,255,0.56)`
- `--color-playback-cue-metadata-unselected`: Light `rgba(15,23,42,0.22)`; Dark `rgba(255,255,255,0.20)`

## 1.2 字体与文本

### Typography

- `--font-family-base`: `system-ui, sans-serif`
- `--font-size-body`: `14px`
- `--font-size-control`: `14px`
- `--font-weight-control`: `500`
- `--line-height-detail-file-title`: `20px`
- `--font-size-segmented-control`: `12px`
- `--font-size-table`: `14px`
- `--font-size-table-header`: `14px`
- `--font-size-caption`: `12px`
- `--line-height-table-cue-primary`: `24px`
- `--line-height-table-cue-secondary`: `20px`
- `--font-size-app-sidebar-item`: `13px`
- `--font-size-player-time`: `12px`
- `--font-size-player-progress-time`: `10px`
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
- `--font-size-playback-cue-metadata`: `14px`
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
- `--font-size-cover-summary-title`: `22px`
- `--font-weight-cover-summary-title`: `700`

### Text Decoration

- `--width-interactive-text-underline`: `1px`
- `--offset-interactive-text-underline`: `2px`

## 1.3 尺寸

### Height

- `--height-filter-bar-control`: `40px`
- `--height-control`: `36px`
- `--height-segmented-control`: `32px`
- `--height-filter-chip`: `32px`
- `--height-filter-chip-count-placeholder`: `12px`
- `--height-field`: `30px`
- `--height-table-header`: `44px`
- `--min-height-table-row`: `40px`
- `--height-action-menu-item`: `32px`
- `--height-select-menu-item`: `32px`
- `--max-height-menu`: `480px`
- `--height-app-sidebar-item`: `32px`
- `--height-app-topbar`: `54px`
- `--height-workbench-topbar`: `54px`
- `--height-player-bottom-control-bar`: `90px`
- `--height-player-bottom-controls-row`: `44px`
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
- `--height-cover-summary-progress-track`: `5px`
- `--height-keycap`: `22px`
- `--min-height-playback-footer`: `48px`
- `--height-settings-window`: `640px`
- `--min-height-settings-window`: `420px`
- `--height-settings-titlebar`: `36px`
- `--min-height-settings-row`: `52px`
- `--max-height-settings-font-menu`: `280px`
- `--height-anki-export-card-box`: `288px`

### Size

- `--size-checkbox`: `21px`
- `--size-spinner`: `16px`
- `--width-spinner-stroke`: `2px`
- `--width-filter-chip-count-placeholder`: `24px`
- `--max-width-filter-chip`: `332px`
- `--size-playback-collage-checkbox`: `31px`
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
- `--size-card-icon-container`: `36px`
- `--size-card-icon-glyph`: `20px`
- `--size-card-chevron`: `16px`
- `--size-detail-file-icon-container`: `40px`
- `--size-detail-file-icon-glyph`: `20px`
- `--min-width-detail-label`: `100px`
- `--min-width-detail-index-label`: `40px`
- `--width-player-volume-slider`: `68px`
- `--size-player-volume-thumb`: `10px`
- `--width-player-volume-value`: `32px`
- `--max-width-player-audio-track-menu`: `300px`
- `--size-player-progress-thumb`: `12px`
- `--width-player-topbar-title-max`: `520px`
- `--size-player-error-icon`: `16px`
- `--size-playback-feedback-icon`: `31px`
- `--width-playback-feedback-max`: `520px`
- `--size-toast-icon`: `23px`
- `--width-toast-max`: `400px`
- `--width-tooltip-max`: `280px`
- `--width-playback-cue-timeline-connector`: `1px`
- `--width-subtitle-focus-content-max`: `960px`
- `--aspect-library-cover`: `16 / 9`
- `--min-width-cover-summary-content`: `448px`
- `--max-width-cover-summary-content`: `720px`
- `--preferred-width-cover-summary-content`: `50%`
- `--width-cover-summary-split-cover`: `320px`
- `--min-width-cover-summary-split-content`: `320px`
- `--width-cover-summary-form-switch`: `664px`
- `--width-cover-summary-progress`: `290px`
- `--width-library-recent-card-min`: `220px`
- `--grid-max-columns-library-with-sidebar`: `5`
- `--grid-max-columns-library-without-sidebar`: `6`
- `--width-library-episode-row-min`: `380px`
- `--width-library-list-cover`: `204px`
- `--width-library-folder-cover`: `120px`
- `--min-height-library-folder-card`: `96px`
- `--width-window-default`: `1000px`
- `--min-width-window`: `600px`
- `--min-height-window`: `560px`
- `--min-width-workbench-page-content`: `600px`
- `--width-dialog-small`: `360px`
- `--width-dialog-medium`: `480px`
- `--width-dialog-large`: `600px`
- `--width-dialog-x-large`: `720px`
- `--width-form-label`: `72px`
- `--width-shortcut-field`: `144px`
- `--width-settings-number-field`: `114px`
- `--width-settings-window`: `880px`
- `--width-settings-sidebar`: `184px`
- `--width-settings-popup`: `180px`
- `--width-settings-font-menu`: `240px`
- `--size-settings-color-swatch`: `16px`
- `--size-settings-color-preset-swatch`: `20px`
- `--border-width-control`: `1px`
- `--size-anki-export-add-button`: `24px`
- `--size-anki-export-add-icon`: `16px`
- `--size-anki-export-drag-handle`: `12px`
- `--size-anki-export-badge-remove-button`: `14px`
- `--size-anki-export-badge-remove-icon`: `12px`
## 1.4 间距

### Spacing

- `--spacing-1`: `4px`
- `--spacing-2`: `8px`
- `--spacing-3`: `12px`
- `--spacing-4`: `16px`
- `--spacing-5`: `20px`
- `--spacing-6`: `24px`
- `--spacing-8`: `32px`
- `--gap-segmented-control`: `2px`
- `--gap-menu-scrollbar-outer`: `6px`
- `--inset-menu-divider`: `--padding-menu` 与 `--padding-menu-item` 之和
- `--gap-menu-divider`: `4px`
- `--gap-subtitle-focus-cue`: `8px`
- `--gap-subtitle-focus-internal-line`: `3px`
- `--gap-app-topbar-toggle-after-window-controls`: `20px`
- `--gap-app-topbar-content`: `12px`
- `--gap-player-window-controls-return`: `16px`
- `--gap-player-speed-menu-from-button`: `8px`
- `--gap-library-recent-grid`: `8px`
- `--gap-library-episode-grid`: `8px`
- `--gap-library-list-item`: `20px`
- `--gap-library-list-info-vertical`: `8px`
- `--gap-library-folder-card-content`: `12px`
- `--gap-cover-summary-to-toolbar`: `24px`
- `--gap-cover-summary-split`: `24px`
- `--gap-cover-summary-title-meta`: `8px`
- `--gap-cover-summary-meta-lines`: `6px`
- `--gap-cover-summary-progress-label`: `6px`
- `--gap-cover-summary-progress-actions`: `14px`
- `--gap-cover-dialog-region`: `20px`

### Padding

- `--inset-dialog`: `24px`
- `--padding-control-x`: `14px`
- `--padding-segmented-control`: `3px`
- `--padding-field-x`: `10px`
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
- `--padding-player-speed-button-x`: `10px`
- `--padding-player-volume-trailing`: `10px`
- `--padding-player-progress-time-capsule-x`: `8px`
- `--padding-player-topbar-x`: `16px`
- `--padding-player-error-x`: `12px`
- `--padding-player-error-y`: `10px`
- `--padding-library-folder-card`: `12px 16px`
- `--padding-library-time-badge`: `2px 6px`
- `--padding-task-count-badge-compact-x`: `6px`
- `--padding-library-media-card-hover`: `12px`
- `--padding-workbench-media-card-grid-inline`: Leading `--spacing-5` (`20px`)，Trailing `--spacing-5` + `--width-page-scrollbar-channel` (`36px`)
- `--padding-app-topbar-trailing`: `--spacing-6` + `--width-page-scrollbar-channel` (`40px`)
- `--padding-library-list-card`: `12px 16px`
- `--padding-cover-summary-backdrop-inline`: `40px`
- `--padding-cover-summary-backdrop-block`: `22.5px`

## 1.5 形状与效果

### Radius

- `--radius-control`: `8px`
- `--radius-field`: `6px`
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
- `--radius-settings-color-swatch`: `4px`
- `--radius-playback-feedback`: `16px`
- `--radius-player-error`: `10px`
- `--radius-library-cover`: `8px`
- `--radius-library-time-badge`: `4px`
- `--radius-library-folder-card`: `8px`
- `--radius-library-media-card-hover`: `20px`
- `--radius-library-list-card`: `16px`
- `--radius-cover-summary`: `16px`
- `--radius-anki-export-badge-remove-button`: `3px`

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
- `--opacity-cover-summary-button-bg-pressed`: `34%`
- `--opacity-cover-summary-button-border`: `35%`
- `--opacity-cover-summary-button-disabled`: `55%`
- `--opacity-anki-export-dragging`: `0.5`

## 1.6 动效

### Interaction Motion

- `--scale-library-cover-hover`: `1.02`
- `--duration-library-cover-hover`: `0.12s`
- `--scale-collage-group-hover`: `1.02`
- `--duration-collage-group-hover`: `0.12s`
- `--duration-sidebar-motion`: `0.18s`
- `--duration-player-volume-expand`: `0.18s`
- `--delay-tooltip-hover`: `1s`
- `--delay-tooltip-skip-window`: `0.3s`

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

### Shimmer Motion

- `--duration-shimmer-motion`: `1.5s`
- `--easing-shimmer-motion`: `linear`
- `--delay-cover-anti-flicker`: `120ms`
- `--duration-cover-crossfade`: `0.20s`

### Subtitle Focus Motion

- `--duration-subtitle-focus-scroll`: `0.22s`
- `--easing-subtitle-focus-scroll`: `cubic-bezier(0.22, 1, 0.36, 1)`

### Player UI Visibility

- `--duration-player-ui-idle-hide`: `3s`
