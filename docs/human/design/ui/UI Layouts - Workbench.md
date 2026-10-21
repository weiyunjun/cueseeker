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
  - Docked：窗口宽度 ≥ `--min-width-workbench-page-content` + `--width-app-sidebar` 时与页面并排布局。
  - Overlay：窗口宽度 < `--min-width-workbench-page-content` + `--width-app-sidebar` 时全高浮于顶栏与页面之上（右侧 1px `--color-border-muted` 分隔线，阴影 `--shadow-popover`），以 `--duration-sidebar-motion` 透明度淡入淡出；指针向右移出 Sidebar 宽度范围或点击 Sidebar Toggle 时收起。
- Collapsed
  - Auto Collapse：窗口宽度 < `--min-width-workbench-page-content` + `--width-app-sidebar` 时自动收起，收起后不自动展开。只在 Workbench 可见时判定，从播放页返回时判定一次。

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

#### Sizes

- Page Content Minimum Width：`--min-width-workbench-page-content`

#### Spacing

- Page Padding Inline：`--spacing-8`
- Page Scrollbar Channel：`--width-page-scrollbar-channel`，位于 Trailing Padding 之外并恒定预留
- Page Padding Top：`--spacing-1`
- Page Padding Bottom：`--spacing-6`

#### Scrolling

- Vertical Scrollbar：Page Viewport Trailing Edge

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
   3. Card：背景 `--color-table-bg`；边框 `--color-border-control`，宽度 `--border-width-control`；圆角 `--radius-settings-group`；宽度跟随窗口，不设上限

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
5. Group `Collage` 及其功能

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
3. Group `Position`：Horizontal、Margin X、Vertical、Margin Y
4. Group `Border`：Type（Outline / Background Box）、Outline Color、Outline Width、Background Color、Background Opacity、Blur
5. Group `Shadow`：Shadow Color、Shadow Opacity、Shadow Offset
6. Restore Defaults

#### Components

- Number Field：Size、Letter Spacing、Line Spacing、Margin X、Margin Y、Outline Width、Background Opacity、Blur、Shadow Opacity、Shadow Offset
- Checkbox / Form Checkbox：Bold、Italic
- Color Well：Color、Outline Color、Background Color、Shadow Color
- Segmented Control：Type、Horizontal、Vertical
- Menu / Dropdown Menu：Font（顶部含 Search Field，打开及搜索词变化时默认高亮首项，无匹配项时显示 `No Results`）
- Button / Neutral：Restore Defaults

#### Row

1. 设置项名称
2. 控件；Font 为宽度 `--width-settings-popup` 的下拉触发器，点击展开宽度 `--width-settings-font-menu`、最大高度 `--max-height-settings-font-menu` 的字体搜索菜单

#### Layout

- Number Field 与 Color Well 宽度：`--width-settings-number-field`
- Group `Border` 按当前 Type 动态显隐行：Outline 时显示 Type、Outline Color、Outline Width、Blur；Background Box 时显示 Type、Background Color、Background Opacity、Blur
- Restore Defaults：位于最后一个 Card 下方，靠右；Leading Icon `arrow-counter-clockwise`；全部为默认值时 Disabled

#### Spacing

- Font 名称与 Choose…：`--spacing-3`
- Bold 与 Italic：`--spacing-6`
- 最后一个 Card 与 Restore Defaults：`--spacing-6`

## 3.3 Recent
### L-03.1 Recent Layout

#### Structure

1. Topbar Tabs：`Videos`、`Excerpt Lists`（左侧保留 Page Title `Recent`）
2. Recent Videos：Recent Watching Card Grid
3. Recent Excerpt Lists：Excerpt List Card Grid

#### Components

- Tabs
- Tab
- Section Title
- Recent Watching Card Layout
- Excerpt List Card Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- Tabs 默认在顶栏水平、垂直居中；空间不足时保持与左、右内容至少 `--spacing-3` 间距并向空余一侧偏移，两侧间距均达 `--spacing-3` 后截断左侧标题。卡片网格使用 `--padding-workbench-media-card-grid-inline`。
- 默认选项：Videos。选择在 App 运行期间保留，重新启动后回到默认。
- 按本地自然日凌晨 `00:00` 划分为 `Last 7 Days`、`Last 30 Days`、`Earlier`、`Never Played` 四个分组，仅展示非空分组；分组标题左边缘与未 Hover 时的卡片封面左边缘齐平。
- `Never Played`：Videos 收录无播放记录的文件夹（默认展示 `EP01`，按文件夹名称升序）；Excerpt Lists 收录未播放过的有效摘录集（按创建时间正序，打开时从第 1 条有效字幕播放）。

#### Sizes

- Section Gap：`--spacing-3`
- Section Title to Grid Gap：`--spacing-3`
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
- Action Bar：左对齐，从左到右依次为排序按钮（图标为 `funnel-simple`，文字为当前选中的排序方式）、文件夹数量（`xx folders`，样式同 Workbench Status Indicator）。
- 排序菜单：Radio Menu，与排序按钮左边缘对齐，选项为默认排序、最晚入库、最早入库；打开时默认高亮首项。
- 排序规则：默认按文件夹名称升序；最晚入库/最早入库按首次入库时间（最早被索引文件的时间）排序，相同时间按文件夹名称升序。排序选择持久化保存。

#### Sizes

- Action Bar to Grid Gap：`--spacing-4`
- Action Bar Item Gap：`--spacing-3`
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

- Cover Summary
- Library Episode Grid Layout

#### Layout

- Content Page Padding Inline 与 Excerpt List Detail 相同。
- Cover Summary 使用 `--spacing-8` 边距，Episode Grid 使用 `--padding-workbench-media-card-grid-inline`，使未 Hover 时的剧集封面图与 Cover Summary 水平边界齐平。
- Cover Summary 宽度跟随页面可用宽度变化，并在 Split Form 与 Backdrop Form 之间切换。
- Cover Summary 内容：
  - Supporting Content 第 1 行为视频与字幕数量（`xx videos  yy subtitles`，中间以 2 个英文空格分隔），第 2 行为文件夹路径。
  - Progress Label（仅 Resume 态显示）：`EPxx  mm:ss / mm:ss`（集数与时间戳之间以 2 个英文空格分隔，不显示百分比）。
  - Action Row：`Resume` / `Play`、`View in File`（图标 `folder`，点击跳转至 File 对应目录视图；若文件夹已不在媒体库中则拦截并弹出 Toast）、`More`（图标 `dots-three`，弹出菜单内容与 Library 一级界面文件夹卡片右键菜单一致）。

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
   1. Status and Action Row：Action Buttons（`Add Folder`、`Index All`）、Status Indicator
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
- Spinner
- Button / Neutral
- Button / Destructive
- Empty State
- Dropdown Menu
- Confirmation Dialog
- File Card Layout
- Rename Dialog Layout
- WebDav / SMB / FTP / NFS Folder Dialog Layout

#### Layout

- Page Layout：Workbench Titled Page Layout
- 顶栏后退与前进按钮响应三级界面的下钻与返回，顶栏标题恒定为 `File`。
- Status and Action Row、列表标题、面包屑、单集 `Display Title` 与各级容器/卡片均左边缘对齐。
- Status and Action Row 在 Level 1、Level 2、Level 3 第一行常驻展示，高 36px（`--height-control`），左对齐：从左到右依次为 `Add Folder` 按钮、`Index All` 按钮、状态指示器。
- 所有层级的第一行（Status and Action Row）与第二行（Level 1 的 `All Folder(s)` 标题行、Level 2 与 Level 3 的面包屑行）在顶部固定冻结，纵向滚动时仅下方列表区域滚动。
- Level 1 统一展示全部根文件夹卡片，顶部标题为 `All Folder`（根目录数量为 1 时）或 `All Folders`（根目录数量大于 1 时），样式为 14px Semibold `--color-text-primary`。
- 面包屑节点（Level 2 与 Level 3 第二行）：以 `All Folder` / `All Folders` 为起点（点击返回 Level 1）；未激活链接项为 14px Medium `--color-text-secondary`（Hover 变为 `--color-text-primary`）；当前项为 14px Semibold `--color-text-primary`；分隔符为 `caret-right`（12px 1.15px `--color-text-muted`），间距 `--spacing-2`。
- Episode File Group（单集文件分组）：视频与字幕按单集 `Display Title` 合一展示为单张圆角卡片容器（背景 `--color-table-bg`、边框 `--color-border-control`、宽度 `--border-width-control`、圆角 `--radius-settings-group`、内边距 `0`，占满内容区宽度并裁剪圆角）。卡片顶部为标题栏（最小高度 `--height-control`，水平内边距 `--spacing-4`，背景 `--color-file-group-header-bg`），左对齐展示 `Display Title`（14px Medium `--color-text-muted`）；标题栏底部及下方各文件行之间均以与卡片容器等宽的 `--color-border-divider`（宽度 `--border-width-control`）分隔。
- 没有根目录时显示 Empty State；二级或三级无内容且非加载中时显示 Empty State。异步加载期间展示居中 `Spinner`。
- 移除根目录前弹出 Confirmation Dialog。
- 存在 Index、Add Folder、Remove Folder、Rename Folder 或 Rename Files 任务期间，以及数据库压缩进行中时，全部操作按钮为 Disabled。

#### Spacing

- Status and Action Row to Breadcrumb / Content：`--spacing-4`
- Breadcrumb to Content：`--spacing-3`
- Subfolders to Direct Episode Groups Gap：`--spacing-6`
- All Folder(s) Title to Card List：`--spacing-3`
- Episode Group Gap：`--spacing-4`
- Episode Header Bar Padding Inline：`--spacing-4`
- Action Row Gap：`--spacing-3`
- Card Gap：`--spacing-3`（仅用于独立文件夹卡片之间；单集容器内部文件行紧贴排列，以 1px 等宽分割线分隔）

#### Status Indicator

- 高度：`--height-control`（36px），垂直居中
- 排版规范：字号 14px，字重 500 Medium（`--font-weight-control`），Icon 与文本间距 `--spacing-2`
- 状态映射：
  - 已完成（Completed）：`check-circle`（18px 1.30px `--color-success-text`）+ `--color-success-text`（`Indexed [Folder]`、`Indexed All Folders`、`Removed [Folder]`）
  - 进行中（In Progress）：`Spinner` + `--color-text-secondary`（`Indexing [Folder]`、`Indexing All Folders`、`Removing [Folder]`）
  - 失败（Failed）：`warning`（18px 1.30px `--color-danger-text`）+ `--color-danger-text`（`Index Failed: [Folder]`、`Removal Failed: [Folder]`）
  - 闲置（Idle）：`arrow-clockwise`（18px 1.30px `--color-text-secondary`）+ `--color-text-secondary`（`Last Updated: yy-MM-dd HH:mm` / `Last Updated: --`）。层级切换或重新进入时若无进行中操作则恢复闲置状态。

### L-04.6 File Card Layout

- Card Container：
  - Baseline Height：68px（标准双行文本时）
  - Padding：`--spacing-4`
  - Standalone Folder Card：圆角 `--radius-control`，边框 `--color-border-control`，默认背景 `--color-table-bg`，Hover 背景 `--color-row-hover`，Pressed 背景 `--color-file-folder-card-bg-pressed`
  - Episode Group File Row（单集容器内视频/字幕行）：无独立外边框与圆角，默认背景透明（透出外层单集卡片 `--color-table-bg`），Hover 背景 `--color-row-hover`（无 Pressed 态）
- Anatomy：Icon Container + `--spacing-4` + Text Column + Spacer + Trailing Actions
- Alignment：
  - 基准态（双行文本 36px）：图标底容器（36×36px）与文本列顶部对齐（距顶 16px）；右侧操作区（高 32px）垂直居中（上下各 18px，右边距 16px）
  - 多行展开态：文本折行撑开卡片时，左侧图标底容器（距顶 16px）与右侧操作区（距顶 18px）保持基准位置锁定，卡片向下延伸并保持底部 16px 边距
- Icon：
  - Container：36×36px，圆角 `--radius-control`，背景 `--color-bg-hover`
  - Glyph Size：`--size-card-icon-glyph`（20px），居中
  - Glyph Color：`--color-text-secondary`
  - Mapping：本地文件夹为 `folder`，WebDAV 文件夹为 `folder-webdav`，SMB 文件夹为 `folder-smb`，FTP 文件夹为 `folder-ftp`，NFS 文件夹为 `folder-nfs`，视频为 `video`，字幕为 `subtitles`
- Text Column：
  - Line 1：Title（`--font-size-body` / `--font-weight-control` / `--color-text-primary`）
  - Line 2：Subtitle（`--font-size-caption` / Regular / `--color-text-muted`；WebDAV、SMB、FTP 与 NFS 路径解码为可读字符展示）
  - Line Gap：`--spacing-1`
  - Wrapping：所有文本完整展示，字符折行，不截断
- Trailing Actions：
  - 文件夹卡片最右侧常驻不可点击的 `caret-right` 指示箭头（`--size-card-chevron` 16px，`--color-text-muted`），`dots-three` 按钮位于其左侧（间距 `--spacing-2`）；文件卡片无 `caret-right` 箭头，最右侧仅保留 `dots-three` 按钮。
  - `dots-three` 纯图标按钮（32×32px，圆角 8px，图标 21px）默认隐藏，仅在卡片 Hover 或该卡片菜单打开时显示；Hover 按钮自身及菜单打开时底色为 `--color-row-selected`，Pressed 底色为 `--color-row-action-bg-pressed`（按住该按钮时卡片自身维持 Hover 背景色）。
  - `Add Folder` 弹出菜单：`Local Folder`（`folder`）+ `WebDav Folder`（`folder-webdav`）+ `SMB Folder`（`folder-smb`）+ `FTP Folder`（`folder-ftp`）+ `NFS Folder`（`folder-nfs`）
  - 卡片弹出菜单：
    - Root Folder Card：`Rename This Folder`（Neutral）+ `Index This Folder`（Neutral）+ `Remove This Folder`（Destructive 警告项）
    - Subfolder Card：`Rename This Folder`（Neutral）
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
- Summary 行保持 `--spacing-8` 边距，左对齐，从左到右依次为新建按钮（Neutral，带 `plus` 图标）、Summary 文本（`xx lists  yy cues`，样式同 Workbench Status Indicator，其中 `yy cues` 与卡片封面徽章仅统计有效字幕）；卡片网格使用 `--padding-workbench-media-card-grid-inline`，使未 Hover 时的卡片封面左边缘与新建按钮左边缘齐平。

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
- Cover Summary 内容：
  - Supporting Content 第 1 行为摘录列表描述（未填写时显示占位文案 `No description`），第 2 行为有效台词总数量与创建时间（`xx excerpts  Created yyyy-MM-dd`，中间以 2 个英文空格分隔）。
  - Progress Label（仅 Resume 态显示）：`#x / y  台词内容`（`y` 为有效台词数，序号与台词内容之间以 2 个英文空格分隔，超出单行或遇换行均在末尾以 `...` 截断）。
  - Action Row：`Resume` / `Play`、`More`（图标 `dots-three`，弹出菜单内容与 Excerpt 一级界面卡片右键菜单一致，含 `Edit List` 与 `Delete List`；确认删除当前列表后自动退回 Excerpt 一级界面）。

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

1. Row 1：从左到右依次为 Search Field（自适应撑满整行剩余宽度）、Filter Trigger（带 18px 图标与 `Filter` / `筛选` 文本）、Sort Trigger（图标为 `funnel-simple`，文字为当前选中的排序方式；点击展开与按钮左边缘对齐的 Radio Menu，打开时默认高亮首项）
2. Row 2（左对齐）：
   - Default：Result Count（Search 为 `xx results`，未输入搜索词时不显示；Excerpt 为 `xx excerpts`，仅统计有效台词）
   - Select Mode：从左到右依次为 `退出选择` 按钮（带 18px `sign-out` 图标）、Selection Banner 文案（`已进入批量选择状态：点击任意行即可勾选，支持 Shift 连选`）

#### Components

- Search Field
- Status Indicator / Workbench Status Indicator
- Button / Neutral
- Menu
- Information Badge / Task Count Badge

#### Sizes

- Row Height：`--height-control`
- Row Gap：`--spacing-4`
- Item Gap：`--spacing-3`
- Bottom Gap：`--spacing-4`
- Width：Fill Parent Content Width

#### States

- Default：Row 1 启用，Row 2 左对齐展示 Result Count
- Select Mode：Row 1 保持原位并全部禁用（Search Field、Filter Trigger、Sort Trigger 均为 Disabled），Row 2 左对齐展示「退出选择」按钮与批量选择提示文案（样式同 Result Count，无背景卡片与边框）
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

- Search：支持默认排序（按 Display Title、字幕路径、Cue 时间升序）、字符数最多、字符数最少；相同条件下按默认排序兜底，首屏与搜索完成后的顺序一致，搜索进行中切换排序立即重新搜索。排序选择持久化保存，并与 Command Panel 搜索结果保持一致
- Excerpt：支持添加日期最早（默认）、添加日期最晚、字符数最多、字符数最少；相同条件下按添加日期最早兜底。各 Excerpt List 的搜索词、筛选与排序相互独立（筛选与排序持久化保存，搜索词重启后清空）

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
- Current Name 的 Label 与 Text Field 的 Label 相同，多行自然折行完整显示；Rename Folder 显示当前文件夹名称，Rename Files 显示视频与字幕去掉扩展名后的公共名。

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Label to Field Gap：`--spacing-3`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error

### L-06.4 WebDav / SMB / FTP / NFS Folder Dialog Layout

#### Structure

1. Step 1: Connection
   1. Header：`WebDav Folder`、`SMB Folder`、`FTP Folder` 或 `NFS Folder` + Close Button
   2. Form Region：
      - `WebDav Folder`：`Address Field`、`Username Field`、`Password Field`（密文掩码）
      - `SMB Folder`：`Address Field`、`Port Field`（默认预填 `445`）、`Username Field`、`Password Field`（密文掩码）
      - `FTP Folder`：`Address Field`、`Port Field`（默认预填 `21`）、`Username Field`、`Password Field`（密文掩码）
      - `NFS Folder`：`Address Field`
   3. Footer：`Cancel`、`Connect`
2. Step 2: Folder Browser
   1. Header：`WebDav Folder`、`SMB Folder`、`FTP Folder` 或 `NFS Folder` + Close Button
   2. Breadcrumb Navigation
   3. Browser Card List
   4. Footer：左侧 `Back`；右侧 `Cancel`、`Add`

#### Components

- Dialog
- Text Field
- Breadcrumb Navigation
- Spinner
- Empty State / Empty Hint
- Scrollbar / Vertical
- Button / Neutral
- Button / Primary

#### Layout

- Step 1 Width：`--width-dialog-medium`；Form Region 为左 Label（宽度 `--width-form-label`）、右输入框的双列水平布局；`Address` 必填（粘贴百分号编码链接时即时还原为可读字符；`SMB Folder`、`FTP Folder` 与 `NFS Folder` 未带对应协议前缀时点击 `Connect` 自动补全 `smb://`、`ftp://` 或 `nfs://` 解析，不修改输入框内容；`NFS Folder` 支持斜杠路径或 `主机:/导出路径` 写法并由后台自动连接标准 `2049` 端口），`SMB Folder` 与 `FTP Folder` 的 `Port` 必填且分别默认预填 `445` 与 `21`，`Username` 与 `Password` 选填（留空以匿名/访客方式访问），均无占位提示；仅最下方输入框下预留 1 行 Validation Message（左边缘与输入框对齐），成功加载初始目录列表前的任何报错均停留在 Step 1 显示红字。
- Step 2 Width：`--width-dialog-x-large`，Height：`--height-task-panel`；Header、Breadcrumb 与 Footer 固定，中间列表垂直滚动，滚动条位于右侧 `--inset-dialog` 通道内。
- Breadcrumb Navigation：以 Step 1 所填地址对应的目录名称或主机名称为起点（不展示或回退至更上层父目录）。
- Browser Card List：仅展示文件夹（或 SMB 顶层共享文件夹、NFS 顶层导出目录）、受支持的视频与字幕文件（文件夹在上、文件在下，按名称排序）。卡片复用 `L-04.6 File Card Layout` 单行形态（高度 `68px`、内边距 `--spacing-4`、图标底容器 `36×36px`、标题 `--font-size-body` Medium 单行尾部截断；文件夹右侧带 `16px` `caret-right` 箭头，文件无箭头与操作按钮）。
- 交互与选中态：文件卡片不可点击且无 Hover 效果；文件夹卡片支持同层级单击多选与双击进入子目录。未选中文件夹 Hover 背景为 `--color-row-hover`；选中文件夹背景为 `--color-library-media-card-hover-bg`、边框为 `--color-border-active`，且选中后无 Hover 效果。双击进入子目录、点击面包屑跳转或点击 `Back` 返回 Step 1 时清空当前选中项；`Back` 返回 Step 1 时保留已输入的表单内容，仅关闭弹窗时清空。

#### Spacing

- Region Gap：`--spacing-4`
- Field Gap / Card Gap：`--spacing-3`
- Label to Field Gap：`--spacing-3`
- Footer Action Gap：`--spacing-2`

#### States

- Step 1 - Default
- Step 1 - Validation Error
- Step 1 - Connecting（全部输入框与 `Connect` 按钮为 Disabled，`Connect` 按钮内左侧展示 `Spinner`）
- Step 2 - Loaded（`Add` 启用；未选中子文件夹时添加当前目录自身，选中一个或多个子文件夹时按从上到下顺序依次入队添加；当 `SMB Folder` 处于主机顶层共享文件夹列表、或 `NFS Folder` 处于主机顶层导出目录列表且未选中任何文件夹时，`Add` 为 Disabled）
- Step 2 - Loading Subfolder（列表区居中展示 `Spinner`，`Add` 为 Disabled）
- Step 2 - Load Failed / Empty（列表区居中展示 `Empty Hint`，加载失败时 `Add` 为 Disabled）

### L-06.5 Export to Anki Dialog Layout

#### Structure

1. Header
   1. Title：`Export to Anki`
   2. Close Button
2. Form Region
   1. Card Columns（`Front`、`Back` 并列两列）
      1. Front：标题行（`Front` 标题与右侧紧邻的 `+` 添加按钮）与下方白色卡片放置区
      2. Back：标题行（`Back` 标题与右侧紧邻的 `+` 添加按钮）与下方白色卡片放置区
   2. File Name Field
   3. Location Field：Text Field 与 Icon Button / Default（`folder`）
3. Footer
   1. Cancel
   2. Export

#### Components

- Dialog
- Dropdown Menu
- Text Field
- Icon Button
- Button / Neutral
- Button / Primary

#### Layout

- Width：`--width-dialog-large`
- Form Region 单列，占满内容宽度；超出窗口高度时中间表单区域垂直滚动，Header 与 Footer 固定。
- Card Columns：包含 `Front` 与 `Back` 两列等宽卡片列（间距 `--spacing-3`）：
  - 顶部标题行：`Front` / `Back` 标题（`--font-size-body`，字重 `600`，左内边距 `--spacing-2` 与卡片内数据对象左边缘对齐），右侧紧邻 `+` 按钮（间距 `--spacing-1`，容器 `--size-anki-export-add-button: 24px`，图标 `--size-anki-export-add-icon: 16px`）。
  - 下方白色卡片容器：固定高度 `--height-anki-export-card-box`（`288px`，固定容纳全部 7 个数据对象），背景 `--color-bg-control`，边框 `--color-border-control`，圆角 `--radius-control`，内边距 `--spacing-2`；为空时不显示占位提示。
- 数据对象添加、删除与拖拽交互：
  - 同一面（`Front` 或 `Back`）内不重复添加同一数据对象；不同面之间可独立添加同一数据对象。
  - 当该面剩余未添加项 $\ge 2$ 个时，点击 `+` 在按钮正下方左对齐弹出 `Dropdown Menu`，按固定标准顺序展示剩余未添加项，点击后追加至该面末尾；当仅剩 1 个未添加项时，点击 `+` 不弹出菜单，直接将该项追加至末尾；当 7 个数据对象全部添加后，`+` 按钮变为 `Disabled`。
  - 数据对象高度 `--height-filter-chip`（`32px`），左侧为 6 点拖拽手柄（`dots-six-vertical`，`--size-anki-export-drag-handle: 12px`），右侧为删除按钮（`✕`，容器 `--size-anki-export-badge-remove-button: 14px`，图标 `--size-anki-export-badge-remove-icon: 12px`，圆角 `--radius-anki-export-badge-remove-button: 3px`，Hover 时显示 `--color-bg-hover` 背景，Pressed 时显示 `--color-bg-pressed` 背景，图标颜色保持 `--color-text-muted` 不变）。
  - 数据对象仅在所属白色卡片内部沿垂直方向（一维）上下拖拽排序；拖拽中数据对象本体呈半透明（`--opacity-anki-export-dragging: 0.5`）跟随移动，越过相邻项时实时换位。
- 导出排版（所见即所得）：卡片正面与背面内容严格按 Front、Back 区域内自上而下的视觉顺序渲染；未放入卡片的不导出。
- File Name 与 Location 为左 Label（宽度 `--width-form-label`）、右输入框的双列水平布局；Location 为单行 Text Field，两项下方均预留 1 行 Validation Message（左边缘与输入框对齐）；文件夹按钮在 Location 输入框右侧（间距 `--spacing-2`），字形墨迹右缘与内容右缘对齐。
- 默认：Front 放置 `Audio`，Back 放置 `Cue Text`；Location 为上次选择的文件夹。卡片布局与 Location 重新启动后保留，Search 与 Excerpt 共用；File Name 每次打开时重新生成。

#### Spacing

- Region Gap：`--spacing-4`
- Group Gap：`--spacing-4`
- Field Gap：`--spacing-3`
- Label to Content Gap：`--spacing-2`
- Side Title to Add Button Gap：`--spacing-1`
- Label to Field Gap：`--spacing-3`
- Card Layout Column Gap：`--spacing-3`
- Badge Gap：`--spacing-2`
- Footer Action Gap：`--spacing-2`

#### States

- Default
- Validation Error
  - File Name 或 Location 为空或非法时报错。
  - 点击 Export 时若 Front 或 Back 为空则拦截导出，对应白色卡片边框变红（`--color-danger-text`）并在卡片内居中显示红色错误提示；添加任意数据对象后错误状态自动清除。

### L-06.6 Filter Dialog Layout

#### Structure

1. Header
   1. Title：`Filter`
   2. Close Button
2. Sections：Duration、Character、Language、Watch Status、Folder，从上到下
   1. Section Header：图标、名称与选中数量
   2. Filter Chip：每个选项一个（Excerpt 下各选项计数仅统计有效台词）
3. Footer
   1. Reset
   2. Cancel
   3. Show：Search 为 `Show N results`，Excerpt 为 `Show N excerpts`（仅统计有效台词）；总数未知时为 Spinner 与 `Calculating`

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
- Character 的 Filter Chip：字幕去除首尾空白后按字符宽度统计（全角与东亚宽字符计 2，其余字符计 1）
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
   2. Tabs：`Current`、`Completed`、`Incomplete`，默认水平居中（间距与避让截断规则同 Recent 顶栏）
   3. Close Button
2. Task Card List

#### Components

- Dialog
- Tabs
- Tab
- Icon Button / Dialog Close
- Scrollbar / Vertical

#### Sizes

- Width：`--width-dialog-x-large`
- Height：`--height-task-panel`

#### Ordering

- Current：按发起时间正序（FIFO）排列，正在执行的在最上方
- Completed / Incomplete：按进入该状态的时间倒序（LIFO）排列，最新的在最上方

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

- 统一使用 `dots-three` 纯图标按钮（32×32px，圆角 8px，图标 21px），Hover 及菜单打开底色为 `--color-row-selected`，Pressed 底色为 `--color-row-action-bg-pressed`
- 弹出菜单：
  - Current：`Remove Task`（Destructive 警告项，图标 `minus-circle`）
  - History（Completed / Incomplete）：`Delete Record`（Destructive 警告项，图标 `trash`）

#### States

- In Progress
- Queued
- Completed
- Incomplete
