# 说明

1. 本文档由人类维护，是 `/docs/human/design/ui/` 的目录与编号索引（Map of Content）。
2. **AI 检索规则（Token 优化与防遗漏铁律）**：
   - 凡涉及 UI 视觉、组件或布局实现，**必须首先阅读 [`UI Design Rules.md`](UI%20Design%20Rules.md)（通用视觉与度量公理）与 [`UI Interaction Rules.md`](UI%20Interaction%20Rules.md)（通用交互状态机）**。
   - 随后，根据下方编号速查表，**仅按需读取涉及的组件（`C-xx`）、布局（`L-xx`）或 Token 章节**，严禁无差别全量加载所有 UI 分册。
3. **编号沟通规范**：
   - 每个组件具有唯一编号 `C-{分类}.{序号}`，每个布局具有唯一编号 `L-{分类}.{序号}`。
   - 在需求讨论、截图走查标注、Bug 定位时，统一使用编号 + 名称（如 `C-05.6 Breadcrumb`、`L-04.5 File Page Layout`）指代目标元素。

---

# 1. UI 文档分册职责

| 文档名称 | 内容范围 |
| --- | --- |
| [`UI Design Rules.md`](UI%20Design%20Rules.md) | **全局视觉与度量约束**：无按下视觉效果、选中态组件白名单、Dialog 四边等距与 Cap 顶测量法则、Light/Dark 明暗表面海拔层级、页面/网格/滚动条槽位边距体系、封面加载防闪烁。 |
| [`UI Interaction Rules.md`](UI%20Interaction%20Rules.md) | **全局交互与输入规则**：界面层级与上层屏蔽、菜单模态、Hover 与选中更新条件、按下触发时机、焦点与 Tab、快捷键录入、尺寸过渡禁点、全屏行为、Player UI 与指针显隐、鼠标指针形状（Arrow/Grab/I-beam）优先级、无障碍交互预留。 |
| [`UI Tokens.md`](UI%20Tokens.md) | **Core Tokens**：`1.1 颜色`、`1.2 字体与文本`、`1.3 尺寸（Height / Size）`、`1.4 间距（Spacing / Padding）`、`1.5 形状与效果（Radius / Shadow / Scrim / Opacity）`、`1.6 动效`。 |
| [`UI Components - Controls.md`](UI%20Components%20-%20Controls.md) | **基础交互组件（`C-01` ~ `C-07`）**：输入框、选择控件、按钮、菜单、导航（Sidebar / Tabs / Breadcrumb）、表格、滚动条。 |
| [`UI Components - Domain.md`](UI%20Components%20-%20Domain.md) | **业务与反馈组件（`C-08` ~ `C-13`）**：数据展示徽章与标题、Toast 与播放反馈、对话框容器、媒体封面与卡片、播放器控制条组件、播放台词流组件。 |
| [`UI Layouts - Workbench.md`](UI%20Layouts%20-%20Workbench.md) | **工作台与弹窗布局（`L-01` ~ `L-06`）**：App 壳层、设置窗口、Recent、Library 与 File、Search 与 Excerpt、全部模态对话框与任务面板。 |
| [`UI Layouts - Playback.md`](UI%20Layouts%20-%20Playback.md) | **播放相关布局（`L-07` ~ `L-09`）**：播放器顶底栏与反馈层、Playback Overlay（Current / Playlist / Collage Editor）、Command Panel。 |
| [`Icon Registry.md`](Icon%20Registry.md) | **图标名录**：Phosphor 图标制作规格、尺寸与线宽映射表、全量图标使用位置。 |
| [`Toast Usage Registry.md`](Toast%20Usage%20Registry.md) | **Toast 与 HUD 注册表**：全场景提示文案（英/简/繁）、图标、持续时间与 Scenario ID。 |
| [`Tooltip Usage Registry.md`](Tooltip%20Usage%20Registry.md) | **Tooltip 注册表**：全场景悬停提示文案（英/简/繁）、快捷键跟随规则、触发延迟与 Scenario ID。 |

---

# 2. 组件编号索引（Components `C-01` ~ `C-13`）

## 2.1 基础交互组件（位于 [`UI Components - Controls.md`](UI%20Components%20-%20Controls.md)）

| 分类 | 编号 | 组件名称 | 包含变体 / 子项 |
| --- | --- | --- | --- |
| **2.1 Inputs** | `C-01.0` | Inputs Shared | Focus Treatment、Single-line Input Behavior、Pointer |
| | `C-01.1` | Text Field | — |
| | `C-01.2` | Text Area | — |
| | `C-01.3` | Search Field | — |
| | `C-01.4` | Number Field | — |
| | `C-01.5` | Shortcut Field | — |
| **2.2 Selection Controls** | `C-02.1` | Checkbox | `Table Selection Checkbox`、`Playback Selection Checkbox`、`Form Checkbox` |
| | `C-02.2` | Switch | Platform Native Switch |
| | `C-02.3` | Color Well | Swatch、Hex Input、Preset Popover |
| | `C-02.4` | Segmented Control | — |
| | `C-02.5` | Filter Chip | — |
| **2.3 Buttons** | `C-03.1` | Button | `Neutral`、`Cover Summary`、`Primary`、`Destructive` |
| | `C-03.2` | Icon Button | Sizes: `Default`、`Inline Clear`、`Row Action`、`Dialog Close` |
| | `C-03.3` | Shortcut Action Button | `Overlay Surface`、`Popover Surface` |
| **2.4 Menus** | `C-04.1` | Menu | `Dropdown Menu`、`Context Menu`、`Player Speed Menu`、`Player More Menu` |
| | `C-04.2` | Submenu | `Excerpt Destination Submenu`、`Audio Track Submenu`、`Subtitle Submenu` |
| | `C-04.3` | Menu Item | `Action Menu Item`、`Radio Menu Item`、`Destructive Menu Item`、`Submenu Trigger` |
| | `C-04.4` | Menu Divider | — |
| **2.5 Navigation** | `C-05.1` | Sidebar | — |
| | `C-05.2` | Sidebar Toggle | — |
| | `C-05.3` | Sidebar Item | `Primary` |
| | `C-05.4` | Tabs | — |
| | `C-05.5` | Tab | — |
| | `C-05.6` | Breadcrumb | 面包屑导航（未激活节点、当前节点、`caret-right` 分隔符） |
| **2.6 Tables** | `C-06.1` | Table | — |
| | `C-06.2` | Table Header Cell | `Selection` |
| | `C-06.3` | Table Row | — |
| | `C-06.4` | Table Cell | `Text`、`Index Text`、`Interactive Text` |
| | `C-06.5` | Selection Action Overlay | — |
| **2.7 Scrollbars** | `C-07.1` | Scrollbar | `Vertical`、`Horizontal` |

## 2.2 业务与反馈组件（位于 [`UI Components - Domain.md`](UI%20Components%20-%20Domain.md)）

| 分类 | 编号 | 组件名称 | 包含变体 / 子项 |
| --- | --- | --- | --- |
| **2.8 Data Display** | `C-08.1` | Watch Status Badge | `Unwatched`、`Watching`、`Finished` |
| | `C-08.2` | Task Status Badge | `In Progress`、`Queued` |
| | `C-08.3` | Information Badge | `Cover Badge`、`Task Count Badge` |
| | `C-08.4` | Tag | `Default`、`Player Chrome` |
| | `C-08.5` | Status Indicator | `Workbench Status Indicator`、`Cue State Indicator` |
| | `C-08.6` | Tooltip | — |
| | `C-08.7` | Section Title | — |
| | `C-08.8` | Workbench Page Title | — |
| | `C-08.9` | Keycap | `Overlay Surface`、`Popover Surface` |
| **2.9 Feedback** | `C-09.1` | Toast | — |
| | `C-09.2` | Empty State | `Empty Hint`、`Info Page State` |
| | `C-09.3` | Progress Indicator | `Indeterminate Spinner`、`Bar` |
| | `C-09.4` | Spinner | — |
| | `C-09.5` | Playback Feedback | — |
| | `C-09.6` | Player Error Banner | — |
| **2.10 Dialogs** | `C-10.1` | Dialog | — |
| | `C-10.2` | Confirmation Dialog | — |
| **2.11 Media** | `C-11.1` | Cover | — |
| | `C-11.2` | Cover Summary | `Split Form`、`Backdrop Form`（`Description Variant` / `Metadata Variant`） |
| | `C-11.3` | Cover Crop Editor | — |
| | `C-11.4` | Cover Progress | — |
| | `C-11.5` | Media Card | — |
| **2.12 Player Controls** | `C-12.1` | Player Speed Button | — |
| | `C-12.2` | Player Time Display | — |
| | `C-12.3` | Player Progress Scrubber | — |
| | `C-12.4` | Player Progress Time Capsule | — |
| | `C-12.5` | Player Volume Control | — |
| | `C-12.6` | Player Title | — |
| **2.13 Playback Content** | `C-13.1` | Playback Cue Metadata | — |
| | `C-13.2` | Subtitle Focus Cue | — |
| | `C-13.3` | Playback Cue Result | — |
| | `C-13.4` | Playback Cue Reel | `Focus Cue Reel`、`Cue Result Reel`（Marker: `None` / `Collage Selection`） |

---

# 3. 布局编号索引（Layouts `L-01` ~ `L-09`）

## 3.1 工作台与弹窗布局（位于 [`UI Layouts - Workbench.md`](UI%20Layouts%20-%20Workbench.md)）

| 分类 | 编号 | 布局名称 | 职责简述 |
| --- | --- | --- | --- |
| **3.1 App Shell** | `L-01.1` | App Sidebar Layout | 主窗口左侧导航栏与自动收起阈值 |
| | `L-01.2` | App Topbar Layout | 主窗口顶栏（红绿灯、Sidebar Toggle、前进后退、标题、Task/Settings 入口） |
| | `L-01.3` | Workbench Titled Page Layout | 工作台通用页面容器、内边距与滚动条通道 |
| | `L-01.4` | Toast Layout | 窗口中心最多 4 条 Toast 堆叠与同 ID 刷新计时 |
| **3.2 Settings** | `L-02.1` | Settings Window Layout | 独立设置窗口尺寸与分栏结构 |
| | `L-02.2` | Settings Sidebar Layout | 设置窗口左侧分类导航列表 |
| | `L-02.3` | Settings Category Layout | 设置分类页分组卡片（Group Stack）与行排版 |
| | `L-02.4` | Settings Shortcuts Layout | 快捷键设置页与 Restore Default 按钮布局 |
| | `L-02.5` | Settings Subtitle Layout | 字幕样式设置页与条件显隐规则 |
| **3.3 Recent** | `L-03.1` | Recent Layout | Recent 页面（顶栏 Tabs + 视频/摘录卡片网格） |
| | `L-03.2` | Recent Watching Card Layout | 最近观看视频卡片结构（封面、进度、时长、文件夹名、集数与状态徽章） |
| **3.4 Library and File** | `L-04.1` | Library Overview Layout | 媒体库一级总览页（统计与排序栏 + 文件夹卡片网格） |
| | `L-04.2` | Library Folder Card Layout | 媒体库一级文件夹卡片 |
| | `L-04.3` | Library Folder Detail Layout | 媒体库二级详情页（Cover Summary + 剧集网格） |
| | `L-04.4` | Library Episode Grid Layout | 剧集卡片自适应网格 |
| | `L-04.5` | File Page Layout | File 三级页面（状态操作栏、面包屑、文件夹列表、单集容器） |
| | `L-04.6` | File Card Layout | File 页面文件夹/视频/字幕列表卡片与右侧 `dots-three` 操作区 |
| **3.5 Search and Excerpt** | `L-05.1` | Excerpt List Overview Layout | Excerpt 一级总览页（汇总行 + 新建按钮 + 摘录集网格） |
| | `L-05.2` | Excerpt List Card Layout | Excerpt 一级卡片与右键菜单 |
| | `L-05.3` | Excerpt List Detail Layout | Excerpt 二级详情页（可滚动 Cover Summary + 吸顶工具栏/表头 + 表格） |
| | `L-05.4` | Search / Excerpt Toolbar Layout | 搜索框 + 结果统计/筛选触发器（Select Mode 下切换为批量选择横幅） |
| | `L-05.5` | Selection Action Overlay Layout | 表格底部居中浮层（已选计数 + `A`/`D`/`T` 快捷动作按钮） |
| | `L-05.6` | Search / Excerpt Table Layout | 固定表头 + 可滚动表体 + 列宽权重分配 |
| **3.6 Dialogs** | `L-06.1` | Edit Cover Dialog Layout | 编辑封面弹窗（预览/裁剪切换） |
| | `L-06.2` | Excerpt List Editor Dialog Layout | 新建/编辑摘录集弹窗（响应式双列/单列，Description 底边对齐规则） |
| | `L-06.3` | Rename Dialog Layout | 文件夹/单集文件重命名双列表单弹窗 |
| | `L-06.4` | WebDav Folder Dialog Layout | 添加 WebDAV 文件夹双列表单弹窗 |
| | `L-06.5` | Export to Anki Dialog Layout | 导出 Anki 交互式徽章拖拽与路径选择弹窗 |
| | `L-06.6` | Filter Dialog Layout | 多维筛选弹窗（Duration/Character/Language/Watch Status/Folder） |
| | `L-06.7` | Confirmation Dialog Layout | 二次确认弹窗 |
| | `L-06.8` | File Detail Dialog Layout | 文件详情（Get Info）弹窗 |
| | `L-06.9` | Task Panel Layout | 任务面板弹窗（Current / Completed / Incomplete 分段） |
| | `L-06.10` | Task Card Layout | 任务卡片（基准双行与第 3 行进度条/报错展开对齐） |

## 3.2 播放相关布局（位于 [`UI Layouts - Playback.md`](UI%20Layouts%20-%20Playback.md)）

| 分类 | 编号 | 布局名称 | 职责简述 |
| --- | --- | --- | --- |
| **3.7 Player** | `L-07.1` | Player Topbar Layout | 播放页渐变顶栏（红绿灯、返回、居中标题、Task/Settings 入口） |
| | `L-07.2` | Player Bottom Control Bar Layout | 播放页底栏（进度条区 + 左右播控按钮组） |
| | `L-07.3` | Player Progress Scrubber Layout | 进度条与悬停时间胶囊组合布局 |
| | `L-07.4` | Playback Feedback Overlay Layout | 播放舞台中央 HUD / 反馈层 |
| | `L-07.5` | Player Error Banner Layout | 播放窗口左上角多行红色报错横幅 |
| **3.8 Playback Overlay** | `L-08.1` | Playback Overlay Layout | 播放页内浮层容器（顶栏 + 内容区 + 底栏） |
| | `L-08.2` | Playback Topbar Layout | Playback Overlay 顶栏（Normal 与 Editing Collage 双形态） |
| | `L-08.3` | Playback Footer Layout | Playback Overlay 与 Command Panel 共用底栏（左侧计数 + 右侧快捷键按钮） |
| | `L-08.4` | Playback Current Layout | 当前字幕流视图（`Focus Cue Reel`） |
| | `L-08.5` | Playback Playlist Layout | 播放列表视图（字幕列表 `Cue Result Reel` 或视频网格） |
| | `L-08.6` | Playback Collage Editor Layout | 台词长截图双栏编辑器（左侧预览放大 + 右侧勾选字幕） |
| **3.9 Command Panel** | `L-09.1` | Command Panel Root Layout | 命令面板一级根视图（搜索框 + 选项列表 + 底栏） |
| | `L-09.2` | Command Panel Secondary Layout | 命令面板二级视图（返回头部 + Recent Videos / Excerpt Lists / Search Results） |
| | `L-09.3` | Command Panel Search Results Layout | 命令面板内搜索结果字幕流视图 |
