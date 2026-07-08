# 版本
main

# 需求描述
1. 修改Remove Shiori界面的警告提示框。
2. 将其改造为通用的警告提示界面，后续类似界面只需传递参数即可调用。
3. 新增警告提示界面的Layout，分为从上到下的3部分：标题（Remove Shiori，--color-text-primary），提示文字（This cue will be removed from your Shiori. The original subtitle and video files will not be deleted. --color-text-muted），两个按钮（一个普通按钮，一个警告按钮，2个按钮整体居右）。
4. 警告按钮，需要新建component：淡红色的背景色和红色的字体颜色。
5. 详细UI改动见# UI文档改动。

# UI文档改动

**修改 1：新增 Destructive Button 组件**  

修改前

无，新增内容。

修改后

```markdown
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
```

**修改 2：Confirmation Dialog Layout / Structure**

修改前

```markdown
#### Structure
Container: modal dialog
Orientation: vertical
Align Items: center
Backdrop: modal overlay
Panel: centered dialog surface
```

修改后

```markdown
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
```

**修改 3：Confirmation Dialog Layout / Content**

修改前

```markdown
#### Content
Icon:
  Source: action-specific icon
  Size: --size-icon-button
  Color: --color-icon-default
Title:
  Text: action-specific title
Message:
  Text: action-specific message
Actions:
  Neutral Button
  Neutral Button
```

修改后

```markdown
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
```

**修改 4：Confirmation Dialog Layout / Remove Shiori Content**

修改前

```markdown
#### Remove Shiori Content
Icon: bookmark.slash
Icon Fallback: bookmark
Title: Remove Shiori?
Message: This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.
Primary Action Button:
  Base Component: Neutral Button
  Text: Remove
Cancel Action Button:
  Base Component: Neutral Button
  Text: Cancel
```

修改后

```markdown
#### Remove Shiori Content
Title: Remove Shiori
Message: This cue will be removed from your Shiori. The original subtitle and video files will not be deleted.
Cancel Action Button:
  Base Component: Neutral Button
  Text: Cancel
Destructive Action Button:
  Base Component: Destructive Button
  Text: Remove
```