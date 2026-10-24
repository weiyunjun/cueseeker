# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **顶栏居中元素可用宽度与安全间距规范化（`L-07.1 Player Topbar Layout`、`L-08.2 Playback Topbar Layout`、`C-12.6 Player Title`）**：
   - 视频播放顶栏居中视频标题（`C-12.6 Player Title`）以及 `Playback Overlay` 顶栏拼贴编辑态居中标题（`Editing Collage`），可用宽度均根据左侧控件区与右侧操作区（`Task` / `Settings`，含任务徽章动态变宽）的实际宽度动态计算。
   - 居中标题左右两侧与左、右控件区各保持至少 `--spacing-3`（`12px`）安全间距（与 `Workbench Recent` 顶栏及 `Playback Overlay` 顶栏分段控件的安全间距规则完全统一），超长文本在可用宽度内单行尾部截断（`...`），不与两侧控件重叠。

2. **播放页顶栏任务数量徽章固定深色配色（`C-08.3 Task Count Badge`、`C-08.4 Tag / Player Chrome`）**：
   - 视频播放顶栏（`Player Chrome` 固定深色表面）上 `Task` 入口按钮展示任务数量徽章时，不再随系统浅色/深色模式切换两套配色，统一复用底栏标签（`C-08.4 Tag / Player Chrome`）的固定深色视觉令牌（背景 `--color-player-control-bg-hover`、文字 `--color-player-text-secondary`）。

3. **移除进度条拖拽交互抑制规则并规范控件状态与图标（`L-07.1`、`L-07.2`、`C-03.2`、`C-12.1`、`C-12.5`）**：
   - 移除拖拽播放进度条期间对顶栏与底栏按钮的交互抑制（`Interaction Suppressed`）状态及规则。
   - 底栏图标按钮（`C-03.2 Icon Button`）严格遵循白名单状态（`Default`、`Hover`、`Pressed`、`Open`、`Disabled`）：字幕开启时底栏字幕按钮保持常驻 `Open` 态（外观同 `Hover`），拖拽进度条期间不再出现字幕按钮浅白底色消失的问题。
   - 播放页文字（顶栏标题、底栏时间、进度条悬浮时间胶囊、倍速按钮、音量百分比）统一保持 `Semibold (600)` 字重；底栏音量按钮（`C-12.5`）保持静音（`speaker-x`）与非静音（`speaker-high`）两态图标，舞台中央反馈胶囊（`Playback Feedback`）保持调高音量（`speaker-high`）、调低音量（`speaker-low`）与静音（`speaker-x`）图标。

4. **底栏容器高度与播放页菜单规范化（`L-07.2 Player Bottom Control Bar Layout`、`C-04.1 Menu / Player Chrome`、`C-12.1 Player Speed Button`）**：
   - 底栏容器高度严格固定为 `--height-player-bottom-control-bar`（`90px`），移除底栏为容纳倍速菜单而写死的扩展高度。
   - 倍速菜单（`Player Speed Menu`）与更多菜单（`Player More Menu`）统一在播放舞台层（顶栏底边与底栏按钮顶边之间的安全区域内）向上弹出，统一采用 `C-04.1 Menu / Player Chrome` 容器样式（`1px` 外侧轮廓线与内侧高光），菜单内单选勾选图标（`check`）与子菜单箭头图标（`caret-right`）尺寸统一为 `--size-menu-item-symbol-font-size-macos`（`18px`）。

5. **进度条无时长态与悬浮时间胶囊宽度规范化（`L-07.3`、`C-12.3 Player Progress Scrubber`、`C-12.4 Player Progress Time Capsule`）**：
   - 无有效视频时长（`No Duration`）时，进度条仅展示底轨，鼠标移入或拖拽不触发轨道加粗、不显示预览轨与进度圆点、不触发跳转。
   - 进度条悬浮时间胶囊（`C-12.4`）移除硬编码最小宽度兜底，宽度完全由时间文本内容加左右内边距（`--padding-player-time-capsule-x`）决定，并在进度条左右边界内自动夹紧。

6. **设计文档一致性约束**：
   - 严禁硬编码或私自特殊实现，所有视觉与交互均须可体现在 UI 设计文档体系中；待实际 UI 验收定稿后同步更新 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. 视频播放页顶栏与 `Playback Overlay` 拼贴编辑态顶栏中，当右侧 `Task` 按钮带有任务数量徽章（如 `99+`）或窗口缩窄时，居中标题在距离左右控件区至少 `12px` 处自动单行截断（`...`），不与两侧按钮重叠。
2. 浅色与深色模式下，视频播放顶栏 `Task` 按钮上的任务数量徽章均保持与底栏 `Tag` 一致的固定深色胶囊背景与浅灰文字。
3. 开启字幕后拖拽播放进度条时，底栏字幕按钮的浅白高亮底色保持常驻不消失；拖拽进度条期间顶栏与底栏控件无异常闪烁或状态跳变。
4. 点击底栏倍速按钮向上弹出的倍速菜单与更多菜单外框、圆角、`1px` 描边高光及 `18px` 图标尺寸完全一致，且底栏自身交互高度严格为 `90px`。
5. 无有效视频时长时鼠标移入进度条不加粗、不出现圆点与预览轨；有视频时长时悬浮时间胶囊宽度随时间文本自适应并在左右端点平齐夹紧。