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

1. 表格拥有自己的 Horizontal Scrollbar，用于列宽溢出；Vertical Scrollbar 归页面所有。
2. Workbench 页面持有本页唯一的 Scrollbar，绑定本页真实滚动容器。
3. Vertical Scrollbar 位于页面视口右侧，纵向贯穿整个页面视口，不从表头下方开始。
4. Horizontal Scrollbar 分两级：页面级承担页面内容溢出，表格级承担表格列宽溢出，
   两者互不替代，可以同时出现。
   两级都画在页面可视区域的底部：只有表格级时，它贴着页面底部；页面级出现后，
   改由页面级贴着页面底部，表格级往上让出一条滚动条的高度。
   表格级的长度与表格宽度一致，页面级的长度与整个页面宽度一致。
5. 该规则适用于全部 Workbench 页面，Search 与 Shiori 二级页面使用同一套页面承载结构。
6. Scrollbar 的外观、尺寸、圆角、Thumb 几何和交互沿用已统一的 Scrollbar 规范，本需求只改变归属与位置。
7. Thumb 长度与位置必须按其绑定滚动容器的真实视口与内容尺寸计算，与所绘制的轨道长度口径一致。

## 页面内容最小宽度

1. 所有 Workbench 页面共用同一个页面内容最小宽度，取值为 App 窗口最小宽度，
   由设计 Token 推导，不得写死数值。
2. 可用宽度低于该值时，页面内容停止缩减，横向溢出由页面底部的 Horizontal
   Scrollbar 承担。
3. App 窗口最小宽度保持不变。收起 sidebar 时可用宽度恒不低于该值，因此仅在
   窄窗口展开 sidebar 时才会触发页面级横向滚动。
4. 表格另有自身的最小内容宽度，由列最小宽度之和决定。表格区域窄于该值时，
   仅表格内部横向滚动，页面其余部分不受影响。
5. 标题、工具栏、Filter 面板、封面与卡片网格按可用宽度自适应或重排，
   不被表格最小宽度顶住，保证窗口变窄时操作仍可进行。
6. 页面左右内边距属于页面内容，随页面级横向滚动一起移动；表格级横向滚动
   不移动页面内边距。

# 范围

不包含：

1. Scrollbar 自动隐藏行为。
2. 窗口高度、位置、全屏行为的调整。
3. 表格列宽权重、列最小宽度本身的调整。
4. 页面内容、工具栏、Filter Panel 的功能变更。

# 验收标准

1. Search 与 Shiori 二级页面的纵向 Scrollbar 位于页面视口右侧并贯穿整页高度。
2. Search 与 Shiori 二级页面的横向 Scrollbar 位于页面视口底部。
3. 表格区域内部不再出现任何纵向 Scrollbar。
4. 其余 Workbench 页面的 Scrollbar 位置没有回归。
5. 表格的虚拟滚动、选择、行高、Hover 和拖动定位行为没有回归。
6. 逐渐减小窗口宽度（sidebar 收起）时，页面底部不出现横向滚动条，
   表格外的组件自适应或重排，操作仍可进行。
7. 窗口宽度小于表格最小内容宽度时，表格自身的横向滚动条贴着页面底部出现，
   页面其余部分不随之移动。
8. 窄窗口展开 sidebar 时，页面内容停止缩减，页面视口底部出现横向滚动条。
9. App 窗口最小宽度与改动前一致。
10. 最终视觉与交互由项目 Owner 在真实 Debug 客户端验收。
11. 验收通过后再更新 `UI Design System.md` 中的 Table、Scrollbar 与 Workbench 页面布局条目。
