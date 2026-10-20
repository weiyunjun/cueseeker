# 说明

1. 本文档由人类维护，是 `/docs/human/design/` 的全局卡片盒根索引（Map of Content），用于快速定位各业务域的设计权威文档。
2. AI 在处理任何需求或讨论方案前，应先阅读本索引，**仅按需加载与当前任务直接相关的设计分册**，严禁盲目全量加载无关文档以节省上下文开销。

---

# 1. 目录结构与职责边界

## 1.1 `ui/` — 视觉、通用交互、组件与布局规范
定义应用「长什么样」以及「跨界面的通用交互状态机」。任何涉及界面视觉、布局、控件、指针或动效的任务，必须先进入 [`ui/UI Index.md`](ui/UI%20Index.md)。

| 文档路径 | 核心职责 |
| --- | --- |
| [`ui/UI Index.md`](ui/UI%20Index.md) | **UI 根入口**：定义 UI 子文档检索规则，提供全部组件（`C-xx`）与布局（`L-xx`）的唯一编号速查表。 |
| [`ui/UI Design Rules.md`](ui/UI%20Design%20Rules.md) | **通用视觉与度量公理**：全局无按下视觉效果、选中态组件白名单、基于 Cap 顶与可见边界的等距计算基准、Light/Dark 明暗表面层级、页面与网格边距法则、封面防闪烁规则。 |
| [`ui/UI Interaction Rules.md`](ui/UI%20Interaction%20Rules.md) | **通用交互与输入状态机**：界面 Z 轴层级与输入屏蔽、菜单模态、Hover 与选中移动条件、焦点与 Tab 规则、快捷键录入与冲突、全屏规则、Player UI 与指针显隐状态机、鼠标指针形状优先级、无障碍交互预留。 |
| [`ui/UI Tokens.md`](ui/UI%20Tokens.md) | **设计变量（Core Tokens）**：颜色、字体与文本装饰、高度与尺寸、间距与内边距、圆角与阴影、渐变与动效参数。 |
| [`ui/UI Components - Controls.md`](ui/UI%20Components%20-%20Controls.md) | **基础交互控件（`C-01` ~ `C-07`）**：Inputs、Selection Controls、Buttons、Menus、Navigation（含 Breadcrumb）、Tables、Scrollbars。 |
| [`ui/UI Components - Domain.md`](ui/UI%20Components%20-%20Domain.md) | **业务与反馈组件（`C-08` ~ `C-13`）**：Data Display（Badges/Tag/Indicators/Titles/Keycap）、Feedback（Toast/Empty State/Spinner/Player Error）、Dialogs、Media（Cover/Cover Summary/Media Card）、Player Controls、Playback Content。 |
| [`ui/UI Layouts - Workbench.md`](ui/UI%20Layouts%20-%20Workbench.md) | **工作台与对话框布局（`L-01` ~ `L-06`）**：App Shell、Settings、Recent、Library and File、Search and Excerpt、Dialogs（含 Task Panel）。 |
| [`ui/UI Layouts - Playback.md`](ui/UI%20Layouts%20-%20Playback.md) | **播放相关布局（`L-07` ~ `L-09`）**：Player、Playback Overlay（Current / Playlist / Collage Editor）、Command Panel。 |
| [`ui/Icon Registry.md`](ui/Icon%20Registry.md) | **图标注册表**：Phosphor 图标制作规格、尺寸与线宽映射表、全应用图标名录与使用位置。 |
| [`ui/Toast Usage Registry.md`](ui/Toast%20Usage%20Registry.md) | **Toast 与 HUD 注册表**：全场景 Toast、播放轻提示、报错提示与常规 HUD 的多语言文案、图标、持续时长与 Scenario ID。 |

---

## 1.2 `data/` — 数据、索引与字幕解析底层规则
定义媒体库「数据如何入库、匹配、解析与保持永久身份」。

| 文档路径 | 核心职责 |
| --- | --- |
| [`data/Data.md`](data/Data.md) | **Index 流程与永久身份**：视频与字幕扩展名匹配优先级、增量检测、核心数据发布、视频元数据与自动封面策略、Display Title 编号规则、失败回滚机制，以及 `LibraryID / VideoID / SubtitleID / CueID / ExcerptID` 永久身份与路径分离规则。 |
| [`data/Cue Parsing.md`](data/Cue%20Parsing.md) | **字幕解析与变化检测**：ASS 与非 ASS 字幕清洗、200ms 过滤与去重、Cue Group 划分规则，以及重索引时基于四要素/二要素的 `CueID` 继承与 Tombstone 变化检测流程。 |

---

## 1.3 `workbench/` — 工作台核心业务规则
定义工作台各业务模块的「功能逻辑、数据排序、筛选与导出流转」（逐步补齐中）。

| 文档路径 | 核心职责 |
| --- | --- |
| [`workbench/Search and Filter.md`](workbench/Search%20and%20Filter.md) | **搜索与筛选业务**：全文检索匹配与字符归一化、搜索排序与高亮、Cue Group 聚合展示、Filter 多维筛选交并集与计数、表格批量选择操作业务。 |
| [`workbench/Library and File.md`](workbench/Library%20and%20File.md) | **媒体库、文件与任务队列业务**：观看状态与进度流转、封面裁剪与缓存策略、App 内文件夹/单集联动重命名、WebDAV 与 SMB 挂载同步、后台任务队列并发互斥与取消规则。 |
| [`workbench/Excerpt and Export.md`](workbench/Excerpt%20and%20Export.md) | **摘录、长截图与 Anki 导出业务**：Excerpt 列表增删改与跨列表移动/复制去重、Collage 长截图帧提取与拼接规则、Export to Anki 字段映射与导出生成逻辑。 |
| [`workbench/Settings and Localization.md`](workbench/Settings%20and%20Localization.md) | **设置项与多语言规范**：各设置项默认值、持久化与生效边界，以及简/繁/英/日多语言词条对照规范。 |

---

## 1.4 `playback/` — 播放器、浮层与外设业务规则
定义视频播放期间的「播控行为、边界异常恢复、快捷面板与外设控制」。

| 文档路径 | 核心职责 |
| --- | --- |
| [`playback/Playback Core.md`](playback/Playback%20Core.md) | **播放器核心行为（待补充）**：正常态时间戳跳转（Seek）、Playlist 连播与单句自动暂停（Auto Stop）、画面字幕渲染与样式覆盖、音轨与字幕轨切换、URL Scheme 唤起播放。 |
| [`playback/Playback Edge Cases.md`](playback/Playback%20Edge%20Cases.md) | **播放与工作台边界异常流**：本地物理文件缺失/损坏处理、播放中数据库变更不中断原则、已展示界面数据冻结（Hold）与越界返回刷新（Reconcile）、父子层级实体失效回退展示。 |
| [`playback/Command Panel.md`](playback/Command%20Panel.md) | **Command Panel 业务规则**：默认条目、面板内搜索与 Deep Link 搜索行为、Filter 继承与预填逻辑。 |
| [`playback/Controller.md`](playback/Controller.md) | **手柄控制规则**：DS5 手柄在播放页、Playback Overlay、Command Panel 与 Collage 界面的键位映射、摇杆连发与死区逻辑。 |
