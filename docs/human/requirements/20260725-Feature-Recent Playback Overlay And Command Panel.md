# 版本
main

# 需求描述

## 1. 目标

本需求统一 Workbench Recent、Playback Overlay、Command Panel 与播放恢复行为，使用户可以：

- 从 Workbench 快速访问最近播放的视频和最近使用的 Shiori List；
- 在播放过程中查看当前字幕或当前播放来源的 Playlist；
- 通过 Command Panel 快速搜索字幕、恢复 Recent Videos 或 Recent Shioris；
- 在多层播放界面之间切换时保持正确的暂停与恢复状态。

具体视觉规则以本需求单中的 `UI.md` 改动为准。

## 2. 最小实现原则

本需求必须遵循以下实现约束：

- 优先复用现有数据来源、搜索逻辑、播放队列、Cue Reel、快捷键、视频卡片、Library 条目和 Shiori 条目。
- 不为本需求建立平行的数据模型、状态源、导航系统或重复组件。
- 不增加未被当前需求使用的抽象、配置项、扩展点或兼容层。
- 不重构与本需求无关的现有代码。
- 新增代码只解决已确认行为；发现必须扩大范围时，应先停止实现并说明原因。
- Command Panel 只预览首屏结果，不为其引入重度表格或虚拟化滚动实现。
- 封面加载不得随选择切换持续累积资源，也不得显示已经过期的异步加载结果。
- Current 的当前视频封面在视频未变化时保持复用，不随 Cue 导航重复渲染。
- Playlist 或 Command Panel 的上下文封面发生变化时，只保留当前需要显示的封面资源。

## 3. Workbench 左侧导航

Workbench 左侧保持四个一级入口：

1. Search
2. Recent
3. Library
4. Shiori

导航规则：

- Recent 展开后固定显示 Recent Videos 和 Recent Shioris。
- Shiori 展开后显示当前存在的 Shiori Lists。
- Shiori Lists 超出可用高度时，二级区域允许纵向滚动。
- Search 和 Library 不增加二级导航。
- 左侧导航不显示封面、字幕、播放进度或 Resume 卡片等富信息。
- 一级入口负责页面导航；展开箭头只负责展开或收起二级入口。

## 4. Workbench Recent

Recent 一级页面包括两个分区：

1. Recent Videos
2. Recent Shioris

每个分区标题显示：

- 分区名称；
- 对应完整二级页面的总数；
- 进入完整二级页面的箭头。

总数表示完整数据总数，不表示一级页面当前展示的预览数量。

### 4.1 Recent Videos

- 一级页面继续复用现有 Recent Videos 视频卡片。
- 完整二级页面继续复用现有卡片布局和现有数据。
- 保留观看进度、播放时间、Episode、Watch Status Badge、右键菜单和打开所在文件夹等现有能力。
- Episode 与 Watch Status Badge 位于同一行。
- 首版不增加新的搜索、筛选、排序或批量操作。

### 4.2 Recent Shioris

- 一级页面每行显示一个 Recent Shiori。
- 条目包含 Shiori List 封面、名称、描述、Resume 位置和最近播放字幕。
- 完整二级页面复用相同条目并显示全部 Recent Shioris。
- 首版不增加搜索、筛选、排序、管理或批量操作。

## 5. Recent Videos 数据规则

本需求不改变 Recent Videos 现有的数据来源、写入时机和排序规则：

- 只记录通过视频浏览入口实际开始播放过的视频。
- 保留 Library、Workbench Recent Videos 和播放内视频入口等现有写入来源。
- 从 Search Result、Shiori List 或 URL Scheme 启动播放时，不写入 Recent Videos。
- 不预先写入全库视频或只浏览但未播放的视频。

## 6. Playback Overlay

Playback Overlay 只保留两个视图：

1. Current
2. Playlist

交互规则：

- Playback Page 中按 `Enter` 打开 Playback Overlay。
- Overlay 打开后默认进入 Current。
- 顶部居中显示 Current 和 Playlist。
- 当前视图必须保留明确但轻量的 Selected 状态。
- 使用无修饰 `Tab` 在 Current 和 Playlist 之间循环切换。
- Overlay 不再显示左侧模块导航。
- 顶部、左侧和右侧不使用 Divider 划分区域，依赖内容、间距和选中状态形成视觉层级。

### 6.1 Current

- 左侧上下文区域约占内容宽度的 `20%`。
- 左侧显示当前视频的一张固定封面。
- 封面下方显示弱化的视频名称、Episode 等必要识别信息。
- 封面不显示观看进度条或时间 Badge。
- 封面视觉中心与右侧焦点字幕的 Focus Anchor 位于同一水平线上。
- 视频信息位于封面下方，不参与中心对齐。
- 右侧继续复用现有 Subtitle Focus Cue Reel。
- Cue 导航、滚动和选择变化不更新当前视频封面。

### 6.2 Playlist

Playlist 始终使用当前播放来源的完整数据，不受 Command Panel 首屏数量限制。

字幕型 Playlist：

- 适用于 Search Result 和 Shiori。
- 复用 Current 的左右布局，但允许更紧凑的信息密度。
- 左侧同时只显示当前稳定选择对应的一张封面及必要上下文信息。
- 右侧复用现有 Playback Cue Result Reel。
- 选择尚未稳定时不更新封面。
- 不为列表中的每一行分别加载封面。

视频型 Playlist：

- 适用于 Library 和 Recent Videos。
- 复用现有 Playback Library 的列表、条目和选择视觉。
- 不显示原页面顶部标题。
- 选择效果复用对应现有条目的选择区域和视觉规则。
- 不增加新的 Library 详情界面或独立视频列表组件。

### 6.3 Cue 快捷键

Current、字幕型 Playlist 和 Command Panel Search Result 复用相同的 Cue 快捷键及现有语义：

- `S`：保存当前选中的 Primary Cue。
- `X`：复制当前选中 Primary Cue 的 Markdown Cue Link。
- `C`：复制当前选中 Primary Cue 的完整文本。
- `Enter`：跳转到当前选中 Primary Cue 并播放。

不存在稳定 Selected Primary Cue 时，上述动作不执行。

## 7. Playback Command Panel

Command Panel 是播放内的轻量搜索、跳转和恢复入口，不是完整 Universal Search。

### 7.1 打开和层级

- Playback Page 或 Playback Overlay 活跃时，按 `Cmd+Enter` 打开。
- 文本输入状态下不响应 `Cmd+Enter`。
- Command Panel 位于 Playback Content 和 Playback Overlay 之上。
- 打开后取得唯一键盘焦点。
- 下层内容保持可见但不可交互，并降低对比、变暗或轻微模糊。
- Command Panel 不显示 macOS Traffic Light Buttons。
- 每次打开默认进入一级界面，搜索框默认获得焦点。

### 7.2 一级界面

查询为空时：

1. Recent Videos，默认选中；
2. Recent Shioris。

查询不为空时：

1. `Search {Query}`，默认选中；
2. Recent Videos；
3. Recent Shioris。

首版 Search 只执行现有字幕搜索，不增加视频搜索、Shiori List 搜索或跨对象聚合搜索。

一级界面 Footer：

- 不显示左下角 App 图标。
- 显示 `↑`、`↓`、`Navigate`。
- 显示 `Open` 和 `Enter`。
- 不显示 Actions 及其快捷键提示。

### 7.3 二级界面通用规则

- 左上角显示返回箭头。
- 顶部居中显示当前标题。
- 隐藏搜索输入框。
- `Up` 和 `Down` 移动选择。
- Selected 状态作用于完整可操作行。
- `Escape` 返回一级界面。
- 一级界面按 `Escape` 关闭 Command Panel。

### 7.4 Search Result

- 标题显示当前查询词。
- 复用 Current 的左右布局，并使用更紧凑的排版。
- 默认选择第一条有效结果。
- 完整结果不超过 `50` 条时，Footer 显示 `{N} results`。
- 完整结果超过 `50` 条时，Panel 只显示前 `50` 条，Footer 显示 `Showing first 50 results`。
- `50` 条限制只影响 Command Panel 预览。
- 执行任意结果的主操作后，使用完整搜索结果建立 Playlist，不截断为 `50` 条。
- Search Result 中没有可编辑输入焦点，因此支持 `S`、`X`、`C` 和 `Enter` 等 Cue 快捷键。

### 7.5 Recent Videos

- 显示完整 Recent Videos 数据。
- 使用纵向单列 Row。
- 左侧复用现有视频卡片的 `16:9` 封面比例、观看进度和时间 Badge。
- 右侧第一行显示标题。
- 右侧第二行显示相邻排列的 Episode 和 Watch Status Badge。
- 封面不得拉伸或放大为页面主视觉。
- Selected 状态作用于完整 Row。
- Footer 显示 `{N} videos`。

### 7.6 Recent Shioris

- 显示完整 Recent Shioris 数据。
- 复用 Workbench Recent Shiori Resume Row。
- Selected 状态作用于完整 Row。
- Footer 显示 `{N} shioris`。

## 8. 播放暂停与恢复

Playback Overlay 和 Command Panel 共同构成播放模态层级：

- 打开第一层模态界面时，记录此前播放状态并暂停播放。
- 从 Playback Overlay 打开 Command Panel 时，Overlay 保留在下层。
- 关闭 Command Panel 后，如果下层仍有 Playback Overlay，继续保持暂停。
- 只有 Playback Overlay 和 Command Panel 都关闭后，才根据打开第一层前的播放状态决定是否恢复播放。
- 如果执行了明确的播放或跳转动作，以该动作结果为准，不再恢复旧播放位置。
- 关闭模态界面本身不得执行隐式 Seek。

## 9. Recent Shioris 恢复规则

每条 Recent Shiori 只需保存恢复当前学习场景所必需的信息：

- 原 Shiori List；
- 最后播放的 Cue 锚点；
- 当时使用的排序状态。

恢复时使用最新数据库内容重新生成原 Shiori List：

1. 锚点仍在原列表中且可以播放时，按保存的排序恢复并从锚点继续。
2. 锚点无法定位或播放时，不推断具体原因；按该列表当前有效内容从第一条开始。
3. 列表中已经没有可播放 Cue 时，移除对应 Recent Shiori 入口，但不删除 Shiori List。

不得通过搜索其他 Shiori List、猜测替代 Cue 或建立复杂补偿规则恢复已经失效的场景。

## 10. 本次不实现

- Command Panel 完整 Universal Search。
- 视频、文件夹或 Shiori List 搜索。
- Command Panel 深度筛选、排序、批量操作或管理能力。
- Command Panel 系统级全局唤起或非播放状态入口。
- Command Panel Actions 菜单及额外功能按钮。
- 为 Command Panel 单独建立重型虚拟化表格。
- 按剧集或视频文件夹搜索。
- 新增 Shiori 管理能力。
- 改变 Recent Videos 现有数据语义。
- 与本需求无关的组件重构、数据层重构或架构迁移。

# UI文档改动

本需求同步更新 `docs/human/design/UI.md`，完整改动范围如下。

## 1. Playback Search Box 改为 Command Panel Search Box

修改前：

- Playback Search Box 属于 Playback Multi-Module Overlay 的 Search Module。
- 输入查询后直接更新 Playback Search Result。
- 输入焦点仅显示 Caret，不增加 Focus Ring。

修改后：

- 组件更名为 Command Panel Search Box。
- 用于 Playback Command Panel 一级界面。
- Command Panel 打开后默认获得输入焦点并显示 Caret。
- 获得焦点时不增加额外 Focus Ring、焦点边框或焦点背景。
- 点击 Inline Clear Button 清除 Query，并重新显示 Empty Query 一级选项。
- 输入焦点存在时，无修饰字母键优先作为查询输入。
- 进入任一 Command Panel 二级界面后隐藏输入框。
- 全局键盘焦点规则中的 Playback Search Box 同步更名为 Command Panel Search Box。

## 2. App Sidebar 增加二级导航

修改前：

- Search、Recent、Library 和 Shiori 均为无层级的 App Sidebar Navigation Item。
- Navigation Item 只有 Default、Selected 和 Disabled 状态。
- 点击 Navigation Item 直接切换页面。

修改后：

- App Sidebar Navigation Item 承载 Search、Recent、Library 和 Shiori 一级导航。
- Recent 和 Shiori 显示 Disclosure Indicator。
- Search 和 Library 不显示 Disclosure Indicator。
- 一级 Item 支持 Default、Selected、Expanded、Collapsed 和 Disabled。
- 点击 Label 或 Leading Icon 进入对应一级页面。
- 点击 Disclosure Indicator 只展开或收起二级导航，不执行页面导航。
- 增加 App Sidebar Child Item，承载：
  - Recent Videos
  - Recent Shioris
  - 当前存在的 Shiori List
- Child Item 不显示 Leading Icon，通过缩进表达层级。
- Recent 展开后固定显示 Recent Videos 和 Recent Shioris。
- Shiori 展开后按当前 Shiori List 默认顺序显示。
- Shiori List 超出可用高度时，二级区域独立纵向滚动。
- 二级导航只显示名称，不显示封面、字幕、Resume 位置或其他富信息。

## 3. Recent Watching Card 明确内容结构

修改前：

- Library Cover、Progress Overlay、Time Badge、Folder Name、Episode Label 和 Watch Status Badge 作为未分组内容排列。

修改后：

- 内容从上到下分为：
  1. Cover Region
  2. Folder Name
  3. Meta Row
- Cover Region 包括：
  - Library Cover
  - Library Cover Progress Overlay
  - Library Cover Badge / Time
- Meta Row 水平排列 Episode Label 和 Watch Status Badge。
- Episode Label 与 Watch Status Badge 位于同一行并紧邻排列。
- Watch Status 必须使用 Watch Status Badge，不得降级为普通彩色文字或使用圆点分隔。

## 4. 增加 Workbench Recent 页面布局

新增 Recent Overview Layout：

- App Topbar Title 为 `Recent`。
- 页面从上到下包括：
  1. Recent Videos Section
  2. Recent Shioris Section
- 每个 Section Header 包括：
  - Section Title
  - 完整二级页总数
  - 进入完整二级页的箭头
- Section Title 使用 Primary 文字颜色。
- 总数使用 Secondary 文字颜色。
- 总数表示完整二级页总数，不表示一级页当前预览数量。
- Section Header 箭头用于进入完整二级页，不承担 Sidebar 展开或收起动作。

新增 Recent Videos Section Layout：

- 一级页预览复用 Recent Watching Card Layout。
- 保留 Library Cover Progress Overlay、Library Cover Badge / Time、Episode Label 和 Watch Status Badge。
- 完整二级页继续复用 Recent Watching Card Layout。
- 完整二级页显示全部 Recent Videos。
- 不增加 Search、Filter、Sort 或批量操作。

新增 Recent Shiori Resume Row Layout：

- Row 使用水平布局并占满可用内容宽度。
- 左侧显示 Shiori List 的 Library Cover。
- 右侧从上到下显示：
  1. List Name
  2. Description
  3. `Resume {Current Position} / {Total Count}`
  4. 最近播放的字幕文本
- Library Cover 保持 `--aspect-library-cover`，不得拉伸或变形。
- List Name 使用 Primary 文字样式。
- Description 使用 Muted 文字样式。
- Resume 位置使用 Secondary 文字样式。
- 最近播放字幕文本使用 Primary 文字样式。
- Description 为空时不增加替代文案。
- Row 之间使用间距或轻量 Divider，不使用独立 Card Border 或 Shadow。

新增 Recent Shioris Section Layout：

- 一级页每行显示一个 Recent Shiori Resume Row。
- 完整二级页复用相同 Row 并显示全部 Recent Shioris。
- 首版不显示 Search、Filter、Sort、管理按钮或批量操作。

## 5. Playback Module Sidebar Item 改为 Playback View Tab

修改前：

- Playback Module Sidebar Item 用于 Current、Playlist、Search、Recent、Library 和 Shiori 六个 Module。
- Overlay 左侧始终显示 Module Sidebar。
- Selected 通过文字和图标颜色表达。

修改后：

- 组件更名为 Playback View Tab。
- 只用于 Current 和 Playlist 两个 View。
- Label 固定为 `Current` 或 `Playlist`。
- Selected 使用 Primary 文字颜色，并在文字下方显示短 Accent 下划线。
- Unselected 使用 Muted 文字颜色。
- 不显示选中背景、边框或 Focus Ring。
- 同一时刻只有一个 Playback View Tab 处于 Selected。
- 点击 Unselected Tab 切换 View。
- 点击当前 Selected Tab 不重复切换。

## 6. Playback Multi-Module Overlay 改为 Playback Overlay

修改前：

- 组件章节和 Layout 名称为 Playback Multi-Module Overlay。
- Overlay 包含 Current、Playlist、Search、Recent、Library 和 Shiori 六个 Module。
- Search、Recent、Library 和 Shiori 分别作为 Overlay 内独立页面。
- 左侧 Module Sidebar 承担模块切换。

修改后：

- 组件章节更名为 Playback Overlay。
- Layout 更名为 Playback Overlay Layout。
- Overlay 只保留 Current 和 Playlist 两个 View。
- Search、Recent、Library 和 Shiori 不再作为独立 Overlay Module。
- Search Result、Shiori、Recent Videos 和 Library 只作为 Playlist Source。
- Appearance 更新时更新当前可见 View、Native Reel 和 Scrollbar，不重建 Overlay Session，也不改变当前 View、选择位置或滚动位置。

## 7. Playback Cue 组件适用范围

### 7.1 Subtitle Focus Cue

修改前：

- 完整 Cue 原文作为 `S`、`C` 和 `Enter` 的动作目标。

修改后：

- Selected Cue 作为 `S`、`X`、`C` 和 `Enter` 的动作目标。
- Cue 本身继续不显示 Hover，也不响应点击。
- 点击不得改变选择或穿透到底层 Video。

### 7.2 Playback Cue Result

修改前：

- 用于 Playlist、Search 和 Shiori 三个独立 Module。

修改后：

- 用于字幕型 Playlist 和 Command Panel Search Result。
- 继续显示一个 Primary Cue，以及可选的 Cue Group。
- Show Cue Group 只改变显示内容，不改变 Primary Cue Identity。
- 所有默认 Cue 动作继续以 Primary Cue 为目标。

### 7.3 Show Cue Group

修改前：

- 同一设置适用于 Playback Multi-Module Overlay 的 Playlist、Search 和 Shiori。

修改后：

- 同一设置适用于 Workbench Search、Workbench Shiori、Context、字幕型 Playlist 和 Command Panel Search Result。
- Playback Overlay 和 Command Panel Search Result 使用 Playback Cue Result 显示规则。
- Off 时只显示 Primary Cue。
- On 时在 Primary Cue 上方显示全部 Additional Cues。
- Primary Cue Identity 和动作目标不变。

## 8. Playback Overlay 的 Feature Host 与 Enter Context

修改前：

- Playback Search、Recent、Library 和 Shiori 分别作为对应 Workbench Feature 的受限宿主。
- 各 Module 共享 Workbench Feature 状态。
- 从各 Module 成功播放后更新 Playback Enter Context。

修改后：

- 改为 Playlist Source Host。
- Playlist 可以来源于：
  - Search Result
  - Shiori
  - Recent Videos
  - Library
- Playlist 复用对应 Workbench Feature 的数据顺序和正式操作结果。
- Playback 不提供 Checkbox 批量操作、导出、添加文件夹、Context、Filter 控件或复制表格入口。
- Current 不属于 Workbench Feature Host，只显示当前视频及其完整 Cue 集合。

Playback Enter Context 更新规则：

- 从 Search Result Playlist 成功播放 Result 时更新为 Search。
- 从 Shiori Playlist 成功播放 Result 时更新为 Shiori。
- 从 Recent Videos Playlist 成功播放视频时更新为 Recent。
- 从 Library Playlist 成功播放视频时更新为对应的 Library Folder Detail。
- 后一次成功播放替换前一次 Playback Enter Context。
- 只切换 Current 与 Playlist、浏览 Playlist、打开或关闭 Command Panel，不更新 Playback Enter Context。
- 关闭 Playback Page 时，根据当前 Playback Enter Context 返回 Workbench。
- Playback Enter Context 只决定返回目标，不保存、删除或回滚其他 Feature 状态。

## 9. Playback Overlay 基本结构

修改前：

1. Playback Module Sidebar
2. Module Content Region

修改后：

1. Playback View Switcher
2. View Content Region

Playback View Switcher：

- 固定在 Overlay 顶部并横跨完整内容宽度。
- 居中排列 Current 和 Playlist。
- 当前 View 使用 Selected 状态。
- 不显示独立背景、边框或 Divider。
- 无修饰 `Tab` 在 Current 和 Playlist 之间循环切换。
- 无修饰 `Tab` 不执行原生焦点遍历。
- 不提供其他 View 切换按钮或快捷键。

View Content Region：

- 占据 Playback View Switcher 下方全部可用区域。
- Current 和 Playlist 共享同一 View Content Region。
- View 切换只替换 View Content Region 内容，不关闭 Overlay。
- 左右内容区域之间不显示独立背景、边框或 Divider。

## 10. Playback Overlay 打开与 Session

修改前：

- Playback Page 活跃时按 `Enter` 打开。
- 默认 Module 为 Current。
- 六个 Module 的切换属于同一次 Overlay Session。
- Session 保存各 Module 的层级、选择和滚动状态。

修改后：

- Playback Page 活跃时按 `Enter` 打开。
- 每次打开创建新的临时 Overlay Session。
- 打开后立即暂停 Playback。
- 默认 View 为 Current。
- Current 和 Playlist 的切换属于同一次 Overlay Session。
- View 切换期间保留 Current 和 Playlist 各自的选择与滚动位置。
- Escape、播放动作、关闭 Playback Page或其他关闭路径结束并销毁当前 Overlay Session。
- Session 结束后不保留当前 View、选择位置、滚动位置或临时显示内容。
- 再次打开时默认进入 Current，并重新初始化两个 View 的局部状态。
- Session 销毁不删除 Playlist、Playback History、Search Query、Shiori、Recent、Library 或其他持久状态。

## 11. Current Layout

修改前：

- Current 只显示居中的 Subtitle Focus Cue Reel。

修改后：

- Current 使用水平布局，包括 Context Region 和 Subtitle Region。
- Context Region 约占 View Content Region 宽度的 `20%`。
- Subtitle Region 使用其余可用宽度。
- Context Region 显示当前视频的一张固定 Library Cover。
- Library Cover 不显示 Progress Overlay 或 Time Badge。
- Library Cover 下方显示弱化的视频名称、Episode Label 和必要识别信息。
- Library Cover 不随 Cue Navigation 或滚动变化。
- Library Cover 的视觉中心与 Subtitle Region 的 Focus Anchor 位于同一水平线上。
- 视频识别信息位于 Library Cover 下方，不参与中心对齐。
- Subtitle Region 继续复用现有 Subtitle Focus Cue Reel。
- Cue Reel 允许顶部和底部出现部分可见的相邻 Cue。
- Current 不显示卡片、边框、背景或可见 Focus Marker。
- Current Scrollbar 位于 Subtitle Region Trailing Edge。

## 12. Playback Cue Result Reel

修改前：

- 适用于 Playlist、Search 和 Shiori。
- Playlist 和 Shiori 首次初始化时选择第一条 Result。
- Search 首屏结果出现后选择第一条 Result。
- Result 不显示 Hover，不响应左键。
- 切换 Module 后恢复选择与滚动位置。

修改后：

- 适用于字幕型 Playlist 和 Command Panel Search Result。
- 字幕型 Playlist 在本次 Session 首次初始化时默认选择第一条 Result。
- Command Panel Search Result 首屏结果出现后默认选择第一条 Result。
- 字幕型 Playlist 中，Result 不显示 Hover，不响应左键。
- Command Panel Search Result 的 Selected 和 Pointer 行为遵循 Playback Command Panel Layout。
- Command Panel Search Result 中点击 Result，执行与 `Enter` 相同的主操作，并进入包含完整搜索结果的 Playlist。
- 没有 Result 时不存在 Selected Result，所有字幕动作均无动作。
- 从 Current 切换回字幕型 Playlist 后，恢复本次 Session 内的选择和滚动位置。

## 13. Playback Media Selection

修改前：

- 适用于独立的 Recent、Library 一级界面和 Library 二级界面。
- Module 切换后恢复层级、选择与滚动位置。

修改后：

- 适用于来源为 Recent Videos 或 Library 的视频型 Playlist。
- 继续复用所属 Workbench Card Layout 的 Hover Region 和 Hover 视觉。
- Recent Watching Card 和 Library Folder Card 的 Selected 视觉作用于完整卡片。
- Library Episode 的 Selected 视觉只作用于 Cover Region。
- 不可用 Item 不允许成为 Selected Item。
- `Enter` 执行 Selected Item 在原 Layout 中定义的左键主操作。
- 鼠标左键和右键动作继续由所属 Card Layout 定义。
- 从 Current 切换回视频型 Playlist 后，恢复本次 Session 内的层级、选择和滚动位置。

## 14. Playlist 视觉分型

修改前：

- Playlist 只使用 Playback Cue Result Reel。
- Search、Recent、Library 和 Shiori 分别使用独立 Module Layout。

修改后：

- Playlist 的视觉布局由当前 Playlist Source 决定。
- Playlist 始终保留完整数据集合，不受 Command Panel 首屏数量限制。
- 本次 Session 首次进入 Playlist 时默认选择第一条可用 Item。
- 再次返回 Playlist 时恢复本次 Session 内的选择和滚动位置。

字幕型 Playlist：

- 适用于 Search Result 和 Shiori。
- 复用 Current 的 Context Region 与 Subtitle Region。
- 整体信息密度可以高于 Current。
- Context Region 同时只显示当前 Settled Result 对应的一张封面。
- Context Region 可以显示 Display Title、所属 Shiori List、当前位置和总数。
- Subtitle Region 使用 Playback Cue Result Reel。
- Result 选择稳定后才更新 Context Region。
- `S`、`X`、`C` 和 `Enter` 的动作目标为 Selected Result 的 Primary Cue。

视频型 Playlist：

- 适用于 Library 和 Recent Videos。
- 复用现有 Playback Library 列表、条目和选择视觉。
- 不显示页面顶部 Title。
- Library Source 使用现有 Library Folder 或 Episode 条目。
- Recent Videos Source 复用 Recent Watching Card 的视觉元素。
- Selected 视觉复用对应现有条目的选择区域和视觉规则。
- 方向键选择 Previous Item 或 Next Item。
- `Enter` 执行当前 Selected Item 的主操作。

## 15. Playback Overlay Cue Keyboard Actions

修改前：

- 适用于 Current、Playlist 和 Shiori。
- 支持 `S`、`C` 和 `Enter`。

修改后：

- 适用于 Current 和字幕型 Playlist。
- 所有动作以已经 Settled 的 Selected Primary Cue 为目标。
- Cue 正在移动时接受的动作，在当前目标 Settled 后执行一次。
- 不存在 Selected Primary Cue 时，`S`、`X`、`C` 和 `Enter` 均无动作。

快捷键：

- `S`
  - 保存 Selected Primary Cue。
  - 已保存时不删除、不重复创建。
  - Overlay 保持显示，Playback 保持暂停。

- `X`
  - 复制 Markdown Cue Link。
  - 格式为 `[Cue text](cueseeker://cue?id={CueID})`。
  - 只发布 Plain Text，不发布 HTML 或 RTF。
  - 显示 `Subtitle(markdown format) Copied`。
  - Overlay 保持显示，Playback 保持暂停。

- `C`
  - 复制 Selected Primary Cue 的完整多行文字。
  - 不复制完整 Cue Group。
  - 保留源行序和换行。
  - 显示 `Subtitle Copied`。
  - Overlay 保持显示，Playback 保持暂停。

- `Enter`
  - Seek 至 Selected Primary Cue Start Time。
  - 关闭 Overlay 并销毁当前 Overlay Session。
  - 从该位置连续播放。
  - 显示 `Play`。

## 16. 新增 Playback Command Panel Layout

新增 Playback Command Panel Layout：

- Command Panel 是 Playback 中的快速搜索、跳转和恢复界面。
- 位于 Playback Overlay 和 Playback Content 之上。
- 打开后取得唯一键盘焦点。
- 下层 Playback Overlay 或 Playback Content 保持可见，但降低对比、变暗或轻微模糊，并且不可交互。
- 不显示 macOS Traffic Light Buttons。
- 不显示不承担操作的顶部或左右 Divider。
- 使用内容排列、留白和 Selected Row 自然划分区域。

打开：

- Playback Page 活跃时按 `Cmd+Enter`。
- Playback Overlay 活跃时也可以打开。
- 文本输入状态下不响应 `Cmd+Enter`。
- 打开后暂停 Playback。
- 每次打开默认进入一级界面。
- Command Panel Search Box 默认获得输入焦点。

一级界面 / Empty Query：

1. Recent Videos，默认 Selected。
2. Recent Shioris。

一级界面 / Filled Query：

1. Search Action，默认 Selected。
2. Recent Videos。
3. Recent Shioris。

Search Action 包括 Search Icon、`Search` 和当前 Query。

一级界面 Footer：

- 不显示左下角 App Icon。
- 显示 `↑`、`↓`、`Navigate`。
- 显示 `Open` 和 `Enter`。
- 不显示 Actions 或对应快捷键提示。

二级界面 Header：

- 左上角显示 Back Button。
- 标题在 Header 中水平居中。
- Recent Videos 标题为 `Recent Videos`。
- Recent Shioris 标题为 `Recent Shioris`。
- Search Result 标题为当前 Query。
- 隐藏 Command Panel Search Box。

Search Result：

- 使用比 Current 更紧凑的 Context Region 与 Subtitle Region。
- 不显示 Playback View Switcher。
- 默认选择第一条 Result。
- Selected 视觉作用于完整 Result Row。
- Command Panel 最多显示前 `50` 条 Result。
- 完整结果数小于等于 `50` 时，Footer 左侧显示 `{N} results`。
- 完整结果数大于 `50` 时，Footer 左侧显示 `Showing first 50 results`。
- 打开任意 Result 后，进入包含完整结果集合的 Playlist。
- `50` 条限制只作用于 Command Panel 当前结果预览。
- Search Result 二级界面没有可编辑输入焦点。
- 支持 Playback Overlay 当前全部 Cue 快捷键，包括 `S`、`X`、`C` 和 `Enter`。
- Cue 快捷键以已经 Settled 的 Selected Primary Cue 为目标。

Recent Videos：

- 使用纵向单列 Row。
- Row 左侧显示紧凑的 `16:9` Library Cover。
- Cover 保持现有 Workbench 视频卡片比例，不得拉伸或放大为主视觉。
- Cover 底部显示 Library Cover Progress Overlay。
- Cover 右下角显示 Library Cover Badge / Time。
- Row 右侧第一行显示 Folder Name。
- Row 右侧第二行同时显示 Episode Label 和 Watch Status Badge。
- Episode Label 与 Watch Status Badge 紧邻排列。
- Watch Status 必须使用圆角 Badge。
- Selected 视觉作用于完整 Row。
- Footer 左侧显示 `{N} videos`。
- 二级界面显示完整 Recent Videos 列表。

Recent Shioris：

- 复用 Recent Shiori Resume Row Layout。
- Selected 视觉作用于完整 Row。
- Footer 左侧显示 `{N} shioris`。
- 二级界面显示完整 Recent Shioris 列表。

二级界面 Footer：

- 显示 `↑`、`↓`、`Navigate`。
- 显示 `Open` 和 `Enter`。
- 不显示 Actions 或对应快捷键提示。

导航与关闭：

- `Up` 选择 Previous Item。
- `Down` 选择 Next Item。
- `Enter` 执行 Selected Item 的主操作。
- 二级界面按 `Escape` 返回一级界面。
- 一级界面按 `Escape` 关闭 Command Panel。
- 从 Playback Overlay 打开的 Command Panel 关闭后返回原 Overlay。
- 下层仍存在 Playback Overlay 时继续保持暂停。
- 下层不存在其他模态界面时，根据打开第一层模态界面前的 Playback State 决定是否恢复播放。