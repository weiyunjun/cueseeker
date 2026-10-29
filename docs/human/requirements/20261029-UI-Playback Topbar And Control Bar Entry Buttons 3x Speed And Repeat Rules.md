# 版本

main

# 关联设计

- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/playback/Playback Edge Cases.md`

# 需求描述

1. **新增 Command Panel 按钮与 Playback Overlay 按钮**：
   - **Command Panel 按钮（顶栏）**：
     - 使用 `magnifying-glass` 图标，仅在播放相关界面顶栏（Player Topbar、Playback Overlay Topbar）显示，在 Workbench 界面顶栏不显示。
     - 位于顶栏右侧功能区 `Task` 按钮左边、`Collage` 按钮右边。
     - 点击打开 Command Panel（与按快捷键效果一致），面板打开期间按钮处于 `Open` 状态；悬停显示带动态快捷键的 Tooltip（`Open Command Panel` / `打开命令面板` / `開啟指令面板`）。
   - **Playback Overlay 按钮（播放器底部控制栏）**：
     - 使用 `list` 图标，位于播放器底部控制栏右侧按钮组中 `Repeat` 按钮左边。
     - 点击打开 Playback Overlay 界面（与按回车快捷键效果一致）；悬停显示带动态快捷键的 Tooltip（`Open Playback Overlay` / `打开播放覆盖层` / `開啟播放覆蓋層`）。

2. **解锁 3 倍速播放上限**：
   - 播放器最大播放倍速上限提升至 `3×`。
   - 播放器底部控制栏倍速菜单（`Player Speed Menu`）在 `2×` 选项下方新增 `3×` 选项。

3. **修改 Repeat（重播）按钮与快捷键规则**：
   - **全场景可用**：在任意播放场合下均可使用（无论播放入口、是否开启 Auto Switch 或当前时间点是否处于台词空白处），底部控制栏 `Repeat` 按钮始终为可用状态，悬停固定显示 `Replay Current Cue`（`重播当前台词` / `重播目前台詞`）与动态快捷键 Tooltip。
   - **目标台词判定**：重播的目标台词与按下回车弹出 Playback Overlay 界面（`Current` 模块）时默认选中的台词一致：
     1. 若当前播放时间点存在正在显示的台词，选中该台词；
     2. 若当前播放时间点无正在显示的台词，选中离当前时间点最近的前一句台词；
     3. 若当前播放时间点位于字幕文件第一句台词之前，选中字幕文件的第一句台词。
   - **跳转与自动暂停/自动切换配合**：
     - 触发 Repeat 本质为视频内跳转到目标台词起始时间并继续播放，不弹出任何 Toast 或画面提示。
     - Repeat 与 Auto Pause、Auto Switch 互不冲突：Auto Pause 依然在播放到达特定结束时间戳时触发暂停；若在 Auto Switch Gap 倒计时期间触发 Repeat，由于本质是一次跳转（Seek），会刷新（取消当前并待再次播完暂停时重新计时）Auto Switch Gap 时间。

# 验收标准

1. 在普通播放界面顶栏与 Playback Overlay 顶栏右侧可见放大镜图标的 Command Panel 按钮（位于 `Collage` 右侧、`Task` 左侧），Workbench 顶栏不显示该按钮；点击可打开 Command Panel，悬停 1 秒显示对应 Tooltip。
2. 在播放器底部控制栏 `Repeat` 按钮左侧可见列表图标的 Playback Overlay 按钮；点击可打开 Playback Overlay 界面，悬停 1 秒显示对应 Tooltip。
3. 打开播放器倍速菜单，在 `2×` 下方可见 `3×` 选项；点选 `3×` 或通过倍速增加快捷键最高可将播放速度调至 `3×`。
4. 从任意入口播放视频时，底部控制栏 `Repeat` 按钮与重播快捷键始终可用：在台词播放中途、两句台词空白间隙、片头第一句台词之前均可正常跳转到对应台词起点重播，且不弹 Toast 提示；开启 Auto Pause 或 Auto Switch 时触发 Repeat 可正常重播并在台词结束处暂停、刷新自动切换间隔倒计时。