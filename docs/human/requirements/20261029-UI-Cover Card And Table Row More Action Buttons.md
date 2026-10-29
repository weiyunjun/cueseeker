# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **封面卡片角标左移与新增右下角 `...` 按钮**：
   - **适用范围**：所有纵向 `16:9` 封面卡片（包含 Library 一级总览可用卡片、Library 二级剧集卡片、Recent 视频与摘录集卡片、Excerpt 一级摘录集卡片，以及 Playback Overlay 视频播放列表与 Command Panel 最近视频/最近摘录集中的封面卡片；0 集不可用的禁用态卡片不显示）。
   - **位置调整**：
     - 原位于封面图右下角的胶囊角标（`C-08.3 Information Badge / Cover Badge`：播放时间或数量角标）统一移至**封面图左下角**，距封面左边缘与下边缘均为 `--spacing-2`（`8px`）。
     - 新增的 `...`（`dots-three`）按钮置于**封面图右下角**，距封面右边缘与下边缘均为 `--spacing-2`（`8px`），与左下角胶囊处于同一水平高度（位于底部播放进度条上方）。
   - **尺寸与视觉样式**：
     - 复用 `C-03.2 Icon Button / Default` 尺寸规格（宽高 `--size-icon-button` `32px`、圆角 `--radius-control` `8px`、图标尺寸 `--size-control-icon` `21px`）。
     - 图标颜色复用 `--color-library-time-badge-text`（`#FFFFFF`）；背景复用 `--color-library-time-badge-bg` 的基底色（Light `#0F172A`、Dark `#000000`），仅通过透明度区分三态：
       - **Default**（鼠标悬停卡片、未移到按钮上）：`--opacity-library-cover-action-bg`（Light `0.56`；Dark `0.44`）。
       - **Hover / Open**（鼠标移到按钮上，或通过点击该 `...` 按钮打开菜单期间）：`--opacity-library-cover-action-bg-hover`（Light `0.72`；Dark `0.58`）。
       - **Pressed**（按下按钮）：`--opacity-library-cover-action-bg-pressed`（Light `0.88`；Dark `0.76`）。
   - **显隐与交互**：
     - 默认隐藏，仅在**鼠标指针 Hover 到该卡片**或**通过该 `...` 按钮打开的菜单处于 Open 状态**时显示；在 Playback Overlay 与 Command Panel 中，仅处于键盘/默认选中态（`Selected`）但鼠标未悬停在上面时不显示。
     - 鼠标移到封面卡片 `...` 按钮上时，指针切换为**默认箭头**（封面其余区域保持 `Grab` 抓手）。
     - 按下或点击 `...` 按钮仅触发按钮自身的 `Pressed` 态与开关菜单，不触发打开或播放卡片；通过左键点击 `...` 按钮打开的菜单内容与卡片右键菜单一致，并挂靠在该 `...` 按钮上，此时该 `...` 按钮处于 `Open` 态；通过右键点击卡片触发菜单时，菜单挂靠在鼠标右键落点，与 `...` 按钮无关，`...` 按钮不进入 `Open` 态。

2. **Search 与 Excerpt 表格 `Cues` 列右侧新增 `...` 按钮**：
   - **位置与空间预留**：
     - 在 Search 与 Excerpt 表格的 `Cues` 列内部右侧新增 `...`（`dots-three`）按钮。
     - 所有行在 `Cues` 列右侧**恒定预留该按钮的宽度空间**（按钮宽 `--size-icon-button` `32px` + 与左侧文本或状态图标间距 `--spacing-2` `8px`，按钮距 `Cues` 列右边缘 `--padding-table-cell-trailing` `14px`），确保鼠标移入/移出显示按钮时台词折行、行高及“内容已变更”图标位置固定不变。
     - 垂直方向与左侧序号/勾选框一致，在**整行高度内垂直居中**。
   - **尺寸与视觉样式**：
     - 复用 File 卡片右侧 `...` 按钮的 `C-03.2 Icon Button / Default` 样式与配色：宽高 `--size-icon-button`（`32px`）、圆角 `--radius-control`（`8px`）、图标 `--size-control-icon`（`21px`）；Default 背景透明、图标色 `--color-text-secondary`；Hover / Open 背景 `--color-row-selected`；Pressed 背景 `--color-row-action-bg-pressed`。
   - **显隐与交互**：
     - 普通模式下默认隐藏，仅在**鼠标 Hover 到该行**或**通过该行 `...` 按钮打开的菜单处于 Open 状态**时显示（含 Excerpt 表格中的已失效 `Unavailable` 行）；进入**批量选择模式（Select Mode）**时不显示。
     - 鼠标移到该按钮上时，整行保持 Hover 背景，台词文字不显示下划线，指针为默认箭头；通过左键点击该按钮弹出的菜单内容与该行右键菜单完全一致，并挂靠在该按钮上，此时该 `...` 按钮处于 `Open` 态；通过右键点击表格行触发菜单时，菜单挂靠在鼠标右键落点，与 `...` 按钮无关，`...` 按钮不进入 `Open` 态。

3. **Token 与范围清理**：
   - 新增封面按钮三态背景透明度 Tokens：`--opacity-library-cover-action-bg`、`--opacity-library-cover-action-bg-hover`、`--opacity-library-cover-action-bg-pressed`。
   - 退役删除早期遗留且无实例的 `Icon Button / Row Action` 尺寸变体及相关 Tokens（`--size-row-action-button: 36px`、`--radius-row-action: 8px`），卡片与表格行的 `dots-three` 按钮统一归入 `Icon Button / Default`（`32×32px`、圆角 `8px`）。
   - File 界面卡片与 Task 面板卡片保持现状，暂不新增右键菜单功能。

# 验收标准

1. 所有封面卡片的播放时间/数量胶囊统一位于封面左下角（边距 `8px`）；鼠标悬停卡片或通过 `...` 按钮打开菜单时，封面右下角（边距 `8px`）显示 `32×32px` 的 `...` 按钮，三态透明度在浅色（`0.56 / 0.72 / 0.88`）与深色（`0.44 / 0.58 / 0.76`）主题下符合规范，键盘选中但鼠标未悬停时不显示。
2. 鼠标移到封面卡片 `...` 按钮上时指针变为默认箭头，左键点击该按钮挂靠弹出菜单且按钮处于 `Open` 态，不会误触打开/播放卡片；右键点击卡片弹出菜单时，`...` 按钮不进入 `Open` 态。
3. Search 与 Excerpt 表格 `Cues` 列右侧恒定预留 `...` 按钮空间，按钮在整行高度内垂直居中、距右边缘 `14px`；鼠标悬停切换显示按钮或缩放窗口改变行高时，台词折行、行高及“内容已变更”图标位置均保持稳定不跳动。
4. 表格在普通模式下悬停行（含已失效摘录行）显示 `...` 按钮，进入批量选择模式（Select Mode）后隐藏；悬停按钮时台词无下划线、指针为默认箭头，左键点击按钮挂靠弹出菜单且按钮处于 `Open` 态；右键点击表格行弹出菜单时，`...` 按钮不进入 `Open` 态。
5. File 卡片与 Task 卡片保持既有交互不变。