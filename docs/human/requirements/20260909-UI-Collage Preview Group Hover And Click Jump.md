# 版本
main

# 关联设计
- docs/human/design/UI Design System.md（Playback Collage Editor Layout、Search Field、Focus、Subtitle Focus Motion、Interaction Motion）
- docs/human/design/UI Application Rules.md（Hover 与选中、按下、更高层界面的屏蔽、菜单模态、指针）

# 需求描述
1. 现状：Collage 预览只显示合成图，与右侧字幕区没有交互。
2. 目标：鼠标移到预览中某张已生成的截图上，该截图放大作为反馈；点击后右侧字幕区焦点跳到该截图的第一条字幕。仅限鼠标操作。
3. 第一版用 1px accent 边框作为 hover 反馈，验收时在画面上不够明显，改为与封面卡片一致的放大反馈。

# 交互规则
1. 截图以组为单位。一组的字幕条在整图中连续堆叠，hover 反馈作用于该组的整段区域。
2. hover 反馈是该段整体放大：以段中心为原点缩放到 `--scale-collage-group-hover`（新增，`1.02`），动画时长 `--duration-collage-group-hover`（新增，`0.12s`）、easeOut，与封面卡片的 hover 放大一致。不画边框，不改背景色，不改指针形状。
3. 未 hover 时的画面与改动前完全一致，预览图的位置与尺寸不变，不为放大预留空间。放大后超出原段范围的部分四周都完整显示、不被裁切：竖向盖住相邻段的边缘，横向溢出到图片两侧的留白。视口边缘只多露出放大增加的那一圈，视口外原本看不到的内容不因放大露出。
4. hover 段只在指针真实移动时按指针位置重判，判定区域随放大后的矩形变化，重叠处放大的段优先。滚轮滚动预览不改变 hover 段，放大的段随图一起滚动。指针移出该段（移到相邻段、图下方空白或图片之外）时该段以同样的动画缩回原尺寸，新落入的段同时放大。
5. 预览图任何一次重新发布（原位覆盖、插入、移除、清空）都结束 hover，指针不移动则不再放大。尺寸保持视觉连续：新图中位于指针位置的段继承当前显示尺寸，以固定速度缩回原尺寸（`--scale-collage-group-hover` 到 1 用 `--duration-collage-group-hover`，剩余距离按比例缩短）；缩小过程中再次发布，指针位置的段继承当时的尺寸继续以同样速度缩小，只缩小不放大。指针位置没有段时不做过渡。
6. 放大只有 hover 一种状态，没有持久的选中状态。
7. 左键按下与松开落在同一段才触发，动作在松开时发生；点击同时把 hover 放到该段。
8. 点击是命令式的：用当时屏幕上那张图的分段表决定目标，发出后不再校验图片是否变化。占位图按占位图自己那组算。
9. 目标是该组内 Reel 序号最小的字幕。跳转表现与滚轮一致：沿用 `--duration-subtitle-focus-scroll` 与 `--easing-subtitle-focus-scroll` 动画滚到目标并提交焦点，只移动焦点，不改变勾选。门控与键盘导航一致。
10. 被 Command Panel 覆盖或菜单打开时不响应指针移动与点击。指针形状保持箭头。
11. 无截图或点在图下方空白：不放大、无动作。渲染进行中只要有图就正常响应。
12. 滚轮滚动后放大段停留在视野之外造成的不协调，本需求不处理，留待下一个需求单。

# 改动内容
1. 合成函数返回整图时一并返回每组在整图中的像素高度；预览 Store 每次发布图片时同时发布按显示顺序的分段表（段高、该组第一条字幕的 Reel 序号），图与分段表为同一次发布。
2. 预览视图按自身 mouse-moved 事件坐标判定 hover 段，把该段作为独立图层叠在原图之上、置于视口裁切之外，按上述规则缩放，每次缩放都从图层当时的显示尺寸接续，随滚动同步位置；处理按下与松开。
3. 会话层新增跳到指定序号的入口，复用现有键盘导航请求通道，Reel 不改。
4. 代码新增控件边框宽度常量对应 `--border-width-control`，搜索框现有写死的 1pt 改为引用该常量。
5. 代码新增缩放倍数与时长常量对应 `--scale-collage-group-hover` 与 `--duration-collage-group-hover`，值与封面卡片相同。

# 修改流程
## 1. 分段表发布与预览视图 hover 边框
## 2. 点击跳转接入会话层
## 3. 端到端验证：mouseMove 出框、click 跳转、勾选改变后清框（现有 E2E 能力）
## 4. 边框改为段放大，含四周不裁切与尺寸连续的缩回过渡，回归第 3 步的验证

# 设计文档
验收通过后再更新 UI Design System（新增 `--border-width-control`、`--scale-collage-group-hover`、`--duration-collage-group-hover`；Search Field Container 补 Border Width；Playback Collage Editor Layout 的 States 新增 Group Hovered，描述段放大与缩回）与 UI Application Rules（Hover 与选中补长截图规则）。