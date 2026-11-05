# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/playback/Controller.md`

# 需求描述

1. **`Playback Feedback`（`C-09.5`）与 `Toast`（`C-09.1`）的职责与场景拆分**：
   - **`Playback Feedback`（`C-09.5`）**：仅用于**播放器 UI（视频舞台）**上的操作与状态反馈（播放/暂停、自动暂停、快进/快退、音量与静音、倍速、字幕开关与切换、全屏切换、播放列表上/下一条导航与边界提示、视频截图复制以及加载状态 `Loading`）。
   - **`Toast`（`C-09.1`）**：统一用于除播放器 UI 之外的所有界面，包括 **Workbench**、**Playback Overlay**（`Current`、`Playlist`、`Collage`）与 **Command Panel** 中触发的所有复制、导出、摘录保存/移动/创建副本、无字幕 `No Subtitle` 及边界拦截提示。
   - **取消从 Playback Overlay 播放时的 `Play` 反馈**：在 Playback Overlay（`Current` 或 `Playlist`）中执行 `Play` 关闭浮层并返回视频播放时，不再显示 `Play` 的 `Playback Feedback`（仅在播放器画面内直接切换播放/暂停时显示 `Play` / `Pause` 反馈）。

2. **播放器 UI 左上角 `Playback Feedback`（`C-09.5` / `L-07.4`）位置、样式与动效**：
   - **左上角位置与红色报错框共存**：位置由播放舞台正中改为窗口左上角，与 `C-09.6 Player Error Banner`（`L-07.5`）同轴左对齐（距顶 `--height-app-topbar` + `--spacing-3` = `66px`，距左 `--spacing-6` = `24px`）。当左上角存在红色报错框（含视频与字幕同时报错的 1~2 行状态）时，`Playback Feedback` 显示在红色报错框正下方，间距 `--spacing-3`（`12px`）；红色报错框自身样式与规则保持不变。
   - **无淡入淡出与单槽直接替换**：取消进出场淡入淡出及缩放过渡动画（`Motion: None`），触发时直接显示、到时直接消失；新反馈直接原位替换旧反馈（连续快进/快退的秒数累加规则保持不变）。
   - **无渐变固定圆角灰色遮罩样式（Light / Dark 统一）**：
     - 容器背景复用 `--color-player-topbar-gradient-start`（`rgba(18, 18, 24, 0.66)`，无渐变、无毛玻璃、无边框 `Border: None`、无阴影 `Shadow: None`），圆角 `--radius-playback-feedback` 修改为 `10px`，水平内边距 `--padding-control-x`（`14px`），垂直内边距 `--spacing-2`（`8px`），图文间距 `--spacing-3`（`12px`），最大宽度 `--width-playback-feedback-max`（`520px`），移除原 `--height-playback-feedback`（`52px`）最小高度限制。
     - 图标尺寸 `--size-playback-feedback-icon` 修改为 `23px`，颜色 `--color-player-text-primary`（`rgba(255, 255, 255, 0.94)`），与第一行文字垂直居中。
     - 文字字号 `--font-size-playback-feedback`（`18px`），新增行高 `--line-height-playback-feedback`（`26px`），字重 `--font-weight-control`（`500`），颜色 `--color-player-text-primary`，数字等宽，超出最大宽度自动换行并左对齐。
   - **加载状态（`Spinner` + 文案）统一样式**：
     - 加载状态同样移至左上角 `Playback Feedback` 槽位，并增加文案 `Loading` / `加载中` / `加載中`，与普通 `Playback Feedback` 完全统一样式（左侧图标槽位放置旋转的 `C-09.4 Spinner`，直径统一复用 `--size-playback-feedback-icon: 23px`，移除 `--size-playback-feedback-spinner` 及无文字正方形容器特殊处理；右侧显示 `Loading` 文案）。

3. **右下角 `Toast`（`C-09.1` / `L-01.4`）位置、明暗模式样式与折叠叠层**：
   - **三类界面的右下角位置与底栏避让**：
     - **Workbench**：位于窗口右下角，距右 `--spacing-6`（`24px`），距底 `--spacing-6`（`24px`）。
     - **Playback Overlay**：位于窗口右下角且不遮挡底部 `Playback Footer`，距右 `--spacing-8`（`32px`），底部位于 `Playback Footer` 上沿上方 `--spacing-3`（`12px`）。
     - **Command Panel**：位于 Command Panel 框体内部右下角且不遮挡框内底部 `Playback Footer`，距框体右边缘 `--spacing-5`（`20px`），底部位于框内 `Playback Footer` 上沿上方 `--spacing-3`（`12px`）。
   - **固定宽度、换行对齐与明暗模式配色**：
     - 宽度固定为 `--width-toast`（`260px`，替代原 `--width-toast-max: 400px`），新增圆角 `--radius-toast`（`10px`），水平内边距 `--padding-control-x`（`14px`），垂直内边距 `--spacing-2`（`8px`），图文间距 `--spacing-2`（`8px`）。
     - 区分 Light Mode 与 Dark Mode：背景色 `--color-toast-bg` 修改为 Light `#FFFFFF`、Dark `#36363B`（同 `--color-bg-popover`，100% 不透明、无毛玻璃）；边框色 `--color-toast-border` 修改为 Light `#E5E7EB`、Dark `#4A4A52`（同 `--color-border-control`，`1px` 实线）；阴影复用 `--shadow-popover`；文字与图标颜色统一复用 `--color-text-primary`（Light `#1F1F1F`、Dark `#E4E4E4`）。原 `C-08.6 Tooltip` 使用的黑底微透背景与描边解耦为 `--color-tooltip-bg` 与 `--color-tooltip-border`，保持 `Tooltip` 外观不变。
     - 图标尺寸 `--size-toast-icon` 修改为 `16px`；文字字号 `--font-size-toast` 修改为 `14px`，新增行高 `--line-height-toast`（`20px`），字重 `--font-weight-control`（`500`）。允许文本自动换行，换行发生时左侧图标相对第一行文字保持垂直居中对齐（图标下方自然留白）。
   - **最多 3 层折叠叠放与从下往上动效**：
     - 连续触发同一操作不再合并重置计时，而是作为新 Toast 压入叠层；最多同时显示 **3 层**（超出 3 层时最早一层移除）。
     - 仅最前方第 1 层显示完整图标与文字；后方第 2、3 层保持与第 1 层相同的宽高与 100% 不透明背景边框、隐藏内部图文，并在顶部向上露出折叠层边缘（新增递进垂直偏移 `--offset-toast-stack: 9px`，第 2 层 `-9px`、第 3 层 `-18px`；新增递进缩放步长 `--scale-toast-stack-step: 0.05`，第 2 层 `0.95`、第 3 层 `0.90`）。
     - 新 Toast 从下方 `--distance-toast-motion`（新增，`18px`）处向上滑入，后方旧卡片同步向上推挤并缩小（时长 `--duration-toast-motion` 修改为 `0.36s`，缓动保持 `--easing-toast-motion: cubic-bezier(0.22, 1, 0.36, 1)`）。

# 验收标准

1. **播放器 UI 左上角 `Playback Feedback`**：
   - 在播放画面触发播放/暂停、快进/快退、音量、倍速、字幕开关、全屏、上/下一条导航、截图复制等操作时，反馈均出现在窗口左上角（顶栏下方 `12px`、距左 `24px`），采用无渐变固定圆角灰色遮罩（`rgba(18, 18, 24, 0.66)`，圆角 `10px`，无边框无阴影）与纯白无描边图标文字（图标 `23px`、字号 `18px`），Light 与 Dark 下样式一致。
   - 反馈出现与消失均无淡入淡出动画，新反馈直接替换旧反馈；当左上角存在 1 条或 2 条红色报错信息时，正常反馈与加载状态均显示在红色报错框正下方 `12px` 处。
   - 触发加载等待超时后，左上角反馈槽位显示左侧 `23px` 旋转 Spinner + 右侧 `Loading` / `加载中` / `加載中` 文案，外观与普通 `Playback Feedback` 完全一致；从 Playback Overlay 点击 `Play` 或按回车返回播放时不再弹出 `Play` 反馈。
2. **右下角 `Toast`（Workbench / Playback Overlay / Command Panel）**：
   - 在 Workbench、Playback Overlay（`Current`、`Playlist`、`Collage`）与 Command Panel 中触发复制、导出、保存摘录、无字幕或拦截提示时，统一显示为右下角固定 `260px` 宽度的 `Toast`；其中 Playback Overlay 的 Toast 位于底部栏上方 `12px`（距右 `32px`），Command Panel 的 Toast 位于弹框内部右下角底部栏上方 `12px`（距框右边缘 `20px`），均不遮挡底部按钮。
   - Light Mode 下为白底黑字黑图标（`#FFFFFF` 底、`#E5E7EB` 边框、`#1F1F1F` 图文），Dark Mode 下为深灰浮层底白字白图标（`#36363B` 底、`#4A4A52` 边框、`#E4E4E4` 图文），且 `Tooltip` 仍保持原有黑底白字微透样式不变。
   - 文案超出一行时自动换行，左侧 `16px` 图标始终与第一行文字垂直居中对齐；连续触发多条（含连续触发同一操作）时，新 Toast 从下往上滑入，旧 Toast 向上推挤缩放，最多显示 3 层折叠边缘且各层保持 100% 不透明。