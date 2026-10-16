# 说明
1. 本文档由人类维护，定义工作台与对话框界面布局（`L-01` ~ `L-06`）：App Shell、Settings、Recent、Library and File、Search and Excerpt、Dialogs。
2. 通用布局边距、滚动条预留通道与 Dialog 等距测量基准详见 `/docs/human/design/ui/UI Design Rules.md`。

# 3. Layouts（Part 1：Workbench & Dialogs `L-01` ~ `L-06`）

## 3.1 App Shell

### L-01.1 App Sidebar Layout

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

### L-01.2 App Topbar Layout

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
- Trailing Padding：`--padding-app-topbar-trailing`

#### Page Title

- 一级页：Search、Recent、Library、File、Excerpt
- 二级页：Library 二级页显示 `Library`，Excerpt 二级页显示 `Excerpt`，其它二级页为 None
- 页面已不存在：顶栏保持所属业务页面标题（如 Library、Excerpt）
- 宽度：Back、Forward 与 Trailing Function Region 之外的剩余宽度，不足时尾部截断

#### States

- History Start：Back Disabled
- History End：Forward Disabled
- Sidebar Expanded
- Sidebar Collapsed
- Below Function Region Minimum Width：Function Region 与 Trailing Function Region 随页面一起横向滚动，Window Controls 与 Sidebar Toggle 不参与
- Hidden On Playback：Task Entry 与 Settings Entry 改由播放页与 Playback Overlay 的顶栏显示
- Settings Window Open：Settings Entry Open，窗口最小化期间保持

### L-01.3 Workbench Titled Page Layout

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

### L-01.4 Toast Layout

#### Position

- Anchor：App Center，即 App 窗口中心，含 Sidebar 与顶栏
- 最新一条 Toast 的中心与 Anchor 重合；较早的依次向上堆叠，最新一条的位置不随数量变化
- Layer：Above Pages, Page Overlays, Command Panel and Dialogs

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

### L-02.1 Settings Window Layout

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

### L-02.2 Settings Sidebar Layout

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

### L-02.3 Settings Category Layout

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

### L-02.4 Settings Shortcuts Layout

#### Structure

1. Page Title
2. Group `Shortcuts`：Open Command Panel
3. Group `Playback` 及其功能
4. Group `Playback Overlay & Command Panel` 及其功能

#### Components

- Shortcut Field
- Icon Button / Dialog Close：Restore Default

#### Row

1. 功能名称
2. Restore Default：当前为默认键时不显示
3. Shortcut Field

#### Layout

- Restore Default 与 Shortcut Field 靠右，Restore Default 位于 Shortcut Field 左侧
- Validation Message 位于 Shortcut Field 下方，左侧与 Shortcut Field 对齐，较长时向功能名称一侧延伸；有提示时行随之变高，功能名称与 Shortcut Field 保持垂直居中对齐

#### Spacing

- Restore Default 与 Shortcut Field：`--spacing-1`

### L-02.5 Settings Subtitle Layout

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
### L-03.1 Recent Layout

#### Structure

1. Topbar Segmented Control：`Videos`、`Excerpt Lists`（左侧保留 Page Title `Recent`）
2. Recent Videos：Recent Watching Card Grid
3. Recent Excerpt Lists：Excerpt List Card Grid

#### Components

- Segmented Control
- Recent Watching Card Layout
- Excerpt List Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Segmented Control 位于顶栏内容区水平、垂直居中，卡片网格使用 `--padding-workbench-media-card-grid-inline`。
- 默认选项：Videos。选择在 App 运行期间保留，重新启动后回到默认。

#### Sizes

- Card Minimum Width：`--width-library-recent-card-min`
- Maximum Columns：有 Sidebar `--grid-max-columns-library-with-sidebar`；无 Sidebar `--grid-max-columns-library-without-sidebar`
- Grid Gap：`--gap-library-recent-grid`

### L-03.2 Recent Watching Card Layout

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

- Minimum Width：`--width-library-recent-card-min`
- Content Gap：`--spacing-2`

#### States

- Default
- Selected

## 3.4 Library and File

### L-04.1 Library Overview Layout

#### Structure

1. Action Bar
2. Adaptive Folder Card Grid

#### Components

- Status Indicator / Workbench Status Indicator
- Button / Neutral
- Menu
- Library Folder Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Action Bar 保持 `--spacing-8` 边距，文件夹网格使用 `--padding-workbench-media-card-grid-inline`。
- Action Bar：左侧展示文件夹数量（`xx folders`，样式同 Workbench Status Indicator），右侧展示排序按钮。
- 排序按钮：位于网格上方右上角，与未 Hover 时的封面图右边缘对齐；图标为 `funnel-simple`，文字为当前选中的排序方式。
- 排序菜单：Radio Menu，选项为默认排序、最晚入库、最早入库；打开时默认高亮首项。
- 排序规则：默认按文件夹名称升序；最晚入库/最早入库按首次入库时间（最早被索引文件的时间）排序，相同时间按文件夹名称升序。排序选择持久化保存。

#### Sizes

- Action Bar to Grid Gap：`--spacing-4`
- Card Minimum Width：`--width-library-recent-card-min`
- Maximum Columns：有 Sidebar `--grid-max-columns-library-with-sidebar`；无 Sidebar `--grid-max-columns-library-without-sidebar`
- Grid Gap：`--gap-library-recent-grid`

### L-04.2 Library Folder Card Layout

#### Structure

1. Cover Region
2. Folder Name

#### Components

- Media Card
- Cover
- Information Badge / Cover Badge

#### Sizes

- Minimum Width：`--width-library-recent-card-min`
- Minimum Height：`--min-height-library-folder-card`
- Content Gap：`--spacing-2`

#### States

- Default
- Disabled

### L-04.3 Library Folder Detail Layout

#### Structure

1. Cover Summary
2. Episode Grid

#### Components

- Cover Summary / Library Variant
- Library Episode Grid Layout

#### Layout

- Content Page Padding Inline 与 Excerpt List Detail 相同。
- Cover Summary 使用 `--spacing-8` 边距，Episode Grid 使用 `--padding-workbench-media-card-grid-inline`，使未 Hover 时的剧集封面图与 Cover Summary 水平边界齐平。
- Cover Summary 宽度跟随页面可用宽度变化，并在 Split Form 与 Backdrop Form 之间切换。

#### Spacing

- Content Page Padding Inline：`--spacing-8`
- Content Page Padding Top：`--spacing-1`
- Content Page Padding Bottom：`--spacing-6`
- Cover Summary to Episode Grid Gap：`--spacing-6`

#### Scrolling

- Vertical Scroll Context：Single Page Viewport
- Cover Summary：Scrollable
- Episode Grid：Scrollable
- Vertical Scrollbar：Page Viewport Trailing Edge

#### States

- Unknown：文件夹已不在索引中，页面正文为 Empty State / Empty Hint，文案 `This page no longer exists.`

### L-04.4 Library Episode Grid Layout

#### Structure

1. Recent Watching Card Grid

#### Components

- Recent Watching Card Layout

#### Sizes

- Card Minimum Width：`--width-library-recent-card-min`
- Maximum Columns：有 Sidebar `--grid-max-columns-library-with-sidebar`；无 Sidebar `--grid-max-columns-library-without-sidebar`
- Grid Gap：`--gap-library-recent-grid`

### L-04.5 File Page Layout

#### Structure

1. Level 1: Root Folder Card List
   1. Status and Action Row：Status Indicator、Action Buttons（`Add Folder`、`Index Now`）
   2. All Folder(s) Header & Root Folder Card List（按数量显示 `All Folder` 或 `All Folders`，统一展示全部根目录卡片）
2. Level 2: Subfolder & Direct File List
   1. Status and Action Row
   2. Breadcrumb Navigation：`All Folder(s)` > `[Indexed Path]`
   3. Subfolder Card List（存在子文件夹时）
   4. Episode File Groups（根目录存在直属文件时，排列在子文件夹下方）
3. Level 3: File Card List
   1. Status and Action Row
   2. Breadcrumb Navigation：`All Folder(s)` > `[Indexed Path]` > `[Folder]`
   3. Episode File Groups

#### Components

- Breadcrumb Navigation
- Status Indicator
- WorkbenchSpinner
- Button / Neutral
- Button / Destructive
- Empty State
- Dropdown Menu
- Confirmation Dialog
- File Card Layout
- Rename Dialog Layout
- WebDav Folder Dialog Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- 顶栏后退与前进按钮响应三级界面的下钻与返回，顶栏标题恒定为 `File`。
- Status and Action Row、列表标题、面包屑、单集 `Display Title` 与各级容器/卡片均左边缘对齐。
- Status and Action Row 在 Level 1、Level 2、Level 3 第一行常驻展示，高 36px（`--height-control`），两端对齐：左侧为极简状态指示器，右侧为操作按钮组。
- Level 1 统一展示全部根文件夹卡片，顶部标题为 `All Folder`（根目录数量为 1 时）或 `All Folders`（根目录数量大于 1 时），样式为 14px Semibold `--color-text-primary`。
- 面包屑节点（Level 2 与 Level 3 第二行）：以 `All Folder` / `All Folders` 为起点（点击返回 Level 1）；未激活链接项为 14px Medium `--color-text-secondary`（Hover 变为 `--color-text-primary`）；当前项为 14px Semibold `--color-text-primary`；分隔符为 `caret-right`（12px 1.15px `--color-text-muted`），间距 `--spacing-2`。
- Episode File Group（单集文件分组）：视频与字幕按单集 `Display Title` 分组展示；`Display Title` 位于所属灰底圆角容器正上方（14px Medium `--color-text-muted`）；下方容器背景 `--color-settings-group-bg`、边框 `--color-border-divider`（宽度 `--border-width-control`）、圆角 `--radius-settings-group`、内边距 `--spacing-4`，占满内容区宽度并包裹该集的视频与字幕卡片。
- 没有根目录时显示 Empty State；二级或三级无内容且非加载中时显示 Empty State。异步加载期间展示居中 `WorkbenchSpinner`（18px）。
- 移除根目录前弹出 Confirmation Dialog。
- 存在 Index、Add Folder、Remove Folder、Rename Folder 或 Rename Files 任务期间，以及数据库压缩进行中时，全部操作按钮为 Disabled。

#### Spacing

- Status and Action Row to Breadcrumb / Content：`--spacing-4`
- Breadcrumb to Content：`--spacing-3`
- Subfolders to Direct Episode Groups Gap：`--spacing-6`
- All Folder(s) Title to Card List：`--spacing-3`
- Episode Group Gap：`--spacing-4`
- Episode `Display Title` to Group Container：`--spacing-2`
- Action Row Gap：`--spacing-2`
- Card Gap：`--spacing-3`

#### Status Indicator

- 高度：`--height-control`（36px），垂直居中
- 排版规范：字号 14px，字重 500 Medium（`--font-weight-control`），Icon 与文本间距 `--spacing-2`
- 状态映射：
  - 已完成（Completed）：`check-circle`（18px 1.30px `--color-success-text`）+ `--color-success-text`（`Indexed [Folder]`、`Indexed All Folders`、`Removed [Folder]`）
  - 进行中（In Progress）：`WorkbenchSpinner`（18px `--color-text-secondary`）+ `--color-text-secondary`（`Indexing [Folder]`、`Indexing All Folders`、`Removing [Folder]`）
  - 失败（Failed）：`warning`（18px 1.30px `--color-danger-text`）+ `--color-danger-text`（`Index Failed: [Folder]`、`Removal Failed: [Folder]`）
  - 闲置（Idle）：`arrow-clockwise`（18px 1.30px `--color-text-secondary`）+ `--color-text-secondary`（`Last Updated: yy-MM-dd HH:mm` / `Last Updated: --`）。层级切换或重新进入时若无进行中操作则恢复闲置状态。

### L-04.6 File Card Layout

- Card Container：
  - Baseline Height：68px（标准双行文本时）
  - Padding：`--spacing-4`
  - Radius：`--radius-control`
  - Border Color：`--color-border-control`
  - Background：`--color-table-bg`
  - Hover Background：`--color-row-hover`
- Anatomy：Icon Container + `--spacing-4` + Text Column + Spacer + Trailing Actions
- Alignment：
  - 基准态（双行文本 36px）：图标底容器（36×36px）与文本列顶部对齐（距顶 16px）；右侧操作区（高 32px）垂直居中（上下各 18px，右边距 16px）
  - 多行展开态：文本折行撑开卡片时，左侧图标底容器（距顶 16px）与右侧操作区（距顶 18px）保持基准位置锁定，卡片向下延伸并保持底部 16px 边距
- Icon：
  - Container：36×36px，圆角 `--radius-control`，背景 `--color-bg-hover`
  - Glyph Size：`--size-card-icon-glyph`（20px），居中
  - Glyph Color：`--color-text-secondary`
  - Mapping：本地文件夹为 `folder`，WebDAV 文件夹为 `folder-webdav`，视频为 `video`，字幕为 `subtitles`
- Text Column：
  - Line 1：Title（`--font-size-body` / `--font-weight-control` / `--color-text-primary`）
  - Line 2：Subtitle（`--font-size-caption` / Regular / `--color-text-muted`；WebDAV 路径解码为可读字符展示）
  - Line Gap：`--spacing-1`
  - Wrapping：所有文本完整展示，字符折行，不截断
- Trailing Actions：
  - 文件夹卡片最右侧常驻不可点击的 `caret-right` 指示箭头（`--size-card-chevron` 16px，`--color-text-muted`），`dots-three` 按钮位于其左侧（间距 `--spacing-2`）；文件卡片无 `caret-right` 箭头，最右侧仅保留 `dots-three` 按钮。
  - `dots-three` 纯图标按钮（32×32px，圆角 8px，图标 21px）默认隐藏，仅在卡片 Hover 或该卡片菜单打开时显示；Hover 按钮自身及菜单打开时底色为 `--color-row-selected`。
  - `Add Folder` 弹出菜单：`Local Folder`（`folder`）+ `WebDav Folder`（`folder-webdav`）
  - 卡片弹出菜单（WebDAV 条目的 `Rename Folder` 与 `Rename Files` 为 Disabled）：
    - Root Folder Card：`Rename Folder`（Neutral）+ `Remove`（Destructive 警告项）
    - Subfolder Card：`Rename Folder`（Neutral）
    - Video / Subtitle File Card：`Get Info`（Neutral）+ `Rename Files`（Neutral）

## 3.5 Search and Excerpt

### L-05.1 Excerpt List Overview Layout

#### Structure

1. Summary Row
2. Adaptive Excerpt List Card Grid

#### Components

- Status Indicator / Workbench Status Indicator
- Button / Neutral
- Excerpt List Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Summary 行保持 `--spacing-8` 边距，卡片网格使用 `--padding-workbench-media-card-grid-inline`，使未 Hover 时的卡片封面分别与 Summary 文本（`xx lists  yy cues`，样式同 Workbench Status Indicator）和新建按钮（Neutral，带 `plus` 图标）齐平。

#### Ordering

- 按列表创建时间正序排列，最新创建的列表在最后

#### Sizes

- Summary to Grid Gap：`--spacing-4`
- Summary Height：`--height-control`
- Summary Item Gap：`--spacing-3`
- Card Minimum Width：`--width-library-recent-card-min`
- Maximum Columns：有 Sidebar `--grid-max-columns-library-with-sidebar`；无 Sidebar `--grid-max-columns-library-without-sidebar`
- Grid Gap：`--gap-library-recent-grid`

### L-05.2 Excerpt List Card Layout

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

- Minimum Width：`--width-library-recent-card-min`
- Content Gap：`--spacing-2`

#### Context Menu

1. `Edit List`
2. `Delete List`

只有一个 Excerpt List 时 `Delete List` 为 Disabled。

#### States

- Default
- Selected
- Disabled

### L-05.3 Excerpt List Detail Layout

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

- Default
- Empty List：列表无内容，正文展示 Empty Hint
- Unknown：列表已删除，页面正文为 Empty State / Empty Hint，文案 `This page no longer exists.`

### L-05.4 Search / Excerpt Toolbar Layout

#### Structure

1. Row 1：Search Field
2. Row 2：
   - Default：Result Count（Search 为 `xx results`，未输入搜索词时左侧留白不显示；Excerpt 为 `xx excerpts`）、Filter Trigger（带 18px 图标与 `Filter` / `筛选` 文本）
   - Select Mode：Selection Banner（文案 `已进入批量选择状态：点击任意行即可勾选，支持 Shift 连选`、按钮 `退出选择`，带 18px `sign-out` 图标）

#### Components

- Search Field
- Status Indicator / Workbench Status Indicator
- Button / Neutral
- Information Badge / Task Count Badge

#### Sizes

- Row Height：`--height-control`
- Row Gap：`--spacing-4`
- Bottom Gap：`--spacing-4`
- Width：Fill Parent Content Width

#### States

- Default：Row 1 启用；Row 2 展示 Result Count 与 Filter Trigger
- Select Mode：Row 1 禁用；Row 2 展示批量选择提示文案（样式同 Result Count）与「退出选择」按钮，无背景卡片与边框
- Filter Dialog Open
- Calculating

### L-05.5 Selection Action Overlay Layout

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

#### Layout

- 第 1 项在上，第 2 至 4 项在下；第 2 至 4 项宽度不足时换行

#### Spacing

- Group Gap：`--spacing-2`
- Action Gap：`--spacing-2`
- Line Gap：`--spacing-2`
- Padding Inline：`--spacing-3`
- Padding Block：`--spacing-2`

#### States

- Hidden：Select Mode 关闭
- Visible：Select Mode 开启

### L-05.6 Search / Excerpt Table Layout

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
- 空状态（无数据）时 Fixed Header 隐藏（高度为 0，不显示列名与分割线），正文展示 Empty Hint 并在剩余可视空白区域居中。

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
  - Alignment：Horizontal Center
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

- Empty Query：未输入搜索词，表头隐藏，正文居中展示 Empty Hint
- Calculating
- Results：有数据，正常展示表头与数据行
- Select Mode
- Empty Results：搜索或筛选结果为 0 条，表头隐藏，正文居中展示 Empty Hint

## 3.6 Dialogs

### L-06.1 Edit Cover Dialog Layout

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

### L-06.2 Excerpt List Editor Dialog Layout

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
- Description Field 的 Container 高度：Two Columns 时底边与 Cover 下方 Support Text 第 1 行底边对齐；One Column 沿用同一高度

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

### L-06.3 Rename Dialog Layout

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
- Form Region 为左 Label（宽度 `--width-form-label`）、右内容的双列水平布局；右侧内容与输入框的右缘与最右侧按钮的右缘对齐。
- Current Name 的 Label 与 Text Field 的 Label 相同，多行自然折行完整显示；Rename Folder 显示完整路径，Rename Files 显示视频与字幕去掉扩展名后的公共名。

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Label to Field Gap：`--spacing-3`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error

### L-06.4 WebDav Folder Dialog Layout

#### Structure

1. Header
   1. Title：`WebDav Folder`
   2. Close Button
2. Form Region
   1. Name Field
   2. Address Field
   3. Username Field
   4. Password Field（密文掩码）
3. Footer
   1. Cancel
   2. Add

#### Components

- Dialog
- Text Field
- WorkbenchSpinner
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-medium`
- Form Region 为左 Label（宽度 `--width-form-label`）、右输入框的双列水平布局；`Name` 选填并带占位提示（留空默认取地址末级目录名，根路径取 Host），`Address` 粘贴百分号编码链接时即时还原为可读字符，其余 3 项必填且无占位提示。
- 前 3 个输入框不预留底部报错行；最下方 `Password` 输入框下方预留 1 行 Validation Message（左边缘与密码输入框对齐），验证或连接失败在此处显示红字，对话框保持打开。

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Label to Field Gap：`--spacing-3`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error
- Validating（4 个输入框与 `Add` 按钮为 Disabled，`Add` 按钮内左侧展示 `WorkbenchSpinner`）

### L-06.5 Export to Anki Dialog Layout

#### Structure

1. Header
   1. Title：`Export to Anki`
   2. Close Button
2. Form Region
   1. Available Items：Label 与候选徽章池
   2. Card Layout：Label 与两列卡片放置区（`Front`、`Back`）
      1. Front：卡片标题与放置区
      2. Back：卡片标题与放置区
   3. File Name Field
   4. Location Field：Text Field 与 Icon Button / Default（`folder`）
3. Footer
   1. Cancel
   2. Export

#### Components

- Dialog
- Card / Settings Group Style
- Filter Chip（用于候选徽章）
- Text Field
- Icon Button / Default
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-large`
- Form Region 单列，占满内容宽度；超出窗口高度时中间表单区域垂直滚动，Header 与 Footer 固定。
- Available Items：固定高度（`--height-anki-export-available-pool`，96px），流式容纳候选徽章；全部移出时显示占位提示。
- Card Layout：包含 `Front` 与 `Back` 两列等宽卡片，内部放置区最小容纳 5 个徽章高度（`--min-height-anki-export-card-box`，208px），超过 5 个自适应撑开；为空时显示占位提示。
- 徽章交互：
  - Available Items、Front、Back 之间支持自由拖拽。
  - Front 与 Back 内的徽章带有 6 点拖拽手柄（`dots-six-vertical`）与删除按钮（`✕`）；上下拖拽显示高亮指示线，点击删除按钮移回 Available Items。
  - 移回 Available Items 的徽章按固定标准顺序归位。
- 导出排版（所见即所得）：卡片正面与背面内容严格按 Front、Back 区域内自上而下的视觉顺序渲染；未放入卡片的不导出。
- File Name 与 Location 为左 Label（宽度 `--width-form-label`）、右输入框的双列水平布局；Location 为单行 Text Field，两项下方均预留 1 行 Validation Message（左边缘与输入框对齐）；文件夹按钮在 Location 输入框右侧（间距 `--spacing-2`），字形墨迹右缘与内容右缘对齐。
- 默认：Front 放置 `Audio`，Back 放置 `Cue Text`，其余 5 项位于 Available Items；Location 为上次选择的文件夹。徽章布局与 Location 重新启动后保留，Search 与 Excerpt 共用；File Name 每次打开时重新生成。

#### Spacing

- Region Gap：`--spacing-4`
- Group Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Label to Content Gap：`--spacing-2`
- Label to Field Gap：`--spacing-3`
- Card Layout Column Gap：`--spacing-3`
- Badge Gap：`--spacing-2`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error
  - File Name 为空或非法时报错。
  - 点击 Export 时 Front 或 Back 为空时拦截导出，对应卡片边框变红（`--color-danger-text`）并在卡片内显示红色错误提示。

### L-06.6 Filter Dialog Layout

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

### L-06.7 Confirmation Dialog Layout

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

### L-06.8 File Detail Dialog Layout

#### Structure

1. Header
   1. Title：`File Info`
   2. Close Button
2. Content
   1. File Header Row：文件图标与文件名
   2. Property Groups：Settings 风格卡片组

#### Sizes

- Width：`--width-dialog-x-large`

#### Spacing

- Inset：`--inset-dialog`
- Region Gap：`--spacing-4`
- File Header Spacing：`--inset-dialog`

### L-06.9 Task Panel Layout

#### Structure

1. Header
   1. Title：`Task`
   2. Segmented Control：`Current`、`Completed`、`Incomplete`，水平居中
   3. Close Button
2. Task Card List

#### Components

- Dialog
- Segmented Control
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

### L-06.10 Task Card Layout

#### Structure / Current

1. Icon（Leading，36×36px 圆角底容器，内置 20px 图标）
2. Line 1: Title（动作前缀 + 目标名称，统一字重与字色，单行截断，无路径）
3. Line 2: Progress Text（In Progress 阶段文字 / 导出张数；Queued 状态与数量）
4. Line 3: Progress Bar（仅 In Progress，16px 高度容器居中展示 4px Capsule 进度条）

#### Structure / History

1. Icon（Leading，36×36px 圆角底容器，内置 20px 图标）
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

- Baseline Height：68px（标准双行文本时）
- Padding：`--spacing-4`
- Icon Container：36×36px，圆角 `--radius-control`，背景 `--color-bg-hover`
- Icon Glyph Size：`--size-card-icon-glyph`（20px），居中
- Icon Glyph Color：`--color-text-secondary`
- Icon to Content Gap：`--spacing-4`
- Row Gap：`--spacing-1`
- Dynamic Row Height：`16px`
- Radius：`--radius-control`
- Background：`--color-table-bg`
- Hover Background：`--color-row-hover`
- Border Color：`--color-border-control`
- Alignment：
  - 基准态：以两行文本（Title 1 行 + Line 2 1 行 = 36px）为设计基准，图标底容器（36×36px）与文本列顶部对齐（距顶 16px）；右侧操作按钮（32px）垂直居中（上下各 18px，右边距 16px）
  - 展开态：当出现第 3 行（进度条或错误信息）时，左侧图标底容器（距顶 16px）与右侧按钮（距顶 18px）保持基准位置锁定，卡片向下延伸并保持底部 16px 边距

#### Text

- Title Font Size：`--font-size-body`
- Title Font Weight：`--font-weight-control`
- Title Color：`--color-text-primary`
- Detail Font Size：`--font-size-caption`
- Detail Color：`--color-text-muted`
- Error Color：`--color-danger-text`

#### Trailing Actions

- 统一使用 `dots-three` 纯图标按钮（32×32px，圆角 8px，图标 21px），Hover 及菜单打开底色为 `--color-row-selected`
- 弹出菜单：
  - Current：`Remove Task`（Destructive 警告项，图标 `minus-circle`）
  - History（Completed / Incomplete）：`Delete Record`（Destructive 警告项，图标 `trash`）

#### States

- In Progress
- Queued
- Completed
- Incomplete
