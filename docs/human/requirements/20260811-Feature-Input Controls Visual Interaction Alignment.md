# 版本

main

# 实现基准

f2aee46a

# 需求描述

调整 CueSeeker macOS App 的 Inputs 视觉与交互细节。

本需求只处理 Text Field、Text Area、Search Field、Number Field 及其直接使用界面，不修改其它组件或页面布局。

本需求是 `docs/human/design/UI Design System.md` 中 Components - Inputs 的当前增量要求。实现和实际界面验收完成后，再由人工将稳定结果回写 UI Design System。

# Focus 状态

1. Text Field、Text Area、Search Field、Number Field 获得焦点时，不显示控件外部 Focus Ring。
2. Focus 状态只将控件边框改为 macOS Accent Color。
3. Focus 不改变控件尺寸、圆角、内边距或页面布局。
4. Error 状态继续以 Danger Border 为最高优先级，不额外显示 Focus Ring。
5. 不修改 Button、Selection Control 或其它非 Input 组件的 Focus Ring。
6. 不删除仍被其它组件使用的全局 Focus Ring Token。

# Text Area 光标与内容位置

1. 修复 Description (optional) Text Area 中插入光标明显偏上的问题。
2. Placeholder、插入光标和输入后首行文字必须使用同一套内容 Insets。
3. 空内容获得焦点时，光标位置应与输入后首行文字位置一致。
4. 不得依赖互相独立的 SwiftUI Padding 和原生 NSTextView 默认 Insets 偶然对齐。
5. 保持 Text Area 当前高度、圆角和整体布局不变。

# Text Area 滚动条

1. 不显示 macOS 原生滚动条、滚动槽或预留 Gutter。
2. 使用项目统一的自绘滚动条视觉：
   - Thickness：8px
   - Minimum Thumb Length：24px
   - Track：Transparent
   - Thumb Radius：Pill
   - Default 和 Interactive 颜色使用现有 Scrollbar Token
3. Visibility：
   - No Overflow：Hidden
   - Idle：Hidden
   - Scroll Area Hover：Visible
   - Scrolling：Visible
   - Dragging：Visible
4. 滚动条以 Overlay 形式显示，不得引起内容宽度或布局跳动。
5. 鼠标滚轮、触控板滚动和 Thumb Drag 必须正常工作。
6. 不改变其它非 Input 滚动区域的现有行为。

# Number Field

1. Auto Switch Gap 使用统一 Number Field。
2. 高度为 40px，圆角为 8px，水平内边距为 16px。
3. 数值保持尾部对齐和等宽数字显示。
4. `ms` 单位放入同一个控件容器。
5. 不增加 Increment、Decrement 或 Spinner 控件。
6. Focus 时只改变边框颜色，不显示外部 Focus Ring。
7. 保持现有纯数字输入、范围限制、提交和持久化行为。

# 验收标准

1. 所有 Input Focus 截图中只有边框变色，没有外部 Focus Ring。
2. Text Area 的 Placeholder、光标和首行输入文字位置一致，无明显上偏或裁切。
3. Text Area 无溢出和空闲时不显示滚动条。
4. Text Area 溢出后，Hover、Scrolling、Dragging 状态符合统一滚动条规则。
5. Text Area 不显示原生滚动槽，滚动和拖动功能正常。
6. Number Field 符合 40px、单位内置、无外圈 Focus Ring 的目标。
7. 输入、校验、数值限制和数据保存行为无回归。
8. 使用 Debug E2E 捕获真实的修改前、修改后及关键交互状态截图。
9. 自动化测试和 `swift test` 通过。
10. 不修改其它组件、页面布局或非 Input 滚动区域。
11. 实际界面验收完成后，再由人工更新 `UI Design System.md`。