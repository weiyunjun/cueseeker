# 版本
main

# 需求描述
修改部分UI界面颜色，详见# UI文档改动。

# UI文档改动
### 1.1 颜色
#### Focus
--color-border-focus:
  System: macOS accent color
  Implementation: SwiftUI Color.accentColor / AppKit NSColor.controlAccentColor
--color-focus-ring:
  System: macOS accent color with opacity
  Light Alpha: 0.22
  Dark Alpha: 0.30

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