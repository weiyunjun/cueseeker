# 版本

main

# 需求描述

1. 本需求适用于 Playback Current、Playback Cue Playlist、Editing Collage 和 Command Panel Search 四个界面。

2. 四个界面均不再显示时间轴左侧的序号列。序号区域、序号字号字重颜色以及 `--width-playback-cue-sequence-digit` 一并移除。

3. 时间轴圆点尺寸由 `12px` 调整为 `8px`。圆点圆心仍与 Primary Cue 第一视觉行实际可见字形范围的垂直中心位于同一水平线；圆点与连接线之间仍各保留 `8px` 空隙。

4. Editing Collage 的 Checkbox 标记尺寸、样式、状态和点击范围保持不变。

5. Playback Cue Playlist 和 Command Panel Search 在字幕文本下方的元信息行中，于 Display Title 左侧显示序号，形如 `#238  Fate Stay Night - 02  07:29 - 07:31`，沿用各自列表的 1-based 位置。Playback Current 和 Editing Collage 不显示序号。

6. 元信息行各段之间沿用现有 Item Gap `--spacing-3`，序号沿用 `--color-playback-cue-metadata`，不新增 Token。宽度不足时优先保留序号与 Time Range，由 Display Title 吸收剩余宽度。

7. Playback Current、Playback Cue Playlist 和 Editing Collage 的 Footer `{N} cues` 左边缘必须与时间轴圆点左边缘对齐。Command Panel Search 的 Footer 保持现状，不在本需求范围内。

8. 删除序号列释放的水平空间归字幕正文。内容列总宽仍为 `--width-subtitle-focus-content-max: 960px`，正文列宽不再随序号位数变化。

9. 焦点变化不得改变字幕行高、Reel Placement、滚动位置或 Checkbox 状态。现有虚拟化、键盘、鼠标、文字选择和滚动行为保持不变。

10. 所有尺寸、间距、字号和颜色必须使用共享语义 Token，四个界面不得分别硬编码或建立独立实现。

# UI 文档同步

视觉验收完成后，由人类维护者更新并提交 `docs/human/design/UI Design System.md`，记录最终 Token、Playback Cue Reel 与 Playback Cue Metadata 锚点，以及 Footer 对齐规则。