# 版本
main

# 需求描述
调整部分UI。详见# UI文档改动。

# UI文档改动
### 1.2 尺寸、圆角、间距

#### Height
--height-filter-bar-control: 32px
--height-control: 32px
--height-field: 40px
--height-table-utility-bar: 32px
--height-table-header: 40px
--height-table-row: 64px
--height-action-menu-item: 40px
--height-select-menu-item: 40px
--height-app-sidebar-item: 32px
--height-app-topbar: 45px
--height-player-topbar: 46px
--height-player-bottom-control-bar: 98px
--height-player-bottom-controls-row: 52px
--height-player-capsule-button: 40px
--height-player-speed-menu: 234px
--height-player-speed-menu-item: 30px
--height-player-progress-hit-area: 18px
--height-player-progress-track: 3px
--height-player-progress-track-hover: 6px
--height-player-progress-time-capsule: 22px

#### Size
--size-checkbox: 16px
--size-inline-clear-button: 24px
--size-inline-clear-icon: 16px
--size-inline-clear-symbol-font-size-macos: 11pt
--size-inline-add-symbol-font-size-macos: 16pt
--size-menu-item-symbol-font-size-macos: 14pt
--size-select-indicator: 11pt
--size-button-icon: 13px
--size-control-icon: 16px
--size-icon-button: 32px
--size-row-action-button: 36px
--scrollbar-size: 8px
--width-app-sidebar: 240px
--size-app-sidebar-item-icon: 18px
--size-player-circle-button: 40px
--size-player-circle-button-icon: 18px
--width-player-speed-button: 54px
--width-player-speed-menu: 172px
--size-player-progress-thumb: 12px
--size-player-window-control-button: 13px
--size-player-window-control-glyph: 7px
--width-player-topbar-title-max: 520px

#### Padding
--padding-control-x: 12px
--padding-field-x: 16px
--padding-menu-item: 12px 16px
--padding-header-trigger-x: 12px
--padding-chip-x: 10px
--padding-chip-y: 4px
--padding-app-sidebar-x: 12px
--padding-app-sidebar-y: 12px
--padding-app-sidebar-item-x: 10px
--padding-app-topbar-title-x: 24px

--padding-player-chrome-x: 24px
--padding-player-chrome-bottom: 12px
--padding-player-progress-top: 16px
--padding-player-capsule-button-x: 16px
--padding-player-speed-menu: 6px
--padding-player-speed-menu-item-x: 8px
--padding-player-progress-time-capsule-x: 8px
--padding-player-topbar-x: 16px

#### Typography
--font-family-base: system-ui, sans-serif
--font-size-body: 14px
--font-size-control: 13px
--font-weight-control: 500
--weight-select-indicator: semibold
--weight-button-icon: medium
--font-size-table: 14px
--font-size-table-header: 14px
--font-size-caption: 12px
--font-size-app-sidebar-item: 13px

--font-size-player-time: 12px
--font-size-player-progress-time: 10px
--font-size-player-speed-menu-check: 11px
--font-size-player-speed-menu-item: 13px
--font-size-player-topbar-title: 13px

### 2.4 Select Trigger Button
#### Content
Leading Icon: filter / sliders
Icon Size: --size-control-icon
Text Size: --font-size-control
Text Weight: --font-weight-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled
Select Indicator: chevrons-up-down
Select Indicator Size: --size-select-indicator
Select Indicator Weight: --weight-select-indicator
Select Indicator Gap: --spacing-2
Select Indicator Color Default: --color-icon-default
Select Indicator Color Hover / Open: --color-icon-default
Select Indicator Color Disabled: --color-icon-disabled

### 2.8 Neutral Button
#### Content
Leading Icon: optional
Gap: --spacing-2
Font Family: --font-family-base
Text Size: --font-size-control
Text Weight: --font-weight-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-button-icon
Icon Weight: --weight-button-icon
Icon Color Default: --color-text-primary
Icon Color Disabled: --color-icon-disabled

### 2.9 Inline Add Button
#### Content
Icon: plus
Gap: --spacing-2
Font Family: --font-family-base
Text Size: --font-size-control
Text Weight: --font-weight-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Slot Size: --size-control-icon
Native macOS Symbol: SF Symbol plus, medium
Native macOS Symbol Font Size: --size-inline-add-symbol-font-size-macos
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-text-disabled

### 2.16 Row Action Menu
#### Content
Copy Cue Text Icon: copy
Open Context Icon: search
Favorite Icon: star
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Disabled: --color-text-disabled
Menu Item Icon Color Default: --color-text-primary
Menu Item Icon Color Disabled: --color-icon-disabled
Row Action Trigger Icon: ellipsis
Row Action Trigger Icon Color: --color-icon-default
Row Action Trigger Disabled Icon Color: --color-icon-disabled