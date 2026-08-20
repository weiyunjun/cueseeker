# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
  - `Components / 2.6 Tables / Table`
  - `Components / 2.7 Scrollbars`
  - `Layouts / 3.1 App Shell / Workbench Titled Page Layout`
  - `Layouts / 3.5 Search and Shiori`

# 关联需求

- `docs/human/requirements/20260812-Feature-Unified Custom Scrollbar.md`

# 需求目标

统一 Workbench 各页面的滚动条归属与内容区最小宽度规则，消除 Search 与
Shiori 二级页面之间的布局差异。

# 需求

## 滚动条归属

1. 表格不再拥有自己的横向或纵向 Scrollbar。
2. Workbench 页面持有本页唯一的 Scrollbar，绑定本页真实滚动容器。
3. Vertical Scrollbar 位于页面视口右缘，纵向贯穿整个页面视口，不从表头下方开始。
4. Horizontal Scrollbar 位于页面视口底缘。
5. 该规则适用于全部 Workbench 页面，Search 与 Shiori 二级页面使用同一套页面承载结构。
6. Scrollbar 的外观、尺寸、圆角、Thumb 几何和交互沿用已统一的 Scrollbar 规范，本需求只改变归属与位置。
7. Thumb 长度与位置必须按其绑定滚动容器的真实视口与内容尺寸计算，与所绘制的轨道长度口径一致。

## 内容区最小宽度

1. 右侧内容区存在最小宽度，取值随当前页面变化，不使用全局统一值。
2. 含表格的页面：最小宽度为该表格所有列达到列最小宽度时的内容宽度，加页面左右内边距。
3. 不含表格的页面：最小宽度为 App 最小宽度在 sidebar 收起时的状态。
4. 窗口最小宽度 = 当前页面右侧内容区最小宽度 + sidebar 展开时占用的宽度。
5. 展开 sidebar 时若窗口宽度不足，必须加宽窗口，不得继续压缩右侧内容区。
6. 切换页面导致最小宽度提高时，允许窗口被加宽。
7. 上述宽度必须由设计 Token 推导，不得在实现中写死数值。

# 范围

不包含：

1. Scrollbar 自动隐藏行为。
2. 窗口高度、位置、全屏行为的调整。
3. 表格列宽权重、列最小宽度本身的调整。
4. 页面内容、工具栏、Filter Panel 的功能变更。

# 验收标准

1. Search 与 Shiori 二级页面的纵向 Scrollbar 位于页面视口右缘并贯穿整页高度。
2. Search 与 Shiori 二级页面的横向 Scrollbar 位于页面视口底缘。
3. 表格区域内部不再出现任何 Scrollbar。
4. 其余 Workbench 页面的 Scrollbar 位置没有回归。
5. 表格的虚拟滚动、选择、行高、Hover 和拖动定位行为没有回归。
6. 窗口缩到最小时，含表格页面的表格恰好处于列最小宽度状态。
7. 窗口处于最小宽度时展开 sidebar，窗口加宽且右侧内容区宽度不变。
8. 无表格页面在 sidebar 收起时的最小宽度等于 App 最小宽度。
9. 最终视觉与交互由项目 Owner 在真实 Debug 客户端验收。
10. 验收通过后再更新 `UI Design System.md` 中的 Table、Scrollbar 与 Workbench 页面布局条目。