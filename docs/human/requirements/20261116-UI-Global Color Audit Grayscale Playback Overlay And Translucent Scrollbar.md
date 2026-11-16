# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **全局去蓝偏色与零新增 Token 约束（禁止硬编码与私自特殊实现）**：
   - 本次改动**新增 `0` 个 Token，更新 `23` 个既有颜色 Token，并对齐 `3` 处既有组件/容器表面引用**；所有视觉调整均统一通过既有设计 Token 与组件规则表达，严禁硬编码色值或编写私自特殊实现。

2. **工作台表格选中行、行内操作按钮与字幕状态指示器配色（`UI Tokens.md`、`C-03.2`、`C-06.3`、`C-08.5`）**：
   - 减轻工作台表格勾选行底色的厚重感与冷蓝偏色，并将卡片/表格行右侧 `dots-three` 按钮调整为纯中性灰与半透明白阶梯：
     - `--color-table-row-selected`：Light `#F3F4F6`；Dark `#2B2B31`
     - `--color-row-selected`：Light `#E5E7EB`；Dark `rgba(255,255,255,0.08)`
     - `--color-row-action-bg-pressed`：Light `#D1D5DB`；Dark `rgba(255,255,255,0.14)`
   - `C-08.5 Status Indicator` 下的表格行内 `Cue State Indicator`（`Content Changed` 与 `Unavailable`）悬停底色由 `--color-table-row-selected` 统一改为 **`--color-row-selected`**，使其在普通行、悬停行与已勾选行内均具备清晰辨识度，并与同行右侧 `dots-three` 按钮悬停层级一致。

3. **`Playback Overlay` 纯中性灰度可读性配色体系（`UI Design Rules.md`、`UI Tokens.md`、`C-13.1` ~ `C-13.4`、`L-08.1`）**：
   - 采用零色偏纯中性灰阶（清透浅灰 `#F4F4F4` / 沉静碳黑 `#161616`）承载播放浮层与台词阅读流，通过纯灰度对比拉开焦点台词、同组附加台词、未选中台词、时间轴连接线与元数据的阅读主次；同时在 Dark Mode 下维持“视频舞台（`#000000`） < `Playback Overlay`（`#161616`） < `Command Panel`（`#1C1C1F`） < 菜单（`#36363B`）”的越上层越亮海拔阶梯：
     - `--color-subtitle-focus-overlay-bg`：Light `#F4F4F4`；Dark `#161616`
     - `--color-subtitle-focus-cue-selected`：Light `#1A1A1A`；Dark `#EDEDED`
     - `--color-subtitle-focus-cue-group-selected`：Light `rgba(26,26,26,0.75)`；Dark `rgba(237,237,237,0.75)`
     - `--color-subtitle-focus-cue-unselected`：Light `rgba(26,26,26,0.30)`；Dark `rgba(237,237,237,0.30)`
     - `--color-playback-cue-timeline-muted`：Light `#D6D6D6`；Dark `#444444`
     - `--color-playback-cue-metadata-selected`：Light `rgba(26,26,26,0.54)`；Dark `rgba(237,237,237,0.54)`
     - `--color-playback-cue-metadata-unselected`：Light `rgba(26,26,26,0.24)`；Dark `rgba(237,237,237,0.24)`

4. **`Command Panel` 容器边界、首页选中项与浮层快捷按钮 / 键帽纯中性配色（`UI Tokens.md`、`C-03.2`、`C-03.3`、`C-04.3`、`C-08.9`、`L-09.1`、`L-09.2`）**：
   - **`Command Panel` 首页选项选中态（`C-04.3`、`L-09.1`）**：去除偏蓝色调，在悬停底色（`--color-bg-hover`）基础上加深一档为纯中性灰：
     - `--color-menu-item-selected-bg`：Light `#E5E7EB`；Dark `rgba(255,255,255,0.16)`
   - **`Command Panel` 容器表面与边界（`L-09.1`）**：保持背景 `--color-bg-dialog`、圆角 `--radius-dialog` 与背景遮罩 `--color-command-panel-scrim` 不变；容器阴影由 `--shadow-popover` 对齐为 **`--shadow-dialog`**，并补齐与 `C-10.1 Dialog` 一致的容器外侧 `1` 物理像素外描边 **`--color-dialog-outline`** 与容器内侧 `1px` 高光 **`--color-dialog-edge-highlight`**。
   - **`Command Panel` 二级页头部返回按钮（`L-09.2`）**：按 `C-03.2 Icon Button` 在 `--color-bg-dialog` 表面上的规范，悬停与按下底色统一使用 **`--color-bg-hover`** 与 **`--color-bg-pressed`**，与同栏右侧按钮保持一致。
   - **浮层与弹窗表面快捷动作按钮及键帽**（覆盖 `Playback Overlay` 顶底栏按钮与键帽、`Command Panel` 底栏快捷按钮与键帽、`Tooltip` 键帽及设置页快捷键录入框键帽）：去除冷蓝灰偏色并补足明暗模式下的悬停与按下反馈：
     - `--color-overlay-surface-shortcut-button-bg-hover`：Light `rgba(0,0,0,0.06)`；Dark `rgba(255,255,255,0.10)`
     - `--color-overlay-surface-shortcut-button-bg-pressed`：Light `rgba(0,0,0,0.12)`；Dark `rgba(255,255,255,0.16)`
     - `--color-overlay-surface-keycap-bg`：Light `rgba(0,0,0,0.08)`；Dark `rgba(255,255,255,0.10)`
     - `--color-overlay-surface-keycap-bg-hover`：Light `rgba(0,0,0,0.14)`；Dark `rgba(255,255,255,0.16)`
     - `--color-overlay-surface-keycap-bg-pressed`：Light `rgba(0,0,0,0.20)`；Dark `rgba(255,255,255,0.22)`
     - `--color-popover-surface-shortcut-button-bg-hover`：Light `#F3F4F6`；Dark `rgba(255,255,255,0.12)`
     - `--color-popover-surface-shortcut-button-bg-pressed`：Light `#E5E7EB`；Dark `rgba(255,255,255,0.16)`
     - `--color-popover-surface-keycap-bg`：Light `#E6E6E6`；Dark `rgba(255,255,255,0.10)`
     - `--color-popover-surface-keycap-bg-hover`：Light `#D6D6D6`；Dark `rgba(255,255,255,0.18)`
     - `--color-popover-surface-keycap-bg-pressed`：Light `#C6C6C6`；Dark `rgba(255,255,255,0.24)`

5. **全局半透明前景叠加滚动条配色（`UI Tokens.md`、`C-07.1 Scrollbar`）**：
   - 除播放器固定深色舞台（`Player Chrome` 维持 `--color-player-scrollbar-thumb-*` 不变）外，全应用滚动条滑块统一改用半透明黑/白前景叠加色，使其在工作台纯白表面、`Playback Overlay` 灰度表面、对话框、卡片列表及下拉菜单等不同底色上自动融合且对比度均衡：
     - `--color-scrollbar-thumb-default`：Light `rgba(0,0,0,0.18)`；Dark `rgba(255,255,255,0.22)`
     - `--color-scrollbar-thumb-interactive`：Light `rgba(0,0,0,0.34)`；Dark `rgba(255,255,255,0.38)`

6. **设计文档同步安排**：
   - 关联 UI 设计文档（含 `UI Design Rules.md` §3.1 播放页海拔阶梯色值、`UI Tokens.md` 及对应组件/布局章节）待本次改动完成视觉验收与细节微调后再统一提交更新。

# 验收标准

1. **工作台表格、行操作按钮与状态指示器验收（Light & Dark）**：`Search` 与 `Excerpt` 表格在批量选择模式下勾选行底色柔和克制、无冷蓝偏色，且比未勾选悬停行深一档；`File` 卡片、`Task Panel` 卡片及表格行的 `dots-three` 按钮悬停与按下层次清晰；表格行内 `Content Changed` 与 `Unavailable` 状态图标在普通行、悬停行与已勾选行上悬停时均清晰显示底色反馈。
2. **`Playback Overlay` 灰度阅读流与顶底栏控件验收（Light & Dark）**：`Playback Overlay`（`Current`、`Playlist`、`Collage`）背景呈现纯中性浅灰/碳黑，无偏黄或偏蓝倾向；焦点台词、附加台词、未选中台词、长截图时间轴连接线及台词元数据层次分明且过渡自然；顶栏返回/功能入口按钮及底栏快捷按钮与键帽在静止、悬停、按下态下均为纯中性灰阶且反馈清晰。
3. **`Command Panel` 选中项、容器边界与二级返回按钮验收（Light & Dark）**：`Command Panel` 首页各选项在 Light 下选中态为纯中性灰（无偏蓝）且深于悬停项；`Command Panel` 容器阴影、外侧 `1` 物理像素描边及 Dark 下内侧 `1px` 高光与模态对话框视觉质感一致，圆角边缘干净无漏边或裁切瑕疵；二级页左上角返回按钮的悬停与按下底色与同栏右侧按钮一致；在 `Playback Overlay` 之上打开 `Command Panel` 及弹出菜单时，Dark 下严格呈现逐层提亮的纵深关系。
4. **全局滚动条与共享键帽零偏色验收（Light & Dark）**：工作台各页面/表格、设置窗口、对话框、`Task Panel`、`Playback Overlay`、`Command Panel` 及菜单内的滚动条在静止显现与悬停/拖拽态下均自然融入各自底色、无蓝灰脏感（播放页固定深色舞台滚动条保持不变）；全局 `Tooltip` 键帽与设置页快捷键录入框键帽均呈纯中性灰阶。