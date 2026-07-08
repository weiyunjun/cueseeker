
# UI文档
## 1. Core Tokens

### 1.1 颜色

#### Text
--color-text-primary:
  Light: #0F172A
  Dark: #F4F4F5
--color-text-secondary:
  Light: #404040
  Dark: #D4D4D4
--color-text-muted:
  Light: #667085
  Dark: #A1A1AA
--color-text-placeholder:
  Light: #98A2B3
  Dark: #71717A
--color-text-disabled:
  Light: #98A2B3
  Dark: #71717A
--color-text-readonly:
  Light: #808080
  Dark: #A1A1AA

#### Icon
--color-icon-default:
  Light: #667085
  Dark: #A1A1AA
--color-icon-muted:
  Light: #98A2B3
  Dark: #71717A
--color-icon-disabled:
  Light: #98A2B3
  Dark: #71717A
--color-icon-on-dark:
  Light: #FFFFFF
  Dark: #FFFFFF

#### Background
--color-bg-surface:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-hover:
  Light: #F3F4F6
  Dark: #27272A
--color-bg-disabled:
  Light: #F3F4F6
  Dark: #202024
--color-bg-readonly:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-popover:
  Light: #FFFFFF
  Dark: #1C1C1F
--color-app-sidebar-bg:
  Light: #F6F7F9
  Dark: #202024
--color-app-sidebar-item-selected-bg:
  Light: #FFFFFF
  Dark: #303036
--color-app-topbar-bg:
  Light: #FFFFFF
  Dark: #18181B

#### Border
--color-border-control:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-control-hover:
  Light: #D1D5DB
  Dark: #52525B
--color-border-muted:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-divider:
  Light: #E5E7EB
  Dark: #303036
--color-border-disabled:
  Light: #E5E7EB
  Dark: #303036
--color-border-readonly:
  Light: #E5E7EB
  Dark: #3F3F46
--color-border-checkbox:
  Light: #D0D5DD
  Dark: #52525B

#### Active Blue
--color-accent:
  Light: #0040FF
  Dark: #7AA2FF
--color-text-active:
  Light: #0040FF
  Dark: #8AB4FF
--color-icon-active:
  Light: #0040FF
  Dark: #8AB4FF
--color-border-active:
  Light: #0040FF
  Dark: #7AA2FF
--color-bg-active:
  Light: #EBF5FF
  Dark: #14275A
--color-bg-active-hover:
  Light: #E1EBFF
  Dark: #1B3470
--color-bg-active-clear-hover:
  Light: #D8E8FD
  Dark: #243F7F

#### Primary Button
--color-primary-button-bg:
  System: macOS accent color
  Implementation: SwiftUI Color.accentColor / AppKit NSColor.controlAccentColor
--color-primary-button-bg-hover:
  System: macOS accent color with native hover emphasis
--color-primary-button-text:
  Light: #FFFFFF
  Dark: #FFFFFF

#### Focus
--color-border-focus:
  System: macOS accent color
  Implementation: SwiftUI Color.accentColor / AppKit NSColor.controlAccentColor
--color-focus-ring:
  System: macOS accent color with opacity
  Light Alpha: 0.22
  Dark Alpha: 0.30

#### Table Row
--color-row-hover:
  Light: #F9FAFB
  Dark: #202024
--color-row-selected:
  Light: #F3F4F6
  Dark: #27272A

#### Checkbox
--color-bg-checkbox-unchecked:
  Light: #FFFFFF
  Dark: #18181B
--color-bg-checkbox-checked:
  Light: #111827
  Dark: #F4F4F5
--color-checkbox-icon:
  Light: #FFFFFF
  Dark: #18181B

#### Danger
--color-danger-text:
  Light: #B42318
  Dark: #FCA5A5
--color-danger-bg-hover:
  Light: #FEF3F2
  Dark: #3A1717

#### Scrollbar
--color-scrollbar-thumb-default:
  Light: #CBD5E1
  Dark: #52525B
--color-scrollbar-thumb-interactive:
  Light: #94A3B8
  Dark: #71717A
--color-scrollbar-track:
  Light: transparent
  Dark: transparent

#### Chip
--color-chip-speaker-bg:
  Light: #DDD6FE
  Dark: #31294C
--color-chip-speaker-text:
  Light: #5B21B6
  Dark: #D8B4FE
--color-chip-language-bg:
  Light: #DBEAFE
  Dark: #172A4A
--color-chip-language-text:
  Light: #0040FF
  Dark: #93C5FD

#### Watch Status
--color-watch-status-unwatched-bg:
  Light: #F3F4F6
  Dark: #27272A
--color-watch-status-unwatched-text:
  Light: #667085
  Dark: #A1A1AA
--color-watch-status-watching-bg:
  Light: #DBEAFE
  Dark: #172A4A
--color-watch-status-watching-text:
  Light: #0040FF
  Dark: #93C5FD
--color-watch-status-finished-bg:
  Light: #D1FAE5
  Dark: #123A2A
--color-watch-status-finished-text:
  Light: #047857
  Dark: #6EE7B7

#### Library Media
--color-library-progress-fill:
  System: macOS accent color
  Implementation: SwiftUI Color.accentColor / AppKit NSColor.controlAccentColor
--color-library-progress-track:
  Light: #E5E7EB
  Dark: #303036
--color-library-time-badge-bg:
  Light: rgba(15,23,42,0.72)
  Dark: rgba(0,0,0,0.58)
--color-library-time-badge-text:
  Light: #FFFFFF
  Dark: #FFFFFF
--color-library-cover-placeholder-bg:
  Light: #E5E7EB
  Dark: #303036
--color-library-media-card-hover-bg:
  System: macOS accent color with opacity
  Light Alpha: 0.08
  Dark Alpha: 0.12

#### Player Chrome
--color-player-stage-bg:
  Light: #000000
  Dark: #000000
--color-player-control-bg:
  Light: rgba(0,0,0,0.30)
  Dark: rgba(0,0,0,0.30)
--color-player-control-bg-hover:
  Light: rgba(255,255,255,0.16)
  Dark: rgba(255,255,255,0.16)
--color-player-menu-bg:
  Light: rgba(0,0,0,0.55)
  Dark: rgba(0,0,0,0.55)
--color-player-menu-item-hover-bg:
  Light: rgba(255,255,255,0.12)
  Dark: rgba(255,255,255,0.12)
--color-player-text-primary:
  Light: rgba(255,255,255,0.94)
  Dark: rgba(255,255,255,0.94)
--color-player-text-secondary:
  Light: rgba(255,255,255,0.62)
  Dark: rgba(255,255,255,0.62)
--color-player-text-tertiary:
  Light: rgba(255,255,255,0.34)
  Dark: rgba(255,255,255,0.34)
--color-player-icon-selected:
  Light: #1A1A1F
  Dark: #1A1A1F
--color-player-progress-fill:
  System: macOS accent color
  Implementation: SwiftUI Color.accentColor / AppKit NSColor.controlAccentColor
--color-player-progress-track:
  Light: rgba(0,0,0,0.60)
  Dark: rgba(0,0,0,0.60)
--color-player-progress-hover-track:
  Light: rgba(255,255,255,0.35)
  Dark: rgba(255,255,255,0.35)
--color-player-window-close:
  Light: #FF5F57
  Dark: #FF5F57
--color-player-window-minimize:
  Light: #FEBC2E
  Dark: #FEBC2E
--color-player-window-zoom:
  Light: #28C840
  Dark: #28C840
--color-player-window-control-border:
  Light: rgba(0,0,0,0.18)
  Dark: rgba(0,0,0,0.18)
--color-player-window-control-glyph:
  Light: rgba(0,0,0,0.55)
  Dark: rgba(0,0,0,0.55)
--color-player-topbar-gradient-start:
  Light: rgba(18,18,24,0.66)
  Dark: rgba(18,18,24,0.66)
--color-player-topbar-gradient-end:
  Light: rgba(18,18,24,0)
  Dark: rgba(18,18,24,0)

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
--size-select-indicator: 12pt
--size-button-icon: 14px
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

#### Text Decoration
--width-interactive-text-underline: 1px
--offset-interactive-text-underline: 2px

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
--radius-table-cell-hover: 8px
--radius-chip: 6px
--scrollbar-radius: 9999px
--radius-app-sidebar-item: 8px

--radius-player-capsule: 9999px
--radius-player-speed-menu: 14px
--radius-player-speed-menu-item: 8px

#### Spacing
--spacing-1: 4px
--spacing-2: 8px
--spacing-3: 12px
--spacing-4: 16px
--spacing-6: 24px
--spacing-8: 32px
--gap-app-topbar-title-after-toggle: 12px

--gap-player-bottom-left-controls: 8px
--gap-player-bottom-right-controls: 6px
--gap-player-time-label: 4px
--gap-player-window-controls: 8px
--gap-player-speed-menu-from-button: 8px

#### Padding
--padding-control-x: 14px
--padding-field-x: 16px
--padding-menu-item: 12px 16px
--padding-header-trigger-x: 12px
--padding-chip-x: 10px
--padding-chip-y: 4px
--padding-table-cell-hover-x: 12px
--padding-table-cell-hover-y: 6px
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
--font-size-control: 14px
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

#### Shadow
--shadow-popover:
  Light: 0 12px 24px rgba(15,23,42,0.12)
  Dark: 0 12px 24px rgba(0,0,0,0.36)

--shadow-player-overlay:
  Light: 0 12px 24px rgba(0,0,0,0.42)
  Dark: 0 12px 24px rgba(0,0,0,0.42)
--shadow-player-topbar-title:
  Light: 0 1px 2px rgba(0,0,0,0.50)
  Dark: 0 1px 2px rgba(0,0,0,0.50)

#### Library Size
--aspect-library-cover: 16 / 9
--height-library-progress-bar: 4px
--width-library-recent-card-min: 180px
--width-library-recent-card-max: 220px
--width-library-episode-row-min: 380px
--width-library-list-cover: 204px
--height-library-list-cover: 115px
--width-library-folder-cover: 120px
--min-height-library-folder-card: 96px

#### Library Radius
--radius-library-cover: 8px
--radius-library-time-badge: 4px
--radius-library-folder-card: 8px
--radius-library-media-card-hover: 20px
--radius-library-list-card: 16px

#### Library Spacing
--gap-library-recent-grid: 16px
--gap-library-episode-grid: 16px
--gap-library-list-item: 20px
--gap-library-list-info-vertical: 8px
--gap-library-folder-card-content: 12px

#### Library Interaction
--scale-library-media-card-pressed: 0.98
--scale-library-cover-hover: 1.02
--duration-library-cover-hover: 0.12s

#### Library Padding
--padding-library-folder-card: 12px 16px
--padding-library-time-badge: 2px 6px
--padding-library-media-card-hover: 12px
--padding-library-list-card: 12px 16px

#### Library Typography
--font-size-section-title: 18px
--font-size-library-title: 14px
--font-size-library-meta: 12px
--font-size-library-time-badge: 10px
--font-size-library-list-title: 15px
--font-size-library-list-subtitle: 13px
--font-size-library-list-meta: 12px

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
Hover / Open Bg: --color-bg-active-hover
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
Active Hover / Open
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
Text Weight: --font-weight-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Color Default: --color-text-primary
Icon Color Disabled: --color-icon-disabled
Select Indicator: chevrons-up-down
Select Indicator Size: --size-select-indicator
Select Indicator Weight: --weight-select-indicator
Select Indicator Gap: --spacing-2
Select Indicator Color Default: --color-text-primary
Select Indicator Color Hover / Open: --color-text-primary
Select Indicator Color Disabled: --color-icon-disabled

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
Gap: --spacing-2
Font Family: --font-family-base
Text Size: --font-size-control
Text Weight: --font-weight-control
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Slot Size: --size-control-icon
Native macOS Symbol: SF Symbol plus, medium
Native macOS Symbol Font Size: --size-inline-add-symbol-font-size-macos
Icon Color Default: --color-text-primary
Icon Color Disabled: --color-text-disabled

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
Icon Slot Size: --size-control-icon
Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

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
Check Icon Slot Size: --size-control-icon
Check Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

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
Icon Slot Size: --size-control-icon
Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Icon Color: --color-text-primary
Disabled Icon: --color-text-disabled

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
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Hover / Highlighted: --color-text-primary
Menu Item Icon Color: --color-text-primary
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
Menu Anchor: right-click pointer position inside triggering table cell content hover region
Menu Position: below right-click position, clamped to visible content bounds
Menu Open Cell Background: --color-bg-hover on triggering content hover region only

#### Content
Play Icon: play.fill
Copy Cue Text Icon: copy
Copy Text Icon: copy
Open Context Icon: doc.text
Open Folder Icon: folder
Favorite Icon: star
Menu Item Icon Slot Size: --size-control-icon
Menu Item Native macOS Symbol Font Size: --size-menu-item-symbol-font-size-macos
Menu Item Text Color Default: --color-text-primary
Menu Item Text Color Disabled: --color-text-disabled
Menu Item Icon Color Default: --color-text-primary
Menu Item Icon Color Disabled: --color-icon-disabled

#### Status
Default Menu
Hover / Highlighted Item
Menu Open (from Cues Cell)

#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Row action menu overlay.

Allowed invalidation:
- Menu open / close may update only the active row, active cell trigger, menu overlay, and menu dismiss monitor.
- Menu item hover may update only the hovered menu item.
- Menu item click may execute only the explicit command selected by the user.

Forbidden invalidation:
- Right click and menu hover must not change row selection.
- Right click and menu hover must not reload table rows, rebuild table snapshots, or start background row hydration.
- Row action menu state must not invalidate SearchView, ShioriView, Library, Playback Page, or Playback render host.

### 2.17 Table Row

#### Container
Row Height: --height-table-row
Header Height: --height-table-header
Row Hover Bg: none
Row Selected Bg: none
Header Hover Bg: none
Trigger Surface Bg: --color-bg-hover
Cell Content Hover Bg: --color-bg-hover
Cell Content Hover Radius: --radius-table-cell-hover
Cell Content Hover Padding X: --padding-table-cell-hover-x
Cell Content Hover Padding Y: --padding-table-cell-hover-y
Cell Content Hover Scope: one rounded rectangle around the union bounds of visible text / content
Interactive Cell Region: same bounds as Cell Content Hover Scope
Cell Content Hit Testing: hover, pointer, left-click action, and right-click menu only apply inside Interactive Cell Region
Non-interactive Cell Area: no cell hover, no pointer, no cell action; left click can toggle row checkbox selection
Divider Horizontal: --color-border-control
Divider Width: 1px

#### Content
Header Text Color: --color-text-primary
Header Font Size: --font-size-table-header
Header Font Weight: 500
Primary Text Color: --color-text-secondary
Primary Text Font Weight: 500
Primary Text Hover Color: --color-text-primary
Secondary Text Color: --color-text-secondary
Secondary Text Font Weight: 500
Metadata Text Color: --color-text-secondary
Metadata Text Font Weight: 500
Metadata Numeric Variant: tabular-nums
Interactive Text Color: --color-text-primary
Interactive Text Font Weight: 500
Columns: defined by each table layout
Tags: Chip / Tag

#### Status
Default
Header Hover / Header Area: no background
Header Hover / Trigger Surface
Body Hover: no full-row background
Body Selected: no full-row background
Cell Content Hover

#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table document row layer.

Allowed invalidation:
- Row hover may redraw only the previous row and the current row.
- Cell hover may redraw only the current row.
- Cell action menu open / close may redraw only the triggering row and the previously active row.
- Selection change may redraw the changed row and update the selection header state.
- Keyboard focus movement may redraw only the previous focused row and the current focused row.

Forbidden invalidation:
- Row hover must not invalidate the full table document.
- Row hover must not trigger row data reload, table snapshot rebuild, SearchView refresh, or Playback refresh.
- Row-local visual state must not be stored in SearchStore, ShioriStore, LibraryStore, or PlaybackStore.

### 2.18 Sortable Header Cell

#### Container
Header Height: --height-table-header
Trigger Padding X: --padding-header-trigger-x
Trigger Bg Hover / Menu Open: --color-bg-hover
Row Bg Hover: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Text Size: --font-size-table-header
Text Weight: 500
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Default: --color-icon-default
Icon Disabled: --color-icon-disabled
Indicator Unsorted: chevrons-up-down
Indicator Asc: arrow-up
Indicator Desc: arrow-down

#### Status
Interaction: Default
Interaction: Hover
Interaction: Menu Open
Interaction: Disabled / Not Sortable
Sort: Unsorted
Sort: Sorted Asc
Sort: Sorted Desc

#### Cursor
Not specified in image

#### Refresh Scope
Owner:
- Table header layer.

Allowed invalidation:
- Header hover may update only the hovered header trigger.
- Header menu open / close may update only the header host, active menu, and menu overlay.
- Sort changes may update table row ordering only for the owning table.

Forbidden invalidation:
- Header hover must not redraw table rows.
- Header menu state must not invalidate Playback, Library, or unrelated workbench surfaces.
- Sorting must not rewrite source data outside the owning table snapshot.

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

#### Refresh Scope
Owner:
- Table selection layer.

Allowed invalidation:
- Row checkbox toggle may redraw only the changed row checkbox state, changed row selection state, header checkbox state, Count Summary, and batch action visibility.
- Header checkbox toggle may redraw only rows whose selection state changed and the selection summary region.

Forbidden invalidation:
- Checkbox toggle must not rebuild row data, reload table snapshots, run continuous row loading, or refresh Search/Shiori/Library data.
- Checkbox hover, focus, and pressed state must not invalidate Playback, App Sidebar, App Topbar, or unrelated workbench surfaces.

### 2.20 Interactive Text Cell

#### Container
Background Default: transparent
Background Hover: --color-bg-hover
Radius Hover: --radius-table-cell-hover
Padding X Hover: --padding-table-cell-hover-x
Padding Y Hover: --padding-table-cell-hover-y
Scope: one rounded rectangle around the union bounds of visible text / content; does not fill the full cell or full row
Multi-line Text: one unified rounded rectangle, not separate per-line backgrounds

#### Content
Text Default: --color-text-primary
Text Hover: --color-text-primary
Underline Hover: same as text color
Text Decoration: underline
Decoration Thickness: --width-interactive-text-underline
Decoration Offset: --offset-interactive-text-underline

#### Status
Default
Hover (Underline)

#### Cursor
Default / Non-interactive Area: default
Interactive Text Hover: pointer

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

#### Refresh Scope
Owner:
- Table scrollbar overlay.

Allowed invalidation:
- Scrollbar hover and dragging may redraw only the scrollbar dirty region.
- Scroll position changes may update visible row range, scrollbar metrics, cursor rects, and horizontal header offset when needed.

Forbidden invalidation:
- Scrollbar hover must not redraw table rows.
- Scrollbar dragging must not rebuild row data.
- Scrolling must not invalidate Playback render host or unrelated workbench surfaces.

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
Shiori Tag Background: --color-bg-hover
Shiori Tag Text: --color-text-secondary
Shiori Tag Table Style: same Shiori Tag Background, Text, Radius, Padding, and Font as Shiori Tag Popover Style
Shiori Tag Popover Style: same Shiori Tag Background, Text, Radius, Padding, and Font as Shiori Tag Table Style
Shiori Tag Visual Difference: popover removable tags may show x button; table tags must not show x button
Disabled Background: --color-bg-disabled
Disabled Text: --color-text-disabled
Remove Button Icon: x
Remove Button Icon Color Default: --color-icon-muted
Remove Button Icon Color Hover: --color-danger-text
Remove Button Background Hover: --color-danger-bg-hover
Non-removable Layout: [label]
Removable Layout: [label | x]

#### Status
Speaker / Default
Language / Default
Speaker / Disabled
Language / Disabled
Shiori Tag / Default
Shiori Tag / Hover
Shiori Tag / Removable
Shiori Tag Remove Button / Hover
Shiori Tag / Disabled

#### Cursor
Default: default
Interactive Tag Body: pointer
Remove Button: pointer
Disabled: default

#### Interaction
Non-removable Tag: display label only; no x button
Removable Tag: display label and x remove button
Tag Body Click: delegated to the owning layout
Remove Button Click: delegated to the owning layout
Remove Button Hit Area: only the x button; must not trigger tag body click

#### Refresh Scope
Owner:
- Direct chip owner: table cell, tag popover section, or dialog command target.

Allowed invalidation:
- Chip hover may update only the hovered chip.
- Remove button hover may update only the hovered remove button.
- Tag body click may execute only the action declared by the owning layout.
- Remove button click may execute only the remove or delete action declared by the owning layout.

Forbidden invalidation:
- Chip hover must not reload table rows or rebuild table snapshots.
- Remove button hover must not update row selection, Search, Shiori, Library, or Playback state.
- Remove button click must not also trigger tag body click.

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

### 2.24 Section Title

#### Container
Display: block
Align: left
Background: transparent
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-section-title
Font Weight: semibold
Text Color: --color-text-primary

#### Status
Readonly

#### Cursor
default

### 2.25 Library Cover

#### Container
Aspect Ratio: --aspect-library-cover
Radius: --radius-library-cover
Background Fallback: --color-library-cover-placeholder-bg
Overflow: hidden

#### Content
Cover Image: fill container, preserve aspect ratio by cropping
Image Source: index-stage generated cover cache
Image Rendering: downsample to actual displayed pixel size before rendering

#### Status
No Cover
Loaded

#### Cursor
Inherited from parent component

### 2.26 Library Cover Progress Overlay

#### Container
Position: bottom aligned
Width: 100%
Height: --height-library-progress-bar

#### Content
Progress Track: --color-library-progress-track
Progress Fill: --color-library-progress-fill
Progress Fill Width: follows playback progress

#### Status
No Progress: hidden
In Progress: visible, show progress fill
Finished: visible, fill width 100%
Unknown Duration: hidden

#### Cursor
Inherited from parent component

### 2.27 Library Cover Badge

#### Container
Position: bottom right
Radius: --radius-library-time-badge
Background: --color-library-time-badge-bg
Padding: --padding-library-time-badge

#### Content
Font Size: --font-size-library-time-badge
Text Color: --color-library-time-badge-text

#### Status
Time
Count
Hidden

#### Cursor
Inherited from parent component

### 2.28 Watch Status Badge

#### Container
Height: fit-content
Radius: --radius-chip
Padding X: --padding-chip-x
Padding Y: --padding-chip-y
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-caption
Unwatched Background: --color-watch-status-unwatched-bg
Unwatched Text Color: --color-watch-status-unwatched-text
Watching Background: --color-watch-status-watching-bg
Watching Text Color: --color-watch-status-watching-text
Finished Background: --color-watch-status-finished-bg
Finished Text Color: --color-watch-status-finished-text

#### Status
Unwatched
Watching
Finished
Disabled

#### Cursor
default

### 2.29 Library Card Context Menu

#### Container
Style: Row Action Menu
Trigger: right click on the card-defined interactive hover region
Menu Background: --color-bg-popover
Menu Border: --color-border-muted
Menu Border Radius: --radius-menu
Menu Shadow: --shadow-popover
Menu Padding: --spacing-1
Menu Width: fixed or intrinsic menu width; must not expand to parent container width
Menu Item Hover Background: --color-bg-hover
Dismiss: click outside menu closes the menu
System Popover Arrow: none

#### Anchor
Recent Watching Card: right-click position inside card hover region
Library Folder Card: right-click position inside card hover region
Library Episode Card: right-click position inside Cover Region only
Menu Position: align to right-click position and clamp to visible content bounds

#### Menu Content
Open Folder Icon: folder
Mark as Finished Icon: checkmark.circle
Mark as Unwatched Icon: circle
Mark as Watching Icon: play.circle
Context Icon: doc.text
Menu Item Text Color Default: --color-text-primary
Menu Item Icon Color Default: --color-text-primary

#### Status
Default
Hover
Menu Open
Disabled

#### Cursor
Menu Items: pointer

#### Refresh Scope
Owner:
- Library card context menu overlay.

Allowed invalidation:
- Right click may update only the triggering card open state, menu overlay, menu position, and menu dismiss monitor.
- Menu item hover may update only the hovered menu item.
- Confirmed menu commands may update only the affected library item, folder, or watch-state summary.

Forbidden invalidation:
- Right click and menu hover must not trigger card left click, playback open, library snapshot reload, or playback render invalidation.
- Menu measurement and clamp positioning must not rebuild the Library grid or refresh Search/Shiori/table surfaces.

### 2.30 Empty Hint

#### Container
Display: flex
Align Items: center
Justify Content: center
Background: transparent
Border: none

#### Content
Font Family: --font-family-base
Font Size: --font-size-library-meta
Text Color: --color-text-muted

#### Status
Default

#### Cursor
default

### 2.31 App Sidebar Toggle Button

#### Container
Size: --size-icon-button
Radius: --radius-control
Background Default: transparent
Background Hover: --color-bg-hover
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Icon: macOS native sidebar toggle symbol
Icon Size: --size-control-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

### 2.32 App Sidebar Navigation Item

#### Container
Height: --height-app-sidebar-item
Radius: --radius-app-sidebar-item
Padding X: --padding-app-sidebar-item-x
Background Default: transparent
Background Selected: --color-app-sidebar-item-selected-bg
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: navigation item icon
Label: navigation item label
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-app-sidebar-item
Text Color Default: --color-text-primary
Text Color Selected: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-app-sidebar-item-icon
Icon Color Default: --color-icon-default
Icon Color Selected: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Selected
Disabled

#### Cursor
Enabled: pointer
Disabled: not-allowed

### 2.33 App Sidebar Settings Item

#### Container
Height: --height-app-sidebar-item
Radius: --radius-app-sidebar-item
Padding X: --padding-app-sidebar-item-x
Background Default: transparent
Border: none
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: gearshape
Label: Settings
Gap: --spacing-3
Font Family: --font-family-base
Text Size: --font-size-app-sidebar-item
Text Color Default: --color-text-primary
Text Color Disabled: --color-text-disabled
Icon Size: --size-app-sidebar-item-icon
Icon Color Default: --color-icon-default
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Disabled

#### Cursor
Enabled: pointer
Disabled: not-allowed

### 2.34 Player Circle Button

#### Container
Size: --size-player-circle-button
Radius: --radius-player-capsule
Background Default: transparent
Background Hover: --color-player-control-bg-hover
Background Selected: --color-player-text-primary
Background Disabled: transparent

#### Content
Icon Size: --size-player-circle-button-icon
Icon Color Default: --color-player-text-primary
Icon Color Selected: --color-player-icon-selected
Icon Color Disabled: --color-player-text-tertiary

#### Status
Default
Hover
Pressed
Selected
Disabled
Interaction Suppressed

#### Cursor
Enabled: pointer
Disabled: not-allowed
Interaction Suppressed: default

### 2.35 Player Capsule Button

#### Container
Height: --height-player-capsule-button
Radius: --radius-player-capsule
Padding X: --padding-player-capsule-button-x
Background Default: --color-player-control-bg
Background Hover: --color-player-control-bg-hover
Background Disabled: --color-player-control-bg

#### Content
Text Color Default: --color-player-text-primary
Text Color Disabled: --color-player-text-tertiary
Text Size: --font-size-player-time
Font Variant: monospaced digits

#### Status
Default
Hover
Pressed
Menu Open
Disabled
Interaction Suppressed

#### Cursor
Enabled: pointer
Disabled: not-allowed
Interaction Suppressed: default

### 2.36 Player Circle Button Group

#### Container
Height: --height-player-capsule-button
Radius: --radius-player-capsule
Background Default: --color-player-control-bg
Orientation: horizontal
Inner Gap: 0

#### Content
Items: Player Circle Button
Item Background Default: transparent
Item Background Hover: --color-player-control-bg-hover

#### Status
Default
Child Hover
Child Pressed
Child Disabled
Interaction Suppressed

#### Cursor
Container: default
Child Button: pointer

### 2.37 Player Speed Menu

#### Container
Width: --width-player-speed-menu
Height: --height-player-speed-menu
Radius: --radius-player-speed-menu
Padding: --padding-player-speed-menu
Background: --color-player-menu-bg
Border: --color-player-text-tertiary
Shadow: --shadow-player-overlay

#### Content
Item Height: --height-player-speed-menu-item
Item Radius: --radius-player-speed-menu-item
Item Padding X: --padding-player-speed-menu-item-x
Item Background Hover / Selected: --color-player-menu-item-hover-bg
Check Icon Size: --font-size-player-speed-menu-check
Text Size: --font-size-player-speed-menu-item
Text Color: --color-player-text-primary
Selected Indicator: checkmark

#### Status
Closed
Open
Item Default
Item Hover
Item Selected
Interaction Suppressed

#### Cursor
Menu Item: pointer
Menu Background: default

### 2.38 Player Progress Scrubber

#### Container
Height: --height-player-progress-hit-area
Background: transparent

#### Content
Base Track Height: --height-player-progress-track
Interactive Track Height: --height-player-progress-track-hover
Track Radius: --radius-player-capsule
Base Track Color: --color-player-progress-track
Hover Preview Track Color: --color-player-progress-hover-track
Played Track Color: --color-player-progress-fill
Thumb Size: --size-player-progress-thumb
Thumb Color: --color-player-progress-fill
Tooltip: Player Progress Time Capsule

#### Status
Default
Hover
Dragging
Disabled / No Duration

#### Cursor
Track: pointer
Disabled / No Duration: default

### 2.39 Player Progress Time Capsule

#### Container
Height: --height-player-progress-time-capsule
Radius: --radius-player-capsule
Padding X: --padding-player-progress-time-capsule-x
Background: --color-player-control-bg

#### Content
Text Color: --color-player-text-primary
Text Size: --font-size-player-progress-time
Font Variant: monospaced digits

#### Status
Hidden
Visible On Progress Hover
Visible On Progress Drag

#### Cursor
No hit testing

### 2.40 Player Window Control Button

#### Container
Size: --size-player-window-control-button
Radius: --radius-player-capsule
Border: --color-player-window-control-border

#### Content
Close Background: --color-player-window-close
Minimize Background: --color-player-window-minimize
Zoom Background: --color-player-window-zoom
Glyph Color: --color-player-window-control-glyph
Glyph Size: --size-player-window-control-glyph

#### Status
Default
Cluster Hover / Glyph Visible
Pressed

#### Cursor
Enabled: pointer

### 2.41 Player Topbar Title

#### Container
Max Width: --width-player-topbar-title-max
Alignment: center

#### Content
Text: current playback display title
Text Color: --color-player-text-primary
Text Size: --font-size-player-topbar-title
Line Limit: 1
Truncation: tail
Shadow: --shadow-player-topbar-title

#### Status
Default
Truncated

#### Cursor
Default

### 2.42 Destructive Button

#### Container
Height: --height-control
Radius: --radius-control
Padding X: --padding-control-x
Background Default: --color-danger-bg-hover
Background Hover: --color-danger-bg-hover
Background Disabled: --color-bg-disabled
Border Default: transparent
Border Hover: transparent
Border Disabled: --color-border-disabled
Focus Ring: --color-focus-ring + --focus-ring-width + --focus-ring-offset

#### Content
Leading Icon: optional
Gap: --spacing-2
Font Family: --font-family-base
Text Size: --font-size-control
Text Weight: --font-weight-control
Text Color Default: --color-danger-text
Text Color Disabled: --color-text-disabled
Icon Size: --size-button-icon
Icon Weight: --weight-button-icon
Icon Color Default: --color-danger-text
Icon Color Disabled: --color-icon-disabled

#### Status
Default
Hover
Disabled

#### Cursor
Not specified in image

### 2.43 Tag Composer Field

#### Container
Background: transparent
Border: none
Padding X: 0
Padding Y: 0
Gap X: --spacing-2
Gap Y: --spacing-2
Layout: horizontal wrap
Align Items: center
Min Height: fit-content

#### Content
Tags: Chip / Tag
Tag Layout: removable Chip / Tag using [label | x]
Inline Text Input:
  Background: transparent
  Border: none
  Focus Ring: none
  Font Family: --font-family-base
  Font Size: --font-size-body
  Text Color: --color-text-primary
  Placeholder Text: owning layout supplied
  Placeholder Text Color: --color-text-muted
  Width: flexible inline width
  Min Width: enough for text caret and short input
  Search Icon: none
  Clear Button: none

#### Status
Empty
Focused Empty
Typing
Filled With Tags
Filled With Tags And Typing
Disabled

#### Cursor
Tag Body: delegated to owning layout
Tag x Button: pointer
Inline Text Input: text

#### Interaction
Typing: update owning layout's local query state
Tag Body Click: delegated to owning layout
Tag x Click: delegated to owning layout
Click Empty Composer Area: focus Inline Text Input and must not dismiss the owning popover
Focus After Owning Command: owning layout may restore focus to Inline Text Input after add, create, remove association, or dialog cancel / close

#### Refresh Scope
Owner:
- Owning tag composer layout.

Allowed invalidation:
- Typing may update only the inline input value and owning layout's local matching results.
- Tag hover may update only the hovered tag.
- Tag x hover may update only the hovered x button.
- Focus changes may update only the composer field and owning popover focus state.

Forbidden invalidation:
- Typing, focus, hover, and local measurement must not reload table rows or rebuild table snapshots.
- Local input state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore.

## 3. Layout

### 3.1 Recent Watching Card Layout

#### Structure
Container: clickable media card
Orientation: vertical
Gap: --spacing-2
Padding: --padding-library-media-card-hover
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg

#### Content
Cover: Library Cover
Cover Overlay: Library Cover Progress Overlay
Cover Badge: Library Cover Badge / Time
Context Menu: Open Folder, Mark as Finished, Mark as Unwatched, Mark as Watching, Context
Folder Name:
  Font Size: --font-size-library-title
  Text Color: --color-text-primary
  Line Count: 1
Meta Row:
  Episode Label:
    Font Size: --font-size-library-meta
    Text Color: --color-text-muted
  Watch Status: Watch Status Badge

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: media card press feedback
Left Click: open video at saved playback position
Right Click: open Library Card Context Menu without triggering card click
Disabled / Missing File: reduce opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Recent Watching card.

Allowed invalidation:
- Hover and pressed state may update only the current card.
- Cover image loading may update only the current card cover region.
- Left click may hand off explicitly to Playback route owner.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Card hover, cover image loading, and right click must not rebuild the recent watching grid or refresh Search/Shiori/table surfaces.
- Opening playback from a card must not synchronously rebuild hidden Library surfaces unless the command explicitly requires a batched data update.

### 3.2 Library Folder Card Layout

#### Structure
Container: clickable media card
Orientation: vertical
Gap: --spacing-2
Padding: --padding-library-media-card-hover
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg

#### Content
Cover: Library Cover
Cover Badge: Library Cover Badge / Count
Context Menu: Open Folder, Mark All as Finished, Mark All as Unwatched, Mark All as Watching
Folder Name:
  Font Size: --font-size-library-title
  Text Color: --color-text-primary
  Line Count: 1

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: scale card to --scale-library-media-card-pressed while pointer is pressed
Left Click: open Library Folder Detail view
Right Click: open Library Card Context Menu without triggering card click
Disabled / Empty Folder: reduce opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Library folder card.

Allowed invalidation:
- Hover and pressed state may update only the current folder card.
- Cover badge/count changes may update only the current card.
- Left click may update Library Folder Detail route.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Folder card hover and right click must not rebuild the full Library grid, refresh table data, or invalidate Playback.
- Folder route changes must not reload unrelated Search/Shiori surfaces.

### 3.3 Library Episode Grid and Card Layout

#### Grid Structure
Container: Library Folder Detail episode list
Columns: 1
Row Width: 100% of available content width
Minimum Row Width: --width-library-episode-row-min
Gap: --gap-library-episode-grid

#### Card Structure
Container: horizontal episode row
Orientation: horizontal
Align Items: center
Gap: --gap-library-list-item
Padding: --padding-library-list-card
Radius: --radius-library-list-card
Background: transparent
Cover Region: only interactive playback/menu region
Info Region: non-playback information region reserved for future interactions
Hover Radius: --radius-library-media-card-hover applies to Cover Region only
Hover Background: --color-library-media-card-hover-bg applies to Cover Region only
Pressed: Cover Region press feedback only

#### Content
Cover Region:
  Width: --width-library-list-cover
  Height: --height-library-list-cover
  Cover: Library Cover
  Cover Overlay: Library Cover Progress Overlay
  Cover Badge: Library Cover Badge / Time

Info Region:
  Vertical Distribution: first row aligned to top, metadata row aligned to bottom within cover height
  Height: match Cover Region height
  Orientation: vertical
  Gap: --gap-library-list-info-vertical
  First Row:
    Video Name:
      Font Size: --font-size-library-list-title
      Font Weight: semibold
      Text Color: --color-text-primary
      Line Count: 1
    Watch Status: Watch Status Badge
  Second Row:
    Subtitle File:
      Format: 字幕文件：{subtitle file name}
      Font Size: --font-size-library-list-subtitle
      Text Color: --color-text-secondary
      Line Count: 1
  Third Row:
    Video Metadata:
      Format: {video size} {resolution} {frame rate} {codec}
      Separator: space
      Font Size: --font-size-library-list-meta
      Text Color: --color-text-muted
      Line Count: 1

Action Region:
  Removed

Context Menu:
  Menu: Open Folder, Mark as Finished, Mark as Unwatched, Mark as Watching, Context

#### Interaction
Default: transparent background
Cover Hover: show Cover Region hover background and apply Library Cover hover effect
Info Hover: no playback hover background and no Library Cover hover effect
Pressed: Cover Region press feedback only
Left Click: Cover Region opens video at saved playback position
Right Click: Cover Region opens Library Card Context Menu without triggering video playback
Cursor: pointing hand only inside Cover Region
Disabled / Missing File: reduce row opacity and disable Cover Region click/menu

#### Cursor
Default / Hover: pointer
Disabled: not-allowed

#### Refresh Scope
Owner:
- Library episode row and cover region.

Allowed invalidation:
- Cover hover, pressed state, and cover cursor may update only the current episode cover region.
- Cover image loading may update only the current episode cover.
- Left click may hand off explicitly to Playback route owner.
- Right click may hand off explicitly to Library Card Context Menu.

Forbidden invalidation:
- Info Region hover must not trigger playback hover state, menu state, or cover redraw.
- Episode hover, cover loading, and right click must not rebuild the full episode grid or refresh Search/Shiori/table surfaces.
- Opening playback from an episode must not synchronously rebuild hidden Library surfaces unless the command explicitly requires a batched data update.

### 3.4 Library Folder Detail Header Layout

#### Structure
Container: horizontal header
Orientation: horizontal
Gap: --spacing-2
Align Items: center

#### Content
Back Button:
  Base Component: Icon Button
  Icon: chevron.left
Title:
  Base Component: Section Title
  Text: folder name

#### Interaction
Back Button Click: return to Library一级界面
Title: readonly

#### Cursor
Back Button Default / Hover: pointer
Title: default

### 3.5 Search Filter Bar Layout

#### Structure
Container: horizontal toolbar
Orientation: horizontal
Gap: --spacing-3
Align Items: center

#### Content
Search: Search Box
Filter Controls:
  Filter Panel Trigger Button
  Select Trigger Button
  Form Select Field
  Value Input Field
  Logic Connector
  Inline Add Button

#### Interaction
Search Input: update query
Filter Controls: open / edit / clear filters

#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori filter bar and the owning table query state.

Allowed invalidation:
- Typing may update only the input draft.
- Submit may update the owning query or filter snapshot and then reload the owning table.
- Opening filter controls may update only the filter popover and trigger state.
- Editing filter rules may update only the filter builder and owning filter draft until applied.

Forbidden invalidation:
- Typing without submit must not reload table rows.
- Filter popover hover/open state must not invalidate table rows, Playback, Library, App Sidebar, or App Topbar.
- Search filter changes must not update Shiori table state unless the active surface is Shiori.

### 3.6 Search / Shiori Utility Bar Layout

#### Structure
Container: horizontal utility bar
Orientation: horizontal
Gap: --spacing-3
Align Items: center
Justify Content: space-between

#### Content
Left Region:
  Row Info: Count Summary
  Batch Actions:
    Neutral Button
View Controls:
  Icon Button
  Select Trigger Button

#### Interaction
Row Info: readonly
Batch Actions: visible only when selected row count > 0
View Controls: switch table column visibility

#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori utility bar.

Allowed invalidation:
- Row count changes may update Count Summary.
- Selection changes may update Count Summary and Batch Actions visibility.
- View menu changes may update the owning table column layout.
- Batch action button hover may update only the button itself.

Forbidden invalidation:
- Count Summary updates must not redraw table rows.
- Batch action hover must not update row selection or table data.
- View menu open state must not invalidate Playback or unrelated workbench surfaces.

### 3.7 Search / Shiori Table Layout

#### Structure
Container: table region
Orientation: vertical

#### Content
Header: Sortable Header Cell
Rows: Table Row
Selection: Row Selection Checkbox
Text Cell: Interactive Text Cell
Tags: Chip / Tag
Cell Actions: left-click default actions, Shiori Tags popover, and right-click Row Action Menu from declared interactive cell hover regions
Scrollbar: Table Scrollbar
Empty State: Empty Hint

Search Columns:
  Selection
  Display Title
  Cues
  Time

Shiori Columns:
  Selection
  Display Title
  Cues
  Tags
  Time
  Date Added

Column Widths:
  Selection:
    Width: 50pt
    Fixed: yes

  Display Title:
    Width: 240pt
    Fixed: yes

  Time:
    Width: 190pt
    Fixed: yes

  Date Added:
    Applies To: Shiori
    Width: 160pt
    Fixed: yes

  Tags:
    Applies To: Shiori
    Width: 180pt
    Fixed: yes

  Cues:
    Minimum Width: 520pt
    Flexible: yes
    Behavior: expands to fill remaining table content width

Column Visual Priority:
  Cues:
    Role: primary content
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Hover Text Color: --color-text-primary
    Font Weight: 500

  Display Title:
    Role: secondary context
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 500

  Date Added:
    Role: metadata
    Applies To: Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums

  Tags:
    Role: user tag metadata
    Applies To: Shiori
    Cell Content: Chip / Tag

  Time:
    Role: metadata
    Applies To: Search / Shiori
    Text Color: --color-text-secondary
    Font Weight: 500
    Numeric Variant: tabular-nums

Time Column:
  Label: Time
  Source: cue start time and cue end time
  Format: hh:mm:ss - hh:mm:ss
  Short Format: mm:ss - mm:ss when both start and end hour values are 00
  Sort: by cue start time

Cues Column:
  Contains: cue text
  Cell Hover: one rounded rectangle around visible cue text union bounds using --color-bg-hover
  Cell Hover Padding X: --padding-table-cell-hover-x
  Cell Hover Padding Y: --padding-table-cell-hover-y
  Text Hover: underline cue text
  Left Click Behavior: play video
  Right Click Behavior: open Row Action Menu

Tags Column:
  Applies To: Shiori
  Identifier: tags
  Label: Tags
  Source: tags associated with the Shiori cue
  Cell Content: horizontally tiled Chip / Tag items
  Cell Tags: non-removable; do not show x button
  Cell Hover: one rounded rectangle around visible tag content union bounds using --color-bg-hover
  Left Click Behavior: open Shiori Tag Popover Layout
  Right Click Behavior: no action

Search Empty Hint:
  Text: Enter a search term or add filters to show cues.
  Condition: no search term and no effective filter condition

Shiori Empty Hint:
  Text: Save cues from playback to collect Shiori.
  Condition: no saved Shiori rows

#### Interaction
Header: sort / column menu
Rows: no full-row hover or selected background
Header Area: no hover background
Cell Content: hover shows one rounded rectangle around visible text / content union bounds using --color-bg-hover
Cell Content Hit Testing: hover, pointer, underline, left-click action, and right-click menu use the same Cell Content hover region
Non-hover Cell Area Left Click: toggle row checkbox selection
Non-hover Cell Area Right Click: no cell action menu
Interactive Cell Hover: pointer cursor for Display Title, Cues, Time, Date Added, and Tags; underline for Display Title, Cues, Time, and Date Added only
Cues Cell Left Click: Play
Cues Cell Right Click: open Cues Row Action Menu
Display Title Cell Left Click: Open Folder
Display Title Cell Right Click: open Display Title Cell Action Menu
Time Cell Left Click: Copy Text
Time Cell Right Click: open Time Cell Action Menu
Date Added Cell Left Click: Copy Text
Date Added Cell Right Click: open Date Added Cell Action Menu
Tags Cell Left Click: open Shiori Tag Popover Layout
Tags Cell Right Click: no action
Tags Cell Table Chips: non-removable; no x button
Other Data Cells: reserved for future cell menus; no action defined yet
View Menu: Cues is checked + disabled; other data columns can be hidden
Cues Row Action Menu: Play / Context / Copy Cue Text
Display Title Cell Action Menu: Open Folder / Copy Text
Time Cell Action Menu: Copy Text
Date Added Cell Action Menu: Copy Text
Open Folder Action: open the subtitle file's containing folder and select the subtitle file
Copy Text Action: copy the triggering cell's displayed text to the clipboard
Shiori Row Action Menu Extra Item: Remove Shiori
Remove Shiori Action: open Confirmation Dialog Layout
Cell Action Menu Anchor: use the right-click pointer position inside the triggering cell content hover region; menu opens below the click position and clamps to visible content bounds
Tags Cell Hit Testing: full Tags data cell area, including empty space

#### Effective Filter Condition
An effective filter condition is any filter rule that can constrain results.
A filter rule with a non-empty value is effective.
A presence-style filter rule that does not require a value is effective when selected, for example Cues is not empty.

#### Cursor
Inherited from child components

#### Refresh Scope
Owner:
- Search / Shiori table surface.
- Table document, header, scrollbar, selection, tag popover, confirmation dialog, and menu subregions own their own local rendering.

Allowed invalidation:
- Search or Shiori row snapshot changes may update table rows and table summary.
- Column visibility changes may update header, column layout, visible rows, and cursor rects.
- Filter or submitted search changes may reload the owning table data.
- Visible-row changes may request additional rows only for the owning table.
- Row action menus may update only the active row, active menu, and menu overlay.
- Tags cell popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Adding, creating, or removing a tag association for the current Shiori may update only the current row's Tags cell and the open tag popover.
- Confirmed global tag deletion may update only the open tag popover and visible Shiori Tags cells whose cue used the deleted tag.

Forbidden invalidation:
- Table hover, cursor, focus, menu-open, tag popover open, tag popover hover, tag popover typing, tag confirmation dialog, and scrollbar interactions must not invalidate SearchView, App Sidebar, App Topbar, Playback Page, or Playback render host.
- Search table updates must not invalidate Shiori or Library surfaces.
- Shiori table updates must not invalidate Search or Library surfaces.
- Tag popover typing and hover must not reload table rows, rebuild table snapshots, or start background row hydration.
- Adding or creating a tag association for the current Shiori must not update any other Shiori row's Tags cell.
- Tag association changes must not rebuild the full table snapshot when the current or affected visible Tags cells can be patched.
- Background row hydration must not run while the owning table surface is not allowed to respond to interaction.

### 3.8 App Sidebar Layout

#### Structure
Container: persistent left navigation sidebar
Position: window left edge
Width: --width-app-sidebar
Height: full window height
Background: --color-app-sidebar-bg
Orientation: vertical
Padding X: --padding-app-sidebar-x
Padding Y: --padding-app-sidebar-y

#### Regions
Top Safe Area:
  Purpose: reserve space for macOS traffic light buttons and sidebar toggle

Navigation Region:
  Orientation: vertical
  Gap: --spacing-1
  Items: App Sidebar Navigation Item

Navigation Items:
  Search:
    Icon: magnifyingglass
  Recent:
    Icon: current Test Recent Watching icon
  Library:
    Icon: current sidebar Library icon
  Shiori:
    Icon: current Shiori icon

Spacer:
  Behavior: fills remaining vertical space

Bottom Region:
  Items: App Sidebar Settings Item

#### Expanded State
Default: expanded
Content:
  Show navigation item icons
  Show navigation item labels
  Show settings item icon
  Show settings item label

#### Collapsed State
Content:
  Sidebar content is hidden
  Sidebar layout width is removed from main content
Toggle Button:
  Remains visible in titlebar
  Position follows fullscreen / windowed titlebar rules

#### Selection
Selected Item:
  Background: --color-app-sidebar-item-selected-bg
  Text Color: --color-text-primary
  Icon Color: --color-icon-default

#### Interaction
Navigation Item Click:
  Switch active workbench page
  Clicking current selected item does nothing

Settings Item Click:
  Open Settings window

Sidebar Toggle Click:
  Expand / collapse sidebar
  Persist expanded / collapsed state

#### Cursor
Navigation Item: pointer
Settings Item: pointer
Sidebar Toggle: pointer

#### Persistence
Sidebar Expanded State:
  Persist across app restarts

#### Refresh Scope
Owner:
- App sidebar layout.

Allowed invalidation:
- Sidebar item hover may update only the hovered sidebar item.
- Sidebar expand / collapse may update sidebar width, app topbar leading layout, and current workbench surface frame.
- Navigation item click may update the active workbench route and mount the selected surface.

Forbidden invalidation:
- Sidebar hover, cursor, and expand / collapse must not reload Search, Shiori, Library, or Playback data.
- Window width changes and compact sidebar behavior must not rebuild table snapshots or playback render host.
- Hidden workbench surfaces must not start background loading only because sidebar state changed.

### 3.9 App Topbar Layout

#### Structure
Container: non-player app titlebar layout
Position: window top edge
Width: full window width
Height: --height-app-topbar
Background: --color-app-topbar-bg
Orientation: horizontal

#### Regions
Sidebar Segment:
  Visible when App Sidebar Layout is expanded
  Width: --width-app-sidebar
  Background: --color-app-sidebar-bg

Sidebar Toggle Slot:
  Contains: App Sidebar Toggle Button
  Position: follows fullscreen / windowed titlebar rules
  Remains visible when App Sidebar Layout is collapsed

Title Slot:
  Contains: existing title component
  Does not define a new title component

#### Expanded Sidebar State
Sidebar Segment:
  Visible
Title Leading:
  --width-app-sidebar + --padding-app-topbar-title-x

#### Collapsed Sidebar State
Sidebar Segment:
  Hidden
Sidebar Layout Width:
  Removed from main content
Title Leading:
  max(--padding-app-topbar-title-x, sidebar toggle trailing edge + --gap-app-topbar-title-after-toggle)

#### Behavior
Empty Titlebar Area:
  Supports native window drag

Double Click:
  Follows macOS titlebar double-click behavior

#### Playback
When playback page is visible:
  Hide App Topbar Layout
  Playback page owns its own topbar / chrome behavior

#### Refresh Scope
Owner:
- App topbar layout.

Allowed invalidation:
- Sidebar expanded / collapsed state may update topbar layout and title leading position.
- Playback page visibility may hide or show the app topbar.
- Window width changes may update compact sidebar behavior.

Forbidden invalidation:
- App topbar hover, drag, double-click, and visibility changes must not reload Search, Shiori, Library, or Playback data.
- App topbar state must not invalidate playback render host.

### 3.10 Confirmation Dialog Layout

#### Structure
Container: modal dialog
Orientation: vertical
Align Items: stretch
Backdrop: modal overlay
Panel: centered dialog surface
Panel Background: --color-bg-surface
Panel Radius: --radius-control
Panel Border: --color-border-control
Panel Shadow: none
Layout Sections:
  1. Title
  2. Message
  3. Actions

#### Content
Title:
  Text: action-specific title
  Color: --color-text-primary
Message:
  Text: action-specific message
  Color: --color-text-muted
Actions:
  Alignment: trailing
  Layout: horizontal
  Neutral Button
  Destructive Button

#### Remove Shiori Content
Title: Remove Shiori
Message: This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.
Cancel Action Button:
  Base Component: Neutral Button
  Text: Cancel
Destructive Action Button:
  Base Component: Destructive Button
  Text: Remove

#### Delete Tag Content
Title: Delete Tag
Message: Are you sure you want to delete this tag? This will remove the tag from all cues. This action cannot be undone.
Cancel Action Button:
  Base Component: Neutral Button
  Text: Cancel
  Default Focus: yes
Destructive Action Button:
  Base Component: Destructive Button
  Text: Delete
  Text Color: --color-danger-text
  Hover Background: --color-danger-bg-hover

#### Interaction
Default Focus: Cancel Action Button
Cancel Action: close dialog without changes
Remove Shiori Action: remove the Shiori row, close dialog, refresh Shiori table and selection state
Delete Tag Action: delete the tag globally, close dialog, refresh the open Shiori Tag Popover and affected visible Shiori Tags cells
Confirmed Destructive Action: execute only the requested command target
Escape Key: same as Cancel
Return Key: activate default focused action
Click Outside: no action, dialog remains open

#### Refresh Scope
Owner:
- Confirmation dialog overlay.

Allowed invalidation:
- Dialog open / close may update only the dialog overlay, focus state, and the command target state.
- Cancel, Escape, and click outside may close or retain only the dialog state.
- Confirmed destructive action may update only the affected data owner and its declared selection state.

Forbidden invalidation:
- Dialog hover, focus, and open state must not reload table rows, rebuild Library grids, or invalidate Playback.
- Dialog measurement and focus changes must not update Search/Shiori/Library data before the user confirms the action.

### 3.11 Player Topbar Layout

#### Structure
Container: player windowed topbar
Position: playback page top edge
Width: full window width
Height: --height-player-topbar
Background: --color-player-topbar-gradient-start -> --color-player-topbar-gradient-end
Orientation: horizontal
Visibility: follows player UI visible / hidden state
Fullscreen: hidden; native macOS fullscreen titlebar owns fullscreen top chrome

#### Regions
Window Control Cluster:
  Position: leading
  Contains: Player Window Control Button
  Items:
    Close
    Minimize
    Zoom
  Gap: --gap-player-window-controls

Title Slot:
  Position: centered in topbar
  Contains: Player Topbar Title
  Max Width: --width-player-topbar-title-max
  Alignment: center

Empty Titlebar Area:
  Purpose: native window drag and titlebar double-click behavior
  Hit Testing: does not block window control buttons

#### Content
Player Window Control Button:
  Close: return from playback page to originating page
  Minimize: minimize app window
  Zoom: enter fullscreen
  Glyph: visible on control cluster hover

Player Topbar Title:
  Text: current playback display title
  Font Size: --font-size-player-topbar-title
  Text Color: --color-player-text-primary
  Line Limit: 1
  Truncation: tail
  Shadow: --shadow-player-topbar-title

#### Interaction
Pointer Enters Window Control Cluster:
  Show button glyphs

Pointer Exits Window Control Cluster:
  Hide button glyphs

Close Click:
  End / close current playback page according to playback close lifecycle

Minimize Click:
  Minimize native app window

Zoom Click:
  Enter fullscreen

Empty Area Drag:
  Move native window

Empty Area Double Click:
  Follow macOS titlebar double-click behavior

#### Cursor
Window Control Button: pointer
Title: default
Empty Titlebar Area: default

#### Refresh Scope
Owner:
- Player topbar layer.

Allowed invalidation:
- Window control cluster hover may update only the window control glyph visibility.
- Player UI visible / hidden state may update only player topbar visibility and player chrome visibility.
- Player title changes may update only Player Topbar Title and playback chrome title surfaces.

Forbidden invalidation:
- Player topbar hover, drag, double-click, and window-control hover must not invalidate Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
- Player topbar visibility changes must not resize, recreate, or reattach the playback render host.

### 3.12 Player Bottom Control Bar Layout

#### Structure
Container: player bottom control bar
Position: playback page bottom edge
Width: full playback stage width
Height: --height-player-bottom-control-bar
Background: transparent
Orientation: vertical
Visibility: follows player UI visible / hidden state

#### Regions
Progress Region:
  Position: top of bottom control bar
  Contains: Player Progress Scrubber
  Padding X: --padding-player-chrome-x

Control Region:
  Position: below Progress Region
  Orientation: horizontal
  Height: --height-player-bottom-controls-row
  Padding X: --padding-player-chrome-x
  Padding Bottom: --padding-player-chrome-bottom

Left Control Group:
  Alignment: leading
  Gap: --gap-player-bottom-left-controls
  Contains:
    Player Circle Button: play / pause
    Player Circle Button Group: previous / next
    Existing Playback Volume Control
    Player Capsule Button: playback time display

Right Control Group:
  Alignment: trailing
  Gap: --gap-player-bottom-right-controls
  Contains:
    Player Circle Button Group: Shiori / copy / subtitles
    Player Capsule Button: speed
    Player Circle Button: fullscreen

Spacer:
  Behavior: fills space between Left Control Group and Right Control Group

#### Content
Player Circle Button:
  Size: --size-player-circle-button
  Icon Size: --size-player-circle-button-icon
  Default Background: transparent or --color-player-control-bg when persistent base is needed
  Hover Background: --color-player-control-bg-hover

Player Capsule Button:
  Height: --height-player-capsule-button
  Radius: --radius-player-capsule
  Background: --color-player-control-bg
  Hover Background: --color-player-control-bg-hover
  Text Color: --color-player-text-primary

Player Circle Button Group:
  Height: --height-player-capsule-button
  Radius: --radius-player-capsule
  Background: --color-player-control-bg
  Contains: multiple Player Circle Button instances
  Inner Gap: 0 unless the component specifies otherwise

Speed Button:
  Component: Player Capsule Button
  Width: --width-player-speed-button
  Text: current playback speed
  Text Alignment: center
  Opens: Player Speed Menu
  Menu Gap: --gap-player-speed-menu-from-button

#### Interaction
Player Circle Button Click:
  Run the button command

Player Capsule Button Click:
  Run the button command or open related menu

Speed Button Click:
  Toggle Player Speed Menu

Timeline Scrubbing Active:
  Suppress unrelated hover and menu interaction until scrubbing ends

Pressed State:
  Apply shared player button press motion

Hover State:
  Apply shared player button hover motion

#### Cursor
Player Circle Button: pointer
Player Capsule Button: pointer
Player Circle Button Group Background: default

#### Refresh Scope
Owner:
- Playback chrome layer.
- High-frequency playback time state is owned by progress, time label, and subtitle overlay subregions, not by the whole chrome shell.

Allowed invalidation:
- Player button hover / pressed states may update only the corresponding control.
- Playback time updates may update only progress, time labels, and current subtitle overlay.
- Speed menu state may update only the speed button, speed menu, menu anchor measurement, and menu dismiss monitor.
- Volume hover and dragging may update only the volume control and volume value.
- Timeline scrubbing may update progress preview, scrub time, and seek pipeline.
- Quick playback commands may update playback state and the corresponding command feedback surface.

Forbidden invalidation:
- Playback chrome hover, speed menu, volume changes, time ticks, subtitle visibility toggles, and button hover must not invalidate Search, Shiori, Library, table surfaces, App Sidebar, or App Topbar.
- High-frequency playback time updates must not re-evaluate the whole chrome shell when only progress, time label, or current subtitle changed.
- Non-geometry chrome updates must not resize, recreate, or reattach the playback render host.

### 3.13 Player Progress Scrubber Layout

#### Structure
Container: player progress scrubber
Position: top region of Player Bottom Control Bar
Width: full available width
Height: --height-player-progress-hit-area
Background: transparent
Orientation: horizontal

#### Regions
Track Region:
  Position: vertically centered in hit area
  Contains:
    Base Track
    Hover Preview Track
    Played Track
    Thumb

Progress Time Capsule Region:
  Position: above hovered or dragged progress position
  Contains: Player Progress Time Capsule
  Visibility: visible on hover or drag when media duration is available

#### Content
Base Track:
  Height: --height-player-progress-track
  Hover / Drag Height: --height-player-progress-track-hover
  Radius: --radius-player-capsule
  Color: --color-player-progress-track

Hover Preview Track:
  Visible: hover only, hidden during drag if scrub time owns preview
  Width: from track start to pointer position
  Height: matches current track height
  Color: --color-player-progress-hover-track

Played Track:
  Width: current playback progress
  Height: matches current track height
  Color: --color-player-progress-fill

Thumb:
  Size: --size-player-progress-thumb
  Color: --color-player-progress-fill
  Visibility: visible on hover or drag

Player Progress Time Capsule:
  Height: --height-player-progress-time-capsule
  Radius: --radius-player-capsule
  Padding X: --padding-player-progress-time-capsule-x
  Background: --color-player-control-bg
  Text Color: --color-player-text-primary
  Font Size: --font-size-player-progress-time
  Font Variant: monospaced digits
  Placement: horizontally centered on hover / drag position, clamped within scrubber bounds

#### Interaction
Pointer Hover:
  Increase track height
  Show Hover Preview Track
  Show Thumb
  Show Player Progress Time Capsule

Pointer Move:
  Update Hover Preview Track width
  Update Player Progress Time Capsule text and position

Drag Start:
  Begin timeline scrubbing
  Show Thumb
  Show Player Progress Time Capsule
  Suppress unrelated player chrome hover interactions

Drag Move:
  Update scrub target time
  Update Played Track preview
  Update Player Progress Time Capsule text and position

Drag End:
  Seek to final target time
  End timeline scrubbing
  Restore normal player chrome interaction

Pointer Exit:
  Hide Hover Preview Track
  Hide Thumb unless dragging
  Hide Player Progress Time Capsule unless dragging

#### Cursor
Track Region: pointer
Progress Time Capsule: default, no hit testing

#### Refresh Scope
Owner:
- Player progress scrubber.

Allowed invalidation:
- Pointer hover may update hover preview track, thumb visibility, and time capsule.
- Pointer move may update hover preview width and time capsule position/text.
- Drag may update scrub target time, played-track preview, thumb, time capsule, and seek command.
- Drag start/end may update timeline scrubbing state.

Forbidden invalidation:
- Progress hover and drag must not invalidate workbench surfaces.
- Progress hover and drag must not trigger table row hydration, Search/Shiori/Library refresh, or Playback render host layout unless video geometry changes.

### 3.14 Shiori Tag Popover Layout

#### Structure
Container: popover overlay
Orientation: vertical
Layout Sections:
  1. Current Tags and Search
  2. Global Tag Pool
Section Separator: none
Popover Anchor: left-click pointer position inside the triggering Shiori Tags cell
Popover Position: below the click position, clamped to visible content bounds
Dismiss: click outside popover closes the popover
Inside Popover Click: never dismisses the popover by itself
Popover Measurement: remeasure and reclamp when local content changes
Delete Tag Confirmation: centered Confirmation Dialog Layout overlay using Delete Tag Content; not embedded inside the popover panel
System Popover Arrow: none

#### Content
Current Tags and Search:
  Hint Text: Current Tags
  Hint Text Color: --color-text-muted
  Section Background: transparent
  Tag Composer: Tag Composer Field
  Tag Composer Tags: tags associated with the current Shiori cue
  Tag Composer Tag Style: Removable Chip / Tag using [label | x]
  Tag Composer Input: search or create tag query

Global Tag Pool:
  Hint Text: Select a tag or create one
  Hint Text Color: --color-text-muted
  Section Background: transparent
  Tags Layout: horizontal wrap
  Tags When Input Is Empty: all existing tags, including tags already associated with the current Shiori cue
  Tags When Input Is Not Empty: existing tags matching the current input, including matching tags already associated with the current Shiori cue
  Global Tag Style: Removable Chip / Tag using [label | x]
  Global Tag Style Consistency: same Shiori Tag visual style as table Tags cell; x button is the only visual difference
  Create Option Visibility: when the current input is not empty and no existing tag exactly matches it
  Create Option Layout: horizontal row
  Create Option Content: Create label + non-removable Chip / Tag preview using the current input text
  Create Option Hover Background: --color-bg-hover

#### Interaction
Open Trigger: left click on a Shiori Tags cell
Open Behavior: open at the left-click pointer position using the same positioning and clamping behavior as Row Action Menu
Open Focus: automatically focus the Tag Composer Inline Text Input
Tag Composer Placeholder / No Current Tags: Add a tag
Tag Composer Placeholder / Has Current Tags: none
Typing In Tag Composer: update local search text, Global Tag Pool matching results, Create Option visibility, and popover measurement
Click Matching Global Tag / Not Associated: add that tag only to the current Shiori cue, clear the input, keep the popover open, and restore focus to Tag Composer Inline Text Input
Click Matching Global Tag / Already Associated: no action, no prompt, keep the popover open, and keep focus in the popover
Click Create Option: create the tag, add it only to the current Shiori cue, clear the input, keep the popover open, and restore focus to Tag Composer Inline Text Input
Current Tag Body Click: no action
Current Tag x Click: remove only that tag association from the current Shiori cue, keep the popover open, and restore focus to Tag Composer Inline Text Input
Global Tag Body Click / Not Associated: add that tag only to the current Shiori cue, clear the input, keep the popover open, and restore focus to Tag Composer Inline Text Input
Global Tag Body Click / Already Associated: no action, no prompt, keep the popover open, and keep focus in the popover
Global Tag x Click: open centered Confirmation Dialog Layout using Delete Tag Content; keep the Shiori Tag Popover open behind the dialog
Delete Tag Dialog Cancel: close only the dialog and restore focus to Tag Composer Inline Text Input
Delete Tag Dialog Confirm: delete the tag globally, close only the dialog, refresh the open Shiori Tag Popover and affected visible Shiori Tags cells, and restore focus to Tag Composer Inline Text Input
Right Click: no action
Escape Key: close popover when Delete Tag dialog is not open; cancel Delete Tag dialog when it is open
Click Inside Popover Background: no dismiss; keep focus in the popover
Click Empty Tag Composer Area: focus Tag Composer Inline Text Input

#### Cursor
Popover Background: default
Tag Composer Inline Text Input: text
Create Option Row: pointer
Tag Body: pointer when the owning interaction has an action; default when no action is available
Tag x Button: pointer

#### Refresh Scope
Owner:
- Shiori tag popover overlay.
- Centered Delete Tag confirmation dialog overlay when opened from the Shiori tag popover.
- Current Shiori row Tags cell for current-cue association changes.
- Visible Shiori Tags cells affected by confirmed global tag deletion.

Allowed invalidation:
- Popover open / close may update only the active row, active Tags cell trigger, popover overlay, focus state, and dismiss monitor.
- Typing in Tag Composer may update only the composer input value, Global Tag Pool matching tags, Create Option visibility, focus state, and open popover measurement.
- Tag hover, x hover, and Create Option hover may update only the hovered tag, x button, or Create Option row.
- Adding an existing tag may update only the current row Tags cell, Tag Composer tags, Global Tag Pool associated/no-op state, composer input value, and popover focus state.
- Creating a tag may update only the current row Tags cell, Tag Composer tags, Global Tag Pool tags, composer input value, and popover focus state.
- Removing a current tag association may update only the current row Tags cell, Tag Composer tags, Global Tag Pool associated/no-op state, and popover focus state.
- Opening Delete Tag confirmation may update only the centered dialog overlay and dialog focus state while keeping the Shiori Tag Popover open.
- Canceling Delete Tag confirmation may update only the centered dialog overlay and restore Shiori Tag Popover focus.
- Confirmed global tag deletion may update only the centered dialog overlay, open popover tag sections, and visible Shiori Tags cells whose cue used the deleted tag.
- Typing in Tag Composer may remeasure and reclamp only the open popover overlay.

Forbidden invalidation:
- Popover open, close, typing, focus, hover, and measurement must not reload Shiori table rows or rebuild the Shiori table snapshot.
- Popover local state must not be written into SearchStore, ShioriStore, LibraryStore, or PlaybackStore unless the user confirms a data-changing command.
- Adding, creating, removing, or deleting tags must not invalidate SearchView, Library, Playback Page, or Playback render host.
- Adding or creating a tag for the current Shiori cue must not update any other Shiori row's Tags cell unless that row has its own separate association refresh.
- Confirmed global tag deletion must not rebuild the full Shiori table snapshot when affected visible Tags cells can be patched.
- Global tag body click on an already associated tag must not publish state changes, show a prompt, reload data, or redraw unrelated rows.
- Delete Tag confirmation must not be measured, positioned, clipped, or hosted as popover content.

Probe / verification:
- Opening the popover keeps table snapshot rebuild count at 0.
- Typing in Tag Composer keeps table row reload count at 0.
- Adding or removing a current tag redraws only the current visible Tags cell and the popover.
- Confirmed global tag deletion redraws only affected visible Tags cells and the popover.

## 4. Refresh Scope Contract

### 4.1 Global Rule

#### Contract
Every UI interaction must define a rendering owner and must stay inside its allowed invalidation scope.

Allowed state changes:
- The owning component may update its own local visual state.
- The owning data surface may update its own stable snapshot.
- Cross-surface actions may update another surface only through an explicit owner handoff.
- Layout changes may update geometry and visibility for declared layout owners only.
- Background loading may update only the visible or explicitly active data owner that requested it.

Forbidden state changes:
- Local hover, focus, pressed, cursor, drag, right-click, checkbox, and menu-open states must not be written into global stores.
- A component must not subscribe to a store or observable object unless it renders that state directly.
- Background loading must not invalidate unrelated visible surfaces.
- Playback video rendering must not be invalidated by non-playback interactions.
- NSViewRepresentable updates must diff meaningful inputs and must not redraw their full content when only callbacks, cursor state, or unrelated parent state changed.
- Hidden or playback-covered surfaces must not respond to routine hover, menu, selection, scroll, or background loading events.

Required implementation checks:
- Each new interaction must identify Owner, Allowed Invalidation, Forbidden Invalidation, and Probe / verification point before implementation.
- Each new store subscription must identify the exact rendered fields and prove that unrelated field changes do not invalidate the component.

### 4.2 Invalidation Source Categories

#### Contract
Each UI update source must be classified before implementation.

Categories:
- Visual-local: hover, focus, pressed, cursor, menu item hover.
- Selection-local: checkbox toggle, row selection, batch action visibility.
- Overlay-local: popover, context menu, dialog, tooltip, measurement, dismiss monitor.
- Layout-local: window width, sidebar collapse, topbar visibility, route frame.
- Data-local: search results, shiori rows, library cards, watch state, cover image.
- Cross-surface command: open playback, open folder, copy, export, mark watched.
- High-frequency playback: time tick, progress hover, scrub drag, subtitle text.
- Background loading: hydrate, continuous load, image load, detail load, count load.

Rule:
- Each category must declare its owner, allowed invalidation, forbidden invalidation, and probe.

### 4.3 Store Subscription Boundary

#### Contract
Components must subscribe only to state they render directly.

Required behavior:
- Large stores must be split by view boundary, projected into stable snapshots, or passed as value props before reaching high-frequency or large-list components.
- Local interaction state must remain local unless another owner explicitly renders it.
- Store writes should be batched or deduplicated when a command updates multiple related fields.

Forbidden behavior:
- A top-level workbench component must not observe a large store only to pass callbacks.
- A list row, card, table bridge, or playback control must not observe a global store for command access when stable closures are sufficient.
- High-frequency playback state must not be stored in a way that invalidates non-time chrome controls.

### 4.4 Visibility and Activity Gate

#### Contract
A surface may respond only when it is visible, active, or explicitly declared as a background owner.

Required behavior:
- Playback-covered workbench surfaces must suppress routine hover, menu, selection, scroll, and background loading responses.
- Hidden Search, Shiori, and Library surfaces may defer data refresh until they become visible.
- Background tasks must check the current owner generation before publishing results.

Forbidden behavior:
- Hidden surfaces must not rebuild snapshots only because another surface changed route, layout, menu, or playback state.
- Playback entry must not synchronously refresh unrelated table or library presentations.

### 4.5 Probe and Verification

#### Contract
Refresh scope changes must be measurable.

Required probes:
- Log the user action name.
- Count the expected owner body/render/update.
- Count forbidden surfaces that must remain unchanged.
- Record table snapshot rebuilds, row hydration, library snapshot rebuilds, playback render host updates, and high-frequency playback chrome updates.

Acceptance:
- A change passes only when the expected owner updates and forbidden surfaces do not update for the tested interaction.
