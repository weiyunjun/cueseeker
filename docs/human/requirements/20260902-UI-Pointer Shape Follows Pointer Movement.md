# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（指针、Hover 与选中、菜单模态、更高层界面的屏蔽）
- `docs/human/design/UI Design System.md`（Media Card、Table Cell / Interactive Text、Playback Cue Reel）

# 关联需求

- `docs/human/requirements/20260826-UI-Pointer Cursor Single Authority.md`
- `docs/human/requirements/20260830-Bug-Pointer Shape Sticks Outside The Table.md`

# 需求描述

## 1. 目标

指针形状此前由承载框架按指针下方的几何持续重算，滚动、布局变化与键盘导航都会改变形状。本需求把形状改为只在指针移动与三类复位事件上改变，规则正文见第 2 节。

## 2. 指针规则

### 定义
1. 鼠标默认样式：即最常见的箭头样式。鼠标特殊样式：在CueSeeker中包括Grab样式和I-beam样式。
### 规则
1. 鼠标Grab样式出现场景：1. 表格中，鼠标移动到字幕文字内容上时变为Grab样式。表格包括：Workbench Search界面的表格、Shiori二级界面的表格。2. 鼠标移动到封面卡片组件上，变为Grab。封面卡片组件包括：Library一级界面的封面卡片、Library二级界面的封面卡片、Recent一级界面的视频和Shiori的封面卡片、Recent Videos界面的封面卡片、Recent Shioris界面的封面卡片、Shiori一级界面的封面卡片、Playback Overlay Playlist界面的封面卡片、Command Panel Recent Videos界面的封面卡片、Command Panel Recent Shioris界面的封面卡片。
2. 鼠标I-beam样式出现场景：1. 鼠标移动到任何文字可以按下左键拖拽鼠标选中的、且不变为鼠标Grab样式的区域，变为I-beam样式。2. 鼠标移动到可以输入文本的区域，例如搜索框、编辑列表名称、编辑列表描述等。
3. 界面切换，会将鼠标样式恢复为默认样式。
4. 弹出菜单或Dialog等，会将鼠标样式恢复为默认样式。
5. 当鼠标Grab样式对应的hover/select效果被其他操作改变时，鼠标变回默认样式。
### 规则解释
1. 规则1和规则2描述了：鼠标移动。这意味着除非其他规则影响，否则鼠标自身位置没有变化的情况下，不会主动改变鼠标样式。之所以这么设置，是出于防止鼠标hover和键盘操作冲突的考虑。注意只是滚动鼠标滚轮或按下鼠标左键不会改变鼠标样式。
2. 规则优先级：规则5 > 规则4 > 规则3 > 规则2 = 规则1。 下面会描述。注意这些规则，优先级会低于鼠标位置变化。也就是说，当鼠标移动和5条中的若干条规则发生冲突，会优先判断鼠标移动带来的影响。
3. 规则3界面切换补充说明：Sidebar标签切换；Library一级界面和Library二级界面的Video/File之间切换；Library一级界面/二级界面切换；Shiori一级界面/二级界面切换；进入/退出播放页；进入/退出Playback Overlay；Playback Overlay界面中切换Current/Playlist/Collage；Command Panel 开关及页面切换。
4. 为了帮助你理解，我描述几个具体场景：1. 在表格中，鼠标位于某一句很长的字幕的右侧边缘，显示为Grab样式，此时滚动鼠标滚轮，不移动鼠标，虽然新的位置下可能没有字幕文字内容，但根据规则1和规则5，保持为Grab样式，hover效果停留在鼠标滚动前的那一行。2. 在表格中，鼠标位于某一句很长的字幕的右侧边缘，显示为Grab样式，此时右键弹出菜单，根据规则4，鼠标变为默认样式。3. 在Playback Overlay Current界面中，鼠标位于某句字幕上，显示为I-beam样式，此时用键盘方向上下键导航，或者滚动鼠标滚轮，根据规则2，鼠标保持为I-beam样式。4. 在Playback Overlay Current界面中，鼠标位于某句字幕上，显示为I-beam样式，此时选中几个字，弹出了菜单，根据规则4，鼠标变为默认样式。5. 在Command Panel界面中，鼠标点击Recent Videos，尽管点击后位于某个封面卡片组件上，根据规则3，鼠标变为默认样式，hover效果根据已有实现选中第一个卡片。6. 在Playback Overlay Current界面中，鼠标位于某句字幕上，显示为I-beam样式，按下Tab切换到Playback Overlay Playlist界面（视频Playlist），尽管鼠标可能位于封面卡片上，但根据规则3，鼠标变为默认样式。7. 在Playback Overlay Playlist界面（视频Playlist），鼠标移动到某个封面卡片上，显示为Grab样式，此时用键盘方向键将Select切换到其他视频，视觉上hover/select效果已经变化，规则5和规则1有冲突，规则5优先级更高，鼠标变为默认样式。

## 3. 作废与保留

1. `20260826-UI-Pointer Cursor Single Authority.md` §3「判定归属」作废：形状不再由承载框架的指针机制决定。
2. 应用规则「指针」第 1 条由第 2 节的清单替换；第 4 条（卡片手型需要 macOS 15）作废，卡片 Grab 不再有系统版本差异；第 2、3、5、6 条不变。
3. 表格 Select Mode 整行箭头不变。Cover Summary 不是卡片，保持箭头。

## 4. 实现约束

1. 形状由 App 统一持有，只有一个当前形状。SwiftUI 的指针样式声明、表格与 Reel 的光标区域及其重算调用全部移除，不保留第二条路径。
2. 形状只在指针真实移动时按指针下方对象重判；滚轮、按键、布局与内容变化不重判。规则 3、4、5 的事件把形状置为默认。
3. 命中判定复用现有几何与 hover 上报，不新增判定来源。文本输入控件按是否可编辑判定为 I-beam。
4. 规则 5 的触发定义：最近一次移动命中的 Grab 对象，经非指针路径失去 hover/选中。包括键盘移动卡片选中，以及表格重载导致 hover 行消失。
5. 层级冻结与菜单模态沿用现有登记表，不新增状态。

## 5. 执行步骤

1. 测量：记录三种场景下谁在何时设置光标：SwiftUI 卡片上移动；指针静止时滚动表格、Reel 与卡片网格；键盘导航。若测量显示框架在事件之外异步重算且无法压制，停止并报告，不加补丁。
2. 按测量结果确定 App 重申形状的时机，实现形状持有者，移除框架声明。
3. 接入规则 3 的界面切换通知与规则 4、5 的复位调用。
4. 单元测试覆盖规则解释 4 的 7 个场景（事件序列 → 形状）。
5. 更新 `docs/engineering/04_architecture_rules.md` 中"形状必须来自承载框架"的条目。

## 6. 设计文档

验收通过后，再将第 2 节写入应用规则「指针」章节，并在 Design System 相关组件补 Pointer 条目。

# 验收

1. 规则解释 4 的 7 个场景逐一成立。
2. 规则 1 清单中的每类表格与卡片：移动到其上为 Grab，移出后为箭头；不可用内容为箭头。
3. 规则 2 清单中的每类文本与输入框：移动到其上为 I-beam；表格 Select Mode 整行为箭头。
4. 现有自动化端到端与单元用例全部通过。
5. 端到端验证由需求方负责。形状本身由需求方人工验收。