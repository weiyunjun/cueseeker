# 版本
main

# 需求描述

1. 主界面 Sidebar 与 Settings Sidebar 的选中项使用 macOS Accent Color 背景，文字、前置图标及展开箭头使用白色。
2. 进入二级界面时，仅二级项显示选中效果，所属一级项不显示选中效果。
3. 主界面 Sidebar 底部的 Settings 仅作为独立窗口入口，不保持选中效果。
4. Settings Sidebar 的所有分类图标使用统一宽度的图标区域并居中，所有分类文字左边缘对齐。
5. Dock 中右键 CueSeeker 图标时：
   - 主窗口始终显示为 CueSeeker，不因 Workbench 或视频播放状态改变。
   - Settings 窗口打开时显示为 Settings，关闭后不显示。
   - 当前获得焦点的窗口显示勾选标记。
6. Settings 窗口的 Sidebar 延伸至窗口顶部，原生窗口控制按钮位于 Sidebar 区域。右侧不显示可见的 Settings 窗口标题，仅保留当前分类自身的标题；Dock 窗口名称仍为 Settings。
7. 本需求涉及的 UI 必须使用可映射到 UI Design System 的共享或语义 Token，禁止在具体 View 中硬编码颜色、尺寸、间距和圆角。
8. 本需求允许在验收前反复调整需求文档与代码；UI Design System 在最终 UI 验收后同步最终 Token、组件和布局规则。