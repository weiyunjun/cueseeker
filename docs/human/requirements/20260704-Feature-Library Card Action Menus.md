# 版本
main

# 需求描述
1. 在视频封面图右上方，添加...按钮，点击后弹出菜单。...按钮是圆形的，灰色半透明底，hover后有一个白色的底。类似播放器界面的播放按钮。
2. Recent和Library一级/二级界面的...按钮，点击以后弹出菜单，样式复用已有的菜单样式。
3. Recent和Library二级界面的...按钮的弹出菜单：Open Folder，Mark as Finished，Mark as Unwatched，Mark as Watching，Context。其中Open Folder后会打开视频所在文件夹并选中对应视频，Context会默认从第一个Cue Group开始显示。
4. Library一级界面的...按钮的弹出菜单：Open Folder，Mark All as Finished，Mark All as Unwatched，Mark All as Watching。其中Open Folder后会打开视频所在文件夹并不选中任何文件。
5. Library二级界面，去掉Play按钮，封面图新增和Library一级界面一样的Hover效果。点击封面图hover区域除...按钮之外的地方，播放视频。Recent和Library二级界面，点击除...按钮之外的地方，播放视频。

# UI文档改动

### 1.2 尺寸、圆角、间距
#### Library Interaction
--scale-library-media-card-pressed: 0.98
--scale-library-cover-hover: 1.02
--duration-library-cover-hover: 0.12s
--duration-library-card-action-hover: 0.12s

#### Library Size
--aspect-library-cover: 16 / 9
--height-library-progress-bar: 4px
--width-library-recent-card-min: 180px
--width-library-recent-card-max: 220px
--width-library-episode-row-min: 380px
--width-library-list-cover: 204px
--height-library-list-cover: 115px
--height-library-list-button: 30px
--width-library-folder-cover: 120px
--min-height-library-folder-card: 96px
--size-library-card-action-button: 32px
--size-library-card-action-icon: 16px

### 2.29 Library Card Action Button and Menu

#### Action Button Container
Size: --size-library-card-action-button
Radius: full circle
Background Default: Color.black.opacity(0.3)
Background Hover: Color.white
Animation: --duration-library-card-action-hover
Placement: cover top trailing overlay

#### Action Button Content
Icon: ellipsis
Icon Size: --size-library-card-action-icon
Icon Weight: semibold
Icon Color Default: Color.white
Icon Color Hover: PlaybackTheme.iconSelected

#### Menu Container
Style: Row Action Menu
Anchor: Library Card Action Button

#### Menu Content
Open Folder Icon: folder
Mark as Finished Icon: checkmark.circle
Mark as Unwatched Icon: circle
Mark as Watching Icon: play.circle
Context Icon: search
Menu Item Text Color Default: --color-text-primary
Menu Item Icon Color Default: --color-text-primary

#### Status
Default
Hover
Menu Open
Disabled

#### Cursor
Enabled: pointer
Disabled: not-allowed

### 3.1 Recent Watching Card Layout
#### Content
Cover: Library Cover
Cover Overlay: Library Cover Progress Overlay
Cover Badge: Library Cover Badge / Time
Cover Action: Library Card Action Button
Action Menu: Open Folder, Mark as Finished, Mark as Unwatched, Mark as Watching, Context
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
Click: open video at saved playback position, except Library Card Action Button
Action Menu Click: open menu without triggering card click
Disabled / Missing File: reduce opacity and disable click

### 3.2 Library Folder Card Layout

#### Content
Cover: Library Cover
Cover Badge: Library Cover Badge / Count
Cover Action: Library Card Action Button
Action Menu: Open Folder, Mark All as Finished, Mark All as Unwatched, Mark All as Watching
Folder Name:
  Font Size: --font-size-library-title
  Text Color: --color-text-primary
  Line Count: 1

#### Interaction
Default: transparent background
Hover: show hover background
Pressed: scale card to --scale-library-media-card-pressed while pointer is pressed
Click: open Library Folder Detail view, except Library Card Action Button
Action Menu Click: open menu without triggering card click
Disabled / Empty Folder: reduce opacity and disable click

### 3.3 Library Episode Grid and Card Layout

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

Cover Action:
  Component: Library Card Action Button
  Menu: Open Folder, Mark as Finished, Mark as Unwatched, Mark as Watching, Context

#### Interaction
Default: transparent background
Hover: no card background highlight and no card scale animation
Pressed: no card scale animation
Card Click: open video at saved playback position, except Library Card Action Button
Action Menu Click: open menu without triggering card click
Disabled / Missing File: reduce row opacity and disable click