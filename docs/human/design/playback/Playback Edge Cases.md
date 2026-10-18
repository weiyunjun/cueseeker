# 说明

1. 本文档由人类维护，定义播放与工作台各界面在「本地物理文件缺失」以及「资料库变更导致内容失效」下的持久化设计与交互规则。

# 核心设计原则

## 1. 原则 1（非干扰性原则 / Non-disruption）
- **播放中移出资料库**：库变更发生时，若当前正在播放的条目被移出数据库，**继续播放、绝对不退出播放页**；立即切断向数据库写入该视频的播放进度、历史记录与默认轨道（杜绝孤儿数据）。
- **已展示界面数据冻结（Hold）**：库变更发生时，当前用户停留的界面、已打开的浮层（Playback Overlay、Command Panel、Search、Recent 模块、Library 二级、File 二级与子级视图、Excerpt 二级）**保持原内容不突变、不强制关闭、不闪烁刷新**（唯一例外：File 一级根目录作为文件夹管理入口，发生增删变更时即时刷新）。
- **内部标签切换不离开**：在同一个模块内部切换视图（如 Playback Overlay 内的 Current ↔ Playlist；Recent 内的 Recent Videos ↔ Recent Excerpt Lists），**维持冻结状态，不触发刷新**。

## 2. 原则 2（边界刷新与失效拦截原则 / Boundary Reconciliation）
- **离开又返回触发刷新**：关闭再打开浮层、面包屑回退、从二级返回一级、跨 Sidebar Tab 切换再切回、重新搜索等越界行为，**一律拉取最新数据库状态更新界面**。其中 Search 再次进入时，若期间仅发生过移除文件夹则只剔除失效结果，若发生过 Index 或 Add Folder 则按当前搜索词与已选 Filter 重新搜索。
- **未刷新前的失效拦截**：在尚未刷新的冻结界面上点击已移出库的失效项，**严格拦截核心操作**：
  - **尝试播放**：统一进入播放页面并拦截播放（黑屏、进度归零），顶栏弹出红色报错横幅 `This item is no longer in the library`（与现有的 Search、Excerpt 失效播放行为完全一致）。
  - **数据操作**（保存/移动/复制深链接等）：严格拦截操作，在当前工作区弹出对应 Toast 提示。

## 3. 原则 3（父子层级回退与实体失效展示规则）
- 当某个父级文件夹或摘录集被移出库，用户处于其子级视图并**触发返回该父级**时（例如 File 三级回退到二级文件夹，或处于已移出库的 Library / Excerpt 二级）：
  - **保留路径上下文**：面包屑或顶部导航**保留目标路径名称**（例如 `Home > 影视`），不突变跳级，维护用户心智中的空间位置。
  - **实体失效展示规范**：该实体已在库中不存在，**严禁渲染原本的详情骨架**（不显示封面图、标题、描述、表格等），**仅在顶栏下方展示纯净的提示文字**（例如：`该文件夹/摘录集已不在媒体库中`）。
  - **返回闭环**：用户在失效提示下再次返回上一级时，上一级界面根据最新数据库渲染（该失效实体卡片已被干净剔除）。

## 4. 原则 4（物理与逻辑解耦）
- **物理文件缺失（Part 1 规则）**：数据库记录正常，但本地文件被改名、删除或无法读取。入口不预检（无 Disabled 状态），进入播放器后处理：
  - **视频缺失**：舞台黑屏，不退播放页，弹出 5 秒红色报错条，数据库功能照常可用。
  - **字幕缺失**：视频正常播放，不渲染字幕，弹出 5 秒红色报错条。

---

# 交互流程图

## 1. Part 1：本地物理文件缺失与加载失败流

```mermaid
flowchart TD
    Start["用户在任意入口点击条目播放<br>(Search / Excerpt / Library / Recent / Command Panel)"] --> CheckEntry["入口行为: 不预检本地磁盘文件<br>(卡片无 Disabled 态，始终允许响应交互)"]
    CheckEntry --> OpenPlayer["进入播放页面 (Player Surface)"]
    OpenPlayer --> LoadMedia["并发读取并加载本地视频与字幕文件"]

    LoadMedia --> VideoBranch{"视频文件加载结果"}
    LoadMedia --> SubtitleBranch{"字幕文件加载结果"}

    VideoBranch -- "加载成功" --> VSuccess["视频画面正常解码渲染"]
    VideoBranch -- "加载失败<br>(文件被改名/删除/无权限)" --> VFail["视频失败处理:<br>1. 不退出播放页，保留标题与上下文<br>2. 停止上一个播放，舞台黑屏，进度归零<br>3. 停止写入播放进度与历史<br>4. 播放控制操作无效果，数据库功能照常可用<br>5. 弹出左上角红色报错条: Couldn't load the video file"]

    SubtitleBranch -- "加载成功" --> SSuccess["字幕正常渲染"]
    SubtitleBranch -- "加载失败<br>(文件丢失/损坏)" --> SFail["字幕失败处理:<br>1. 视频照常播放，不阻断任何操作<br>2. 仅不渲染该字幕<br>3. 弹出左上角红色报错条: Couldn't load the subtitle file"]

    VFail --> BannerRule{"红色报错条生命周期 (5秒倒计时)"}
    SFail --> BannerRule
    BannerRule --> DismissCond["满足以下任一条件时报错条立即消失:<br>1. 满 5 秒倒计时自然结束<br>2. 对应来源被替换 (切视频/切字幕)<br>3. 进入 Playback Overlay 界面<br>4. 退出播放页 (按 ESC / 返回按钮)"]
```

## 2. Part 2：播放中数据库变更与导航跳集流

```mermaid
flowchart TD
    DBMutate["数据库变更发生<br>(Add Folder / Index / Remove Folder)"] --> CheckCurrent{"当前播放的视频/台词<br>是否仍在数据库中?"}

    CheckCurrent -- "是 (有效项)" --> KeepPlaying["正常播放，继续跟踪播放历史与进度"]
    CheckCurrent -- "否 (已移出资料库 / Tombstone)" --> StalePlaying["原则 1 (非干扰性):<br>1. 视频继续播放，绝对不退出播放页<br>2. 立即切断播放历史、观看进度与默认轨道的写库<br>(杜绝残留孤儿数据)"]

    StalePlaying --> UserNavAction{"用户触发切集 / 自动连播<br>(上一个 / 下一个 / Auto Switch / 视频播完自动下一个)"}

    UserNavAction --> SearchNext["从当前播放列表中查找有效项<br>(过滤掉已离开数据库的失效条目)"]
    SearchNext --> FindValid{"是否存在至少一个有效项?"}

    FindValid -- "存在有效项" --> JumpValid["自动跳转至第一个有效项播放<br>(恢复正常播放状态与写库追踪)"]
    FindValid -- "无任何有效项" --> NoValidFeedback["播放页中央弹出 Playback Feedback (持续 1 秒):<br>- Search 来源: No Available Results<br>- Excerpt 来源: No Available Excerpts<br>- Library 来源: No Available Videos<br>(停留在当前界面，不强制退出)"]
```

## 3. Part 2：浮层与工作区界面（Overlay, Command Panel, Recent）的冻结与离开返回流

```mermaid
flowchart TD
    DBChange["数据库变更事件完成"] --> SurfaceCheck{"当前界面状态"}

    SurfaceCheck -- "处于浮层或特定模块内<br>(Playback Overlay / Command Panel / Recent 模块)" --> HoldState["原则 1 (数据冻结 Hold):<br>1. 保持当前显示内容不突变、不刷新、不关闭<br>2. 模块内子切换维持冻结:<br>   - Overlay 内 Current ↔ Playlist<br>   - Recent 内 Recent Videos ↔ Recent Excerpts<br>3. 数据库变更在后台待命 (awaiting reconcile)"]

    HoldState --> StaleClick{"用户在已冻结界面上点击已失效项"}
    StaleClick -- "尝试播放" --> InterceptPlay["进入播放页面并拦截播放:<br>1. 停止播放解码并置为失败 (黑屏，进度归零)<br>2. 顶栏弹出红色报错横幅: This item is no longer in the library<br>(与 Search / Excerpt 现有失效播放体验完全一致)"]
    StaleClick -- "数据操作 (保存/移动/复制链接)" --> InterceptAction["拦截操作，在当前界面弹出 Toast 提示条目不在媒体库中"]

    HoldState --> CrossBoundary{"原则 2: 发生离开又返回的行为"}
    CrossBoundary -- "Overlay 关闭后重新打开" --> ReconcileOverlay["拉取最新数据刷新:<br>- Current: 提示 This subtitle is no longer in the library<br>- Playlist: 剔除失效项 (全失效展示空提示)"]
    CrossBoundary -- "Command Panel 返回根页 / 重新唤出 / 重新搜索" --> ReconcileCP["拉取最新数据加载最新列表"]
    CrossBoundary -- "离开 Recent 切换至其他 Sidebar Tab 再切回" --> ReconcileRecent["重新拉取并渲染最新 Recent 列表 (剔除已移出视频)"]
```

## 4. Part 2：父子层级界面（File, Library, Excerpt）实体失效与回退流

```mermaid
flowchart TD
    DBMutate["数据库发生变更 (整目录 / 列表被移出库)"] --> ViewState{"用户所处视图"}

    ViewState -- "停留在该被移出实体的子级视图<br>(如 File 三级 Ave Mujica / Library 二级视频 / Excerpt 二级)" --> StayChild["原则 1: 保持当前视图不突变，不强制踢出"]

    StayChild --> NavBack{"用户触发返回该实体<br>(点击左上角返回 < / 点击面包屑中的父节点)"}

    NavBack --> ParentInvalidView["原则 3 (实体失效展示规则):<br>1. 面包屑/路径保留目标名称 (如 Home > 影视)<br>2. 严禁渲染原有骨架 (无封面、无标题、无描述、无表格/卡片)<br>3. 仅在顶栏下方展示纯净提示文字:<br>   - File: 该文件夹已不在媒体库中<br>   - Library: 该文件夹已不在媒体库中<br>   - Excerpt: 该列表已不在媒体库中"]

    ParentInvalidView --> BackToRoot{"用户在失效提示下，再次点击返回上一级<br>(如点击面包屑 Home / 返回总览)"}

    BackToRoot --> RootRefreshed["根级/一级界面拉取最新数据库刷新:<br>该失效实体已彻底从一级列表中移除"]

    ViewState -- "停留在尚未刷新的一级界面<br>(点击了已被移除的文件夹 / 摘录集卡片)" --> ClickStaleL1["直接进入对应的实体失效二级视图<br>(展示顶栏 + 提示文字，无常规骨架)"]
```