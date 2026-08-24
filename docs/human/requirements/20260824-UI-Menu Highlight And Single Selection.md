# 版本

main

# 需求描述

## 1. 适用范围

菜单:Workbench 表格行右键菜单、Workbench 封面右键菜单、视频播放倍速菜单、Playback Overlay 与 Command Panel 的选中文字菜单。

列表:Command Panel 一级界面选项列表、Command Panel Recent Videos、Command Panel Recent Shioris、Playback Overlay Video Playlist。

## 2. 高亮与选中的区分

1. 高亮表示当前项,随键盘与鼠标移动,全局同时只允许存在一个。
2. 选中表示已经生效的值,仅倍速菜单具有,表现为打勾,不带背景。
3. 列表界面没有「已生效的值」这一层,高亮即选中。

## 3. 默认高亮

1. 菜单打开时默认高亮第一项。
2. 倍速菜单打开时默认高亮当前倍速。
3. 列表界面现有的默认选中规则保持不变。

## 4. 键盘

1. 上下键移动高亮;到达首项或末项后停住,不循环。
2. 上下键操作时隐藏鼠标指针。
3. 回车执行当前高亮项。Esc 关闭、左右键展开与收起子菜单等现有行为保持不变。

## 5. 鼠标

1. Hover 本身不改变高亮。
2. 只有在收到真实鼠标移动之后,Hover 才把高亮移动到所指项。
3. 鼠标指针处于隐藏状态时,Hover 不产生任何效果。
4. 任何时刻不得出现两处高亮。

## 6. 作废的旧规则

本需求显式作废 `docs/human/requirements/20260814-Feature-Shared Video Card And Media Navigation Interaction.md` 中的以下三条:

1. §1「二者状态相互独立,可以同时出现在不同卡片上」。同条中「Selected 和 Hover 均作用于整张卡片,并保持 Recent Videos 现有视觉规则」继续有效。
2. §3「Hover 仅为鼠标视觉反馈,不得改变或清除键盘/控制器的 Selected 状态」。
3. §3「鼠标跨卡片移动只能改变 Hover,不得改变 Selected」。

该文档其余规则继续有效,包括取消强制居中、仅滚动到最近边缘,以及 Video Playlist 每个 Session 的首次默认选择规则。

## 7. 样式约束

1. 不新增、不修改、不替换任何颜色、尺寸、圆角与间距 token。
2. 各界面沿用其现有的高亮背景表现;本需求只改变该表现挂在哪一个状态上。
3. 禁止为单个界面增加私有特殊实现。

# 验收

1. 四个菜单打开后第一项默认高亮;倍速菜单打开后当前倍速默认高亮。
2. 上下键在四个菜单与四个列表界面均可移动高亮,到头停住。
3. 键盘操作后鼠标指针隐藏,且高亮不被指针下方的项目改变。
4. 鼠标移动后指针恢复显示,Hover 生效并移动高亮。
5. 八个界面在任何时刻都只有一处高亮。
6. 倍速菜单的打勾始终停留在当前倍速上,不随高亮移动。
7. 第 3、4、5 条中依赖鼠标 Hover 的部分使用人工验收;其余使用现有自动化端到端测试覆盖,不为本需求新增鼠标能力。

# UI 文档同步

视觉验收完成后,由人类维护者更新并提交 `docs/human/design/UI Design System.md`:

1. 新增 Player Speed Menu 组件条目;目前只有 token,没有组件定义。
2. Menu 增加键盘与指针交互规则,Menu Item 补默认高亮规则。
3. Radio Menu Item 明确「打勾表示选中、背景表示高亮」的分离。
4. Media Card、Recent Watching Card Layout、Recent Shiori Resume Row Layout 的状态表,将 Hover 与 Selected 合并为单一当前项状态。
5. Command Panel Root Layout、Command Panel Secondary Layout、Playback Playlist Layout 补键盘与指针规则。