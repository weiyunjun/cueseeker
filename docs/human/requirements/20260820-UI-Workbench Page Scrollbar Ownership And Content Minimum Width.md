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

## 页面内容最小宽度

1. 页面内容不存在独立的最小宽度常量。最小宽度由页面内组件自身的最小宽度决定。
2. 当页面内任何组件达到自身最小宽度、无法继续缩减时，页面内容整体停止缩减。
3. 此时页面内容横向溢出页面视口，由页面底缘的 Horizontal Scrollbar 承担滚动。
4. 页面标题、工具栏、Filter 面板、封面与表格属于同一个页面内容整体，
   共用同一个裁剪边界，并随同一个横向偏移一起移动，不得各自单独缩放或重排。
5. App 窗口最小宽度保持不变，不随页面或 sidebar 状态变化。
6. 展开 sidebar 只减少页面可用宽度，因此更早触发上述规则，不引入额外机制。
7. 含表格的页面（Search、Shiori 二级页）由表格列最小宽度触发该规则。
8. 不含表格的页面，页面内容最小宽度不低于「App 窗口处于最小宽度且 sidebar 收起时
   的右侧区域宽度」。窗口在最小宽度处展开 sidebar 时，这些页面同样停止缩减，
   内容完整渲染并由底部横向滚动条承担溢出。
9. 页面内组件自身的最小宽度大于上述值时，以组件自身的最小宽度为准。
10. 上述宽度必须由设计 Token 推导，不得在实现中写死数值。

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
6. 窗口缩到表格列最小宽度以下时，页面内容停止缩减，底部出现横向滚动条。
7. 横向滚动时，页面标题、工具栏、Filter 面板、封面与表格在同一条边界处被裁剪，
   并保持同步移动，不出现相互错位或空白间隙。
8. App 窗口最小宽度与改动前一致；展开 sidebar 不改变窗口最小宽度。
9. 窗口处于最小宽度、展开 sidebar 时，不含表格的页面内容仍按其最小宽度完整渲染，
   底部出现横向滚动条，内容不被压缩或重排。
10. 最终视觉与交互由项目 Owner 在真实 Debug 客户端验收。
11. 验收通过后再更新 `UI Design System.md` 中的 Table、Scrollbar 与 Workbench 页面布局条目。
