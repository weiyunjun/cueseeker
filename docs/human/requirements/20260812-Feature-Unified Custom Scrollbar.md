# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
  - Scrollbar Color Token
  - Scrollbar Size Token
  - Scrollbar Radius Token
  - `Components / 2.7 Scrollbars`
    - Anatomy
    - Rendering
    - Interaction
    - Sizes
    - Variants

本需求暂不实施 `States` 和 `Visibility` 中的自动隐藏规则。

# 需求目标

统一 CueSeeker 所有 App 自有滚动区域的 Scrollbar 外观与基础交互。

现有 Table Scrollbar 和 Playback Overlay Scrollbar 作为视觉与交互基准。

Scrollbar 外观与交互统一，不代表所有滚动区域都使用相同的虚拟滚动模型。

# 适用范围

包括：

1. Table。
2. Text Area。
3. 普通页面、列表和网格。
4. Library、Search、Shiori 和 Settings。
5. Playback Overlay。
6. Playback Playlist、Command Panel、Library Overlay 和 Collage Preview。
7. Sheet、Popover、Panel 和 Dialog 内由 App 控制的滚动区域。

系统窗口、系统菜单和 File Picker 不在本需求范围内。

# 样式要求

1. 使用 Custom Drawn Scrollbar。
2. 不显示 Platform Native Scrollbar。
3. Track、Thumb、颜色、尺寸和圆角使用 `UI Design System.md` 中的 Token。
4. Scrollbar 的位置、边距、Thumb 比例和双轴交叉处理沿用现有 Table Scrollbar。
5. Scrollbar 使用 Overlay 布局，不保留 Gutter。
6. Scrollbar 不得改变内容区域的尺寸、对齐、换行或滚动范围。
7. Vertical 与 Horizontal Scrollbar 使用相同的视觉与几何规则。
8. Hover 和 Dragging 只改变 Thumb 的交互颜色，不控制 Scrollbar 显示或隐藏。

# 当前显示规则

1. 当前方向不存在滚动范围时，不绘制对应方向的 Thumb。
2. 当前方向存在滚动范围时，持续显示对应方向的 Scrollbar。
3. 本需求不实现：
   - Idle 自动隐藏。
   - Scroll Area Hover 触发显示。
   - Scrolling 触发显示。
   - Dragging 维持显示。
   - 延迟隐藏或淡出。
   - macOS `Show Scroll Bars` Preference 联动。
4. 不新增用于显示或隐藏 Scrollbar 的 Timer、Tracking State 或 Visibility State Machine。
5. Scrollbar 自动隐藏行为留待后续独立需求处理。

# 滚动模型边界

## Table 与 Playback Overlay

1. 保留现有虚拟滚动和逻辑位置映射。
2. Scrollbar 可以根据逻辑数据范围、可见范围和逻辑位置计算 Thumb。
3. 不改变现有虚拟化、数据加载、定位或 Playback 行为。

## 其他滚动区域

1. 使用界面原有的普通滚动模型。
2. Thumb 比例和位置直接根据真实 Viewport、Content Size 和 Content Offset 计算。
3. Thumb Drag 直接修改真实 Content Offset。
4. 不得新增：
   - 虚拟内容范围。
   - 逻辑行号或逻辑索引映射。
   - 分页、预加载或增量加载。
   - 独立滚动位置状态源。
   - Scroll Proxy 或模拟滚动坐标。
5. 不得为了接入 Custom Scrollbar 改变内容布局、生命周期或加载方式。

# 交互要求

1. Mouse Wheel 和 Trackpad Scroll 保持现有行为。
2. Keyboard Navigation 和 Programmatic Scroll 保持现有行为。
3. Thumb Drag 保持现有滚动定位能力。
4. 只有 Thumb 交互区域可以拦截 Pointer Event。
5. Scrollbar Overlay 的其他区域不得阻挡内容点击、选择、Hover 或拖动。
6. 不新增 Track Click、Page Jump 或其他滚动行为。
7. 不改变现有 Selection、虚拟化、数据加载或 Playback 行为。

# 实现约束

1. 复用现有 Table Scrollbar 的绘制与几何实现，不建立第二套 Scrollbar Primitive。
2. 共享范围仅包括视觉、几何和基础 Pointer Interaction。
3. Table、Playback Overlay 与普通滚动区域可以分别提供符合自身滚动模型的 Metrics。
4. 每个 Scrollbar Overlay 必须明确绑定其所属的滚动容器和真实 Viewport。
5. 禁止通过遍历祖先、子视图或兄弟视图，并选择“第一个 NSScrollView”的方式推断滚动容器。
6. 不得将 Scrollbar Overlay 放置在滚动内容内部。
7. Overlay 边界必须与目标 Viewport 一致，并随首次布局、窗口缩放和内容尺寸变化同步更新。
8. Native Scrollbar 只能在对应 Custom Scrollbar 正确接入后关闭。
9. 不为不同 Feature 重复实现颜色、尺寸或 Thumb 几何。
10. 不将 Table 或 Playback Overlay 的虚拟滚动逻辑抽象到普通滚动区域。

# 实施顺序

1. 保持现有 Table 和 Playback Overlay 的滚动模型不变。
2. 统一已有 Custom Scrollbar 的样式和几何。
3. 逐个迁移明确持有滚动容器的 AppKit 滚动区域。
4. 建立明确持有滚动容器与 Overlay 的普通页面滚动实现。
5. 逐个迁移 SwiftUI 页面、列表和网格。
6. 每个阶段独立验证并提交 Git。

# 验收标准

1. 所有适用范围内的 Platform Native Scrollbar 均已替换。
2. 所有 Custom Scrollbar 的视觉样式一致。
3. 存在滚动范围时 Scrollbar 持续显示。
4. 不存在滚动范围时不绘制对应方向的 Thumb。
5. Scrollbar 位于所属 Viewport 的正确边缘，不出现在内容内部或其他滚动区域。
6. 首次布局和窗口缩放后，Overlay 仍与目标 Viewport 对齐。
7. Vertical 与 Horizontal Scrollbar 独立计算滚动范围。
8. Thumb Drag、Mouse Wheel、Trackpad、Keyboard Navigation 和 Programmatic Scroll 正常工作。
9. Scrollbar 不影响内容布局，也不阻挡非 Thumb 区域的 Pointer Event。
10. Table 和 Playback Overlay 的现有虚拟滚动、加载与定位行为没有回归。
11. 其他滚动区域仍使用真实 Content Size 和 Content Offset，没有新增虚拟化、逻辑位置映射或加载机制。
12. 自动化测试必须验证 Overlay 与指定滚动容器及 Viewport 的绑定关系，不得只验证任意 NSScrollView 中存在 Overlay。
13. Debug 客户端截图只用于确认真实运行结果，不得代替布局和绑定测试。
14. 最终视觉与交互由项目 Owner 在真实 Debug 客户端验收。