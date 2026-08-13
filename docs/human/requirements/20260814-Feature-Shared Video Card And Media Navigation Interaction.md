# Feature: Shared Video Card And Media Navigation Interaction

- 日期：2026-08-14
- 代码基线：4aa9b6aa
- 状态：待实现

## 需求

### 1. 共享视频卡片

- Library 二级界面中，封面区域下方完全删除原有左图右文布局，直接复用 Recent Videos 的视频卡片。
- Playback Overlay Video Playlist 同样复用该视频卡片。
- 三处必须使用同一共享实现，不复制相似组件，不增加专用样式。
- 卡片内容规则完全保持 Recent Videos 现状，包括 `folderTitle`、`EPXX`、观看状态、进度和时间；不得改用 `displayTitle`。
- Selected 和 Hover 均作用于整张卡片，并保持 Recent Videos 现有视觉规则；二者状态相互独立，可以同时出现在不同卡片上。

### 2. 选择与滚动

- Command Panel 的 Recent Videos、Recent Shiori，以及 Playback Overlay Video Playlist，均取消强制居中。
- 已选项目可见时不得滚动；不可见时仅滚动到最近边缘以保证可见。
- 每个 Playback Session 首次进入 Video Playlist 时，默认选择当前播放视频；无法匹配时选择第一个可用视频。
- 同一 Session 再次进入时，保留原有选择和滚动位置，不重新选择当前播放视频。

### 3. Pointer 与 Hover

- Hover 仅为鼠标视觉反馈，不得改变或清除键盘/控制器的 Selected 状态。
- 键盘或控制器操作隐藏鼠标时，Command Panel 和 Video Playlist 中所有鼠标 Hover 效果必须立即失效，Selected 状态保持不变。
- 鼠标重新移动后，恢复鼠标显示及 Hover 效果；鼠标跨卡片移动只能改变 Hover，不得改变 Selected。

### 4. UI 约束

- 禁止硬编码 UI 数值或增加私有特殊实现，所有样式必须来自现有 UI Design System。
- 迭代期间暂不修改 `UI Design System.md`；UI 验收完成后再同步并提交该文档。

## 验收

- Pointer 隐藏、Hover 消失、鼠标恢复 Hover，以及鼠标跨卡片移动不改变 Selected，使用人工验收。
- 其余需求必须使用现有自动化端到端测试覆盖，不为本需求新增 Pointer Move 自动化能力。
