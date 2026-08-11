# 版本

main

# 需求描述

1. 以 `docs/human/design/UI Design System.md` 为基础，完成当前 macOS App 的 UI 架构重构和界面迁移。
2. `docs/human/design/UI Application Rules.md`中的特定规则和局部覆盖优先于基础设计系统。
3. 本需求实现设计文档已经定义的 Core Tokens、Components 和 Layouts，不在需求单中重复设计内容。
4. 设计文档没有规定的业务功能、数据流程和用户行为保持不变。
5. 不为尚未存在的 Windows 实现增加额外架构。

# 修改范围

## Core Tokens

1. 建立代码中的统一 Token 来源。
2. 实现设计文档定义的颜色、字体、尺寸、间距、形状、效果和动效。
3. 支持 Light Appearance 和 Dark Appearance。
4. 删除被统一 Token 替代的重复颜色、尺寸和样式常量。

## Components

实现并迁移设计文档中定义的全部 Component 分类：

1. Inputs
2. Selection Controls
3. Buttons
4. Menus
5. Navigation
6. Tables
7. Scrollbars
8. Data Display
9. Feedback
10. Dialogs
11. Media
12. Player Controls
13. Playback Content

同一种 Component 的共享 Anatomy、Sizes 和 States 必须由同一实现维护；界面差异通过设计文档中已经定义的 Variants 表达。

## Layouts

按照设计文档实现并迁移以下 Layout 分类：

1. App Shell
2. Settings
3. Recent
4. Library
5. Search and Shiori
6. Dialogs
7. Player
8. Playback Overlay
9. Command Panel

Layout 只负责组件组合、结构、间距、位置和界面状态，不重复实现 Component 内部样式。

## 现有界面迁移

1. 将所有现有界面迁移到新的 Token、Component 和 Layout。
2. 删除迁移后不再使用的旧样式、重复组件和界面专用替代实现。
3. 保留设计文档明确要求使用的平台原生控件和平台行为。
4. 未被设计文档覆盖的图标资产和业务交互保持现状。

# 实施顺序

1. Core Tokens。
2. 通用 Components。
3. Tables、Media、Player Controls 和 Playback Content。
4. App Shell、Settings、Recent、Library。
5. Search and Shiori、Dialogs、Player、Playback Overlay、Command Panel。
6. 删除旧实现并完成全界面回归。

# 验收标准

1. 设计文档定义的每个 Component 和 Layout 均有明确的代码实现或组合关系。
2. 相同 Component 不再由不同界面分别维护重复样式。
3. 已定义的视觉值全部引用统一 Token，不保留等价的硬编码副本。
4. Light Appearance 和 Dark Appearance 均符合设计文档。
5. Hover、Focus、Selected、Disabled、Dragging、Open 等已定义状态正确。
6. 所有自绘 Scrollbar 的视觉、显示条件和拖动状态一致。
7. App 窗口尺寸变化时，各 Layout 保持设计文档定义的结构和自适应关系。
8. 鼠标、键盘、文字选择、菜单、表格滚动、播放器及 Playback Overlay 的既有业务功能没有回归。
9. 被新架构替代的旧实现和冗余样式已经删除。
10. macOS App 构建和现有测试全部通过。