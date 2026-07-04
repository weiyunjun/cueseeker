# 版本
main

# 需求描述
1. Library二级界面，去掉Play按钮，封面图新增和Library一级界面一样的Hover效果和点击播放效果。排版上，视频信息栏需要往右移一些。
2. Recent和Library一级/二级界面，hover区域，右键点击后弹出菜单。
3. Recent和Library二级界面的弹出菜单：Open Folder，Mark as Finished，Mark as Unwatched，Mark as Watching，Context。其中Open Folder后会打开视频所在文件夹并选中对应视频，Context会默认从第一个Cue Group开始显示。
4. Library一级界面的弹出菜单：Open Folder，Mark All as Finished，Mark All as Unwatched，Mark All as Watching。其中Open Folder后会打开视频所在文件夹并不选中任何文件。

# UI文档改动

### 1.2 尺寸、圆角、间距

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

### 2.16 Row Action Menu

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

### 2.29 Library Card Context Menu

#### Container
Style: Row Action Menu
Trigger: right click on Library card hover region
Menu Background: --color-bg-popover
Menu Border: --color-border-muted
Menu Border Radius: --radius-menu
Menu Shadow: --shadow-popover
Menu Padding: --spacing-1
Menu Item Hover Background: --color-bg-hover
System Popover Arrow: none

#### Anchor
Recent Watching Card: right-click position inside card hover region
Library Folder Card: right-click position inside card hover region
Library Episode Card: right-click position inside card hover region
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

### 3.1 Recent Watching Card Layout
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

### 3.2 Library Folder Card Layout

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

### 3.3 Library Episode Grid and Card Layout

#### Card Structure
Container: clickable media card
Orientation: horizontal
Align Items: center
Gap: --gap-library-list-item
Padding: --padding-library-list-card
Radius: --radius-library-list-card
Background: transparent
Hover Radius: --radius-library-media-card-hover
Hover Background: --color-library-media-card-hover-bg
Pressed: media card press feedback

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
Hover: show hover background and apply Library Cover hover effect
Pressed: media card press feedback
Left Click: open video at saved playback position
Right Click: open Library Card Context Menu without triggering card click
Disabled / Missing File: reduce row opacity and disable click

#### Cursor
Default / Hover: pointer
Disabled: not-allowed