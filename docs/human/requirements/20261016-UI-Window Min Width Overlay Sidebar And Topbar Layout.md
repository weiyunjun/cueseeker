# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Interaction Rules.md`

# 需求描述

1. **窗口与工作台内容区最小宽度上调为 `600px`**：
   - App 主窗口最小宽度（`--min-width-window` / `AppShellLayout.minimumWindowWidth`）从 `480px` 调整为 **`600px`**（最小高度 `--min-height-window` 保持 `560px` 不变）。
   - Workbench 页面内容最小宽度 Token `--min-width-workbench-page-content`（`AppShellLayout.pageContentMinimumWidth`）同步从 `480px` 调整为 **`600px`**。
   - Sidebar 宽度 `--width-app-sidebar` 保持 `240px` 不变，因此 Sidebar 自动收起与模式切换的窗口宽度阈值（`sidebarAutoCollapseWindowWidth = pageContentMinimumWidth + sidebarWidth`）从 `720px` 更新为 **`840px`**（`600 + 240`）。

2. **窄窗口（`< 840px`）下 Sidebar 改为全高 Overlay 浮层（原地淡入淡出），并彻底移除底部横向滚动条**：
   - **并排模式（Docked，窗口宽度 `>= 840px`）**：保持现有并排推挤布局，Sidebar 占左侧 `240px`，右侧内容区占 `窗口宽度 - 240px`（`>= 600px`），鼠标移出 Sidebar 不自动收起。
   - **自动收起触发**：当窗口宽度从 `>= 840px` 缩窄至 `< 840px` 时（仅在 Workbench 可见时判定，退出播放页时重新判定一次），Sidebar 自动收起；在 `< 840px` 期间，右侧内容区始终占满 `100%` 窗口宽度（`>= 600px`），不再被 Sidebar 推挤压缩。
   - **浮层模式（Overlay，窗口宽度 `< 840px` 且手动展开 Sidebar）**：
     - 在窗口宽度 `< 840px` 时点击左上角 Sidebar 切换按钮，Sidebar 以 **Overlay 浮层** 形式在窗口左侧全高显现（宽度 `--width-app-sidebar: 240px`，高度 `100%` 从窗口最顶边 `y = 0` 到最底边，覆盖在 Workbench 顶栏与右侧页面内容之上；左上角原生红绿灯与 Sidebar 切换按钮保持在原位可交互）。
     - **转场动效（纯透明度淡入淡出）**：Overlay Sidebar 严禁使用水平位移滑入动画（避免滑入期间几何盒模型移动与鼠标坐标冲突），统一采用**原地纯透明度淡入淡出（`.transition(.opacity)`，时长 `--duration-sidebar-motion: 0.18s`）**；从展开第 0 帧起几何边界即固定在 `0 <= x <= 240`，并在收起淡出期间立即禁用命中测试（`allowsHitTesting(false)`）。
     - Overlay Sidebar 右侧边缘绘制 `1px` 分隔线（`--width-border-hairline` + `--color-border-muted`）并投射浮层阴影（`--shadow-popover`）。
     - **收起条件与防误触保护**：
       1. **入场动画冷却保护（Cooldown Guard）**：点击左上角按钮展开 Overlay Sidebar 的淡入动画周期（`--duration-sidebar-motion: 0.18s`）内，不响应鼠标微移触发的自动收起，防止点击按钮后手部微颤导致浮层闪退。
       2. **鼠标向右越界自动收起**：仅当鼠标指针在窗口内**向右移出 Overlay Sidebar 右边界（`locationInWindow.x > 240`）**时，Overlay Sidebar 自动淡出收起；在左上角按钮附近向上微移或触碰窗口顶边但仍处于 `x <= 240` 水平范围内时，不触发收起。
       3. **手动点击按钮收起**：再次点击左上角 Sidebar 切换按钮时，Overlay Sidebar 立即淡出收起。
   - **彻底移除底部横向滚动条机制**：由于窗口最小宽度为 `600px` 且窄窗口下 Sidebar 改为不占布局宽度的 Overlay 浮层，右侧区域宽度恒 `>= 600px`。移除 Workbench 各页面与顶栏的底部横向滚动条及 `pageHorizontalScrollOffset` 横向滚动偏移同步逻辑，遵循奥卡姆剃刀原则清理相关冗余状态与代码。

3. **顶栏与弹窗标题栏的 Segmented Control 缩放防遮挡布局（最小间距 `x = --spacing-3`）**：
   - **适用范围**：
     1. **Workbench - Recent 界面顶栏**（左侧 `Recent` 标题、中间 `Videos / Excerpt Lists`、右侧工具按钮）；
     2. **Task 弹窗顶栏**（左侧 `Task` 标题、中间 `Current / Completed / Incomplete`、右侧关闭按钮）；
     3. **Playback Overlay 顶栏**（左侧 `<` 返回按钮、中间 `Current / Playlist`、右侧操作按钮组）。
   - **自适应居中与夹逼偏移规则**：
     - 设所在行容器总宽为 `W`，左侧内容区（含左侧边距与标题/返回按钮）自然宽度为 `L_natural`，中间 `Segmented Control` 固定自然宽度为 `C`，右侧按钮区（含右侧边距）宽度为 `R`，最小安全间距 `x = --spacing-3`（`12px`）。
     - **默认居中**：当居中放置的 `Segmented Control` 与左、右两侧内容的距离均 `>= 12px` 时，`Segmented Control` 严格位于容器水平中心（左边缘 `x = (W - C) / 2`）。
     - **单侧触碰时优先压缩另一侧间距**：当窗口缩窄，使居中的 `Segmented Control` 先与某一侧（例如左侧标题，或 Playback Overlay 的右侧按钮组）距离达到 `12px`，而另一侧距离仍 `> 12px` 时，`Segmented Control` **不得遮挡左侧标题或右侧按钮，也不立即截断左侧标题**，而是保持与先触碰一侧 `12px` 的距离，向另一侧推移（优先缩减它与另一侧的剩余距离）。
     - **双侧均达 `12px` 后截断左侧标题**：当窗口继续缩窄，直到 `Segmented Control` 与左侧内容、右侧按钮的距离**同时达到 `12px`**（即 `L_natural + C + R + 24 > W`）时，`Segmented Control` 锁死在距右侧按钮 `12px` 处（左边缘 `W - R - 12 - C`），此时开始压缩左侧标题文字的可用宽度（最大宽度 `W - R - C - 24`），超出部分以尾部省略号 `...` 截断（截断时按既有规则支持悬停显示完整标题 Tooltip）。

4. **Playback Overlay 与 Collage 顶栏补齐双击缩放窗口与拖拽移动窗口**：
   - **问题背景**：当前 `PlaybackOverlayTopBar`（由 `Playback Overlay` 的 `Current` / `Playlist` 界面与 `Collage` 编辑界面共用）背景未挂载 `TitlebarBackgroundView`（`DraggableNSView`），且下层被 `PlaybackSubtitleFocusPointerShield` 拦截，导致在顶栏双击无法缩放窗口、按住无法拖拽窗口。
   - **修复规则**：
     - 在 `PlaybackOverlayTopBar` 背景挂载 `TitlebarBackgroundView`，使其与 Workbench 顶栏（`AppTopbarLayout`）及 Playback 播放页顶栏（`LiquidGlassVideoTopBar`）行为完全一致。
     - 凡是在顶栏（`54px` 高度内）单击无交互效果的位置（包括左右空白区、Collage 顶栏居中的静态标题文字 `Editing Collage…`），均支持**双击缩放 App 窗口**（遵循系统 `AppleActionOnDoubleClick` 设置）与**按住左键拖拽移动窗口**。
     - 顶栏内的可交互控件（返回按钮、Segmented Control、Collage 按钮、Task/Settings 按钮）保持原有点击交互。
     - `Workbench` 与 `Playback` 播放页顶栏维持现有行为不变（`Playback` 播放页在顶栏自动隐藏期间，点击顶部区域仍保持单击唤醒/播放暂停，仅在顶栏显示时支持双击缩放与拖拽）。

5. **消除硬编码与设计令牌（Design Tokens）统一收口**：
   - **尺寸与动效 Token 收口至 `WorkbenchControlMetrics`**：
     - `--width-window-default: 1000px`（`redesignWindowDefaultWidth`）
     - `--min-width-window: 600px` / `--min-width-workbench-page-content: 600px`（`redesignWindowMinimumWidth`）
     - `--min-height-window: 560px`（`redesignWindowMinimumHeight`）
     - `--duration-sidebar-motion: 0.18s`（`redesignSidebarMotionDuration`）
     - `--width-border-hairline: 1px`（`redesignBorderHairlineWidth`，用于 Overlay Sidebar 右侧分隔线等 `1px` 细边）
     - `AppShellLayout.modeControlsOuterPadding` 统一引用 `WorkbenchControlMetrics.redesignSpacing3`（`12px`），移除字面量硬编码。
   - **色彩与层级常量收口**：
     - `ContentRootView` 根窗口背景色统一使用 `WorkbenchRedesignColors.bgCanvas`，移除硬编码 RGB `Color(red: 0.955, green: 0.955, blue: 0.95)`。
     - `ContentRootView` 顶栏、弹窗、Toast、Tooltip 的 `zIndex` 统一收口为具名层级常量，移除魔法数字 `3 / 200 / 300 / 400`。

6. **设计文档同步**：
   - 待全部改动验收通过后，同步更新 `UI Tokens.md`、`UI Layouts - Workbench.md`、`UI Layouts - Playback.md` 与 `UI Interaction Rules.md`。

# 验收标准

1. App 主窗口最小宽度为 `600px`；窗口宽度 `>= 840px` 时 Sidebar 为并排推挤模式；窗口从 `>= 840px` 缩窄至 `< 840px` 时 Sidebar 自动收起，右侧内容区始终占满窗口宽度且无底部横向滚动条。
2. 窗口宽度在 `600px ~ 839px` 之间时，点击左上角按钮展开的 Sidebar 为全高 Overlay 浮层，采用原地纯透明度淡入淡出动效（无水平滑入位移）；点击按钮后向上微移鼠标不会误触发收起；当鼠标向右移出 `240px` Sidebar 区域或再次点击左上角按钮时，Overlay Sidebar 立即淡出收起。
3. 在 Workbench Recent、Task 弹窗、Playback Overlay 界面缩放窗口时，Segmented Control 默认水平居中；空间缩小时优先向空余一侧偏移（不遮挡标题或按钮），直到左右两侧间距均缩至 `12px`（`--spacing-3`）后，左侧标题才开始以 `...` 截断。
4. 在 Playback Overlay（Current / Playlist）和 Collage 界面，双击顶栏空白处或 Collage 静态标题可正常缩放窗口，按住拖拽可移动窗口；Workbench 与 Playback 顶栏原有缩放与拖拽行为正常。
5. 相关窗口尺寸、动效时长、边框宽度、画布底色与层级常量均已通过语义化 Token 收口，无魔法数字硬编码。