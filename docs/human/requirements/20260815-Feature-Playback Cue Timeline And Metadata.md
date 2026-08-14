# 版本
main

# 需求描述

1. 调整 Playback Current、Playback Cue Playlist、Editing Collage 和 Command Panel Search 的字幕展示结构，四个界面统一复用相同规则。

2. 每条字幕从左到右显示：
   1. 序号
   2. 时间轴标记
   3. 字幕内容与元信息

3. 序号保持现有系统比例字体，字号为 `24px`，字重为 Semibold `600`，并在序号区域内右对齐。禁止改用等宽字体。焦点与非焦点使用相同的序号内容、字号和字重，仅通过灰色深浅区分。

4. 焦点与非焦点字幕均只显示序号，例如 `13`，字幕行内不显示总数。序号区域使用共享的单数字预留宽度 Token `--width-playback-cue-sequence-digit: 16px`，区域宽度为当前数据集最大序号的位数乘以该 Token。不得设置固定位数上限，所有序号必须完整显示；切换焦点时不得引起字幕水平移动。

5. Current 和 Editing Collage 使用当前字幕文件中从 `1` 开始的实际字幕展示顺序。Cue Playlist 和 Command Panel Search 沿用当前列表序号。序号本身不承载总数。

6. Current、Cue Playlist 和 Command Panel Search 使用圆点与竖线组成时间轴。圆点中心与 Primary Cue 第一视觉行实际可见字形范围的垂直中心对齐。序号区域与圆点、圆点与字幕区域的水平间距相等，统一使用 `--spacing-6: 24px`。竖线连接相邻圆点，并与上下圆点边缘各保留 `8px` 空隙。焦点圆点颜色较深，非焦点圆点和竖线颜色较浅，但都弱于对应字幕。

7. Editing Collage 不增加圆点，使用现有 Checkbox 作为时间轴标记，并在相邻 Checkbox 之间增加连接线。Checkbox 中心与 Primary Cue 第一视觉行实际可见字形范围的垂直中心对齐。序号区域与 Checkbox、Checkbox 与字幕区域的水平间距相等，统一使用 `--spacing-6: 24px`。连接线与上下 Checkbox 边缘各保留 `8px` 空隙。Checkbox 的尺寸、样式、状态和点击范围保持不变。

8. Editing Collage 左右区域继续保持 `1:1`，新增序号和连接线必须位于现有右侧字幕区域内，不改变该区域宽度。

9. 删除四个界面的 Playback Information Badge 外观。Display Title 和 Time Range 改为普通灰色文字，显示在 Primary Cue 及可见 Cue Group 字幕后方。只显示 Display Title 和 Time Range，字号保持 `12px`，字重为 Regular `400`，不显示背景、边框、圆角或内边距。

10. Primary Cue 保持 `24px / 32px / 600`；Cue Group 保持 `20px / 28px / 500`。

11. 焦点变化不得改变字幕行高、字幕宽度、Reel Placement、滚动位置或 Checkbox 状态。现有虚拟化、键盘、鼠标、文字选择和滚动行为保持不变。

12. 所有新增字号、字重、颜色、尺寸和间距必须使用共享语义 Token；四个界面不得分别硬编码或建立独立实现。

# UI 文档同步

本需求作为 `docs/human/design/UI Design System.md` 现有 Playback Information Badge 和相关 Playback Layout 规则的增量变更依据。视觉验收完成后，由人类维护者更新并提交该设计文档，记录最终 Token、组件和布局规则。