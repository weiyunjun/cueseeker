# 版本
main

# 关联设计
- docs/human/design/UI Design System.md（Playback Collage Editor Layout、Search Field、Focus、Subtitle Focus Motion）
- docs/human/design/UI Application Rules.md（Hover 与选中、按下、更高层界面的屏蔽、菜单模态、指针）

# 需求描述
1. 现状：Collage 预览只显示合成图，与右侧字幕区没有交互。
2. 目标：鼠标移到预览中某张已生成的截图上出现边框，点击后右侧字幕区焦点跳到该截图的第一条字幕。仅限鼠标操作。

# 交互规则
1. 截图以组为单位。一组的字幕条在整图中连续堆叠，边框覆盖该组的整段区域。
2. 边框颜色 `--color-border-focus`，宽度 `--border-width-control`（新增，`1px`，与搜索框聚焦边框一致），画在段矩形内侧，矩形无圆角。
3. 边框只在指针真实移动时按指针位置重判。滚轮滚动预览不改变边框，边框随图一起滚动。指针移出图片（含图下方空白）时该次移动清除边框。
4. 预览图任何一次重新发布（原位覆盖、插入、移除、清空）都清除边框；指针不移动则不再出现。
5. 边框只有 hover 一种状态，没有持久的选中状态。
6. 左键按下与松开落在同一段才触发，动作在松开时发生；点击同时把边框放到该段。
7. 点击是命令式的：用当时屏幕上那张图的分段表决定目标，发出后不再校验图片是否变化。占位图按占位图自己那组算。
8. 目标是该组内 Reel 序号最小的字幕。跳转表现与滚轮一致：沿用 `--duration-subtitle-focus-scroll` 与 `--easing-subtitle-focus-scroll` 动画滚到目标并提交焦点，只移动焦点，不改变勾选。门控与键盘导航一致。
9. 被 Command Panel 覆盖或菜单打开时不响应指针移动与点击。指针形状保持箭头。
10. 无截图或点在图下方空白：无边框、无动作。渲染进行中只要有图就正常响应。

# 改动内容
1. 合成函数返回整图时一并返回每组在整图中的像素高度；预览 Store 每次发布图片时同时发布按显示顺序的分段表（段高、该组第一条字幕的 Reel 序号），图与分段表为同一次发布。
2. 预览视图按自身 mouse-moved 事件坐标判定 hover 段并绘制边框，按上述规则清除；处理按下与松开。
3. 会话层新增跳到指定序号的入口，复用现有键盘导航请求通道，Reel 不改。
4. 代码新增控件边框宽度常量对应 `--border-width-control`，搜索框现有写死的 1pt 改为引用该常量。

# 修改流程
## 1. 分段表发布与预览视图 hover 边框
## 2. 点击跳转接入会话层
## 3. 端到端验证：mouseMove 出框、click 跳转、勾选改变后清框（现有 E2E 能力）

# 设计文档
验收通过后再更新 UI Design System（新增 `--border-width-control`；Search Field Container 补 Border Width；Playback Collage Editor Layout 新增 Collage Group Frame 与 Group Hovered 状态）与 UI Application Rules（Hover 与选中补长截图规则）。