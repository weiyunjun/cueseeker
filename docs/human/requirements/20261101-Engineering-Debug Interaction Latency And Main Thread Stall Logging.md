# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **适用范围、编译隔离与零行为变更**：
   - 仅在 **Debug 构建**中启用交互耗时埋点与主线程卡顿监控，统一以 `DEBUG` 级别写入既有本地调试日志文件（`~/Library/Application Support/CueSeeker/logs/debug/cueseeker-YYYY-MM-DD.log`）。
   - **Release 构建**不执行上述埋点测量与日志写入；单元测试与集成测试运行期间不写入磁盘日志。
   - 本需求仅增加诊断日志，不改变任何既有界面视觉效果、交互行为或数据加载策略。

2. **界面跳转与视图切换耗时埋点**：
   - **覆盖范围**：
     - **Workbench 导航与页面切换**：左侧导航栏 5 个一级入口切换（`Search`、`Recent`、`Library`、`File`、`Excerpt`）、左侧导航栏展开/收起（`Sidebar Toggle`）、顶栏前进/后退（`Back` / `Forward`）、`Recent` 顶栏分段标签切换（`Videos` / `Excerpt Lists`）、`Library` 一级文件夹卡片进入二级详情页、`File` 一/二/三级目录卡片下钻与面包屑（`Breadcrumb`）回退、`Excerpt` 一级卡片进入二级详情页、`Search` 与 `Excerpt` 表格进出批量选择模式（`Select Mode`）。
     - **页面内按钮与内容直接触发的跳转**：`Recent` 视频/摘录卡片点击播放、`Library` 二级详情页顶部 `Cover Summary` 的 `Play` / `Resume` 与 `View in File` 按钮、`Library` 二级详情页剧集卡片点击播放、`Excerpt` 二级详情页顶部 `Cover Summary` 的 `Play` / `Resume` 按钮、`Search` 与 `Excerpt` 表格有效台词点击播放、播放页顶栏返回 Workbench、播放页底栏上下集/上下条切换与全屏进入/退出。
     - **Playback Overlay 全链路**：打开与关闭 `Playback Overlay`、顶栏 `Current` 与 `Playlist`（`Subtitle Playlist` / `Video Playlist`）标签切换、顶栏 `Collage` 按钮进出 `Editing Collage` 长截图编辑器、点击左侧预览截图组定位右侧台词、浮层内触发播放（双击 / 回车 / 底栏 `Play`）。
     - **Command Panel 全链路**：打开与关闭 `Command Panel`、一级根视图进入二级视图（`Search Results`、`Recent Videos`、`Recent Excerpt Lists`）、二级视图返回一级根视图、二级视图内触发打开/播放（点击 / 回车 / 底栏 `Open` 或 `Play`）。
     - **Settings 独立设置窗口**：打开设置窗口，以及左侧 6 个分类（`General`、`Play`、`Shortcuts`、`Subtitle`、`Maintenance`、`Developer`）切换。
   - **记录内容**：来源与目标视图标识、触发方式、前置同步准备耗时（如播放状态挂起与播放进度落盘）、目标视图容器上屏等待耗时（从触发到旧画面切换为新视图框体的时间）、业务数据读取耗时、首屏封面预解码耗时（含首屏封面总数、缓存命中数与新解码数）、首帧渲染耗时及总耗时。

3. **弹出菜单与浮层面板耗时埋点**：
   - **覆盖范围**：
     - 全部封面卡片（`Recent`、`Library` 一/二级、`Excerpt` 一级、`Playback Overlay` 视频播放列表、`Command Panel` 二级）与 `Library` / `Excerpt` 二级页顶部 `Cover Summary` 的右键菜单及 `...` 按钮菜单；
     - `File` 界面顶部 `Add Folder` 下拉菜单、各级文件夹与视频/字幕行右键菜单及 `...` 按钮菜单；
     - `Task` 任务面板卡片右键菜单及 `...` 按钮菜单；
     - `Search` / `Excerpt` 表格行右键菜单、批量选择模式工具栏按钮弹出的菜单、`Playback Overlay` 与 `Command Panel` 底栏 `Save to Excerpt List` 按钮菜单、目标摘录集二级菜单（`Excerpt Destination Submenu`）、选中文字右键菜单；
     - 各页面与 `Command Panel` 二级 `Search Results` 的排序（`Sort`）下拉菜单、`Export to Anki` 字段添加（`+`）下拉菜单、`File Info` 顶部配对文件切换下拉菜单、`Settings` 中的下拉菜单（`Language`、`Font`）与颜色预设面板（`Color Well Preset Popover`）；
     - 播放页底栏字幕菜单（`Player Subtitle Menu`）、倍速菜单（`Player Speed Menu`）、更多菜单（`Player More Menu`）及音轨二级菜单（`Audio Track Submenu`）。
   - **记录内容**：菜单/浮层标识、触发方式（按钮点击 / 右键 / 快捷键 / 悬停展开）、菜单项数据准备与弹出几何位置测量耗时、下层画面冻结与菜单首帧上屏耗时、总打开耗时，以及点击菜单项触发动作的响应耗时。

4. **弹出 Dialog 界面与弹窗内切换耗时埋点**：
   - **覆盖范围**：
     - 全部 10 类窗口内对话框：`Edit Cover`（含打开弹窗及选图后切换至裁剪画布 `Cover Crop Editor`）、`Excerpt List Editor`、`Rename`、`WebDAV / SMB / FTP / NFS Folder`（含打开弹窗，以及弹窗内 Step 1 点击 `Connect` 进入 Step 2 目录浏览、Step 2 点击子目录进入下一层 / 点击面包屑回退 / 点击 `Back` 返回 Step 1）、`Export to Anki`、`Filter`（从 `Search`、`Excerpt` 二级或 `Command Panel` 二级触发）、`Confirmation`、`File Detail`（`Folder Info` / `File Info`，含打开前读取媒体元数据及弹窗内切换配对文件）、`Task Panel`（含打开面板及顶部 `Current` / `Completed` / `Incomplete` 标签切换）、`Task Detail`（从任务菜单或 `File` 顶部状态栏文字点击触发）；
     - 系统原生文件选择框（添加本地文件夹、选择封面图片、选择导出目录）的唤起响应耗时。
   - **记录内容**：对话框或弹窗内切换标识、触发入口、从触发到弹窗状态开启的前置数据准备耗时、弹窗首帧排版与上屏耗时、入场动画期间的流畅度指标（动画期间实际渲染帧数与最大单帧间隔耗时）及总耗时。

5. **主线程卡顿兜底监控**：
   - 在 Debug 构建运行期间，持续监测主线程事件循环单次繁忙或帧间隔耗时；当主线程单次阻塞或间隔达到或超过 `32ms` 时，自动写入一条慢操作日志，记录阻塞时长、主线程阶段转换以及最近一次触发的用户交互动作标识与距今耗时。

# 验收标准

1. **全场景埋点覆盖完整**：在 Debug 构建下按日常流程操作上述全部页面跳转、页面内跳转按钮、`Playback Overlay`、`Command Panel`、独立 `Settings` 窗口、全部右键/下拉/二级菜单与颜色面板、全部 10 类窗口内对话框（含弹窗内分步/标签切换）及系统文件框，对应操作均在 `logs/debug/cueseeker-YYYY-MM-DD.log` 中实时输出结构化阶段耗时日志。
2. **等待与渲染阶段可区分**：对于包含封面网格或异步准备的界面切换（如从 `Library` 一级点击卡片进入二级、切换 `Playback Overlay` 的 `Playlist` 标签、从 `Command Panel` 一级进入 `Recent Videos` / `Recent Excerpt Lists`、打开 `Playback Overlay` 等），日志能够明确区分前置同步耗时、数据读取耗时、封面预解码耗时（含缓存命中与未命中数量）、视图框体切换等待耗时与首帧渲染耗时。
3. **主线程卡顿自动捕获**：当主线程发生 `≥ 32ms` 的耗时阻塞时，调试日志自动记录阻塞时长与最近触发的交互动作上下文。
4. **Release 隔离与无副作用**：Release 构建不输出上述调试埋点与主线程监控日志；既有界面视觉、交互行为与自动化测试（`swift test`）保持全部通过且测试无磁盘日志残留。