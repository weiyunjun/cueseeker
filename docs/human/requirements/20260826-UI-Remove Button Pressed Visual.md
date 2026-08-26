# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Buttons、Navigation、Menus、Media、Player Controls、Interaction Motion）

# 需求描述

## 1. 取消按下视觉

所有按钮、卡片、菜单项、Sidebar 项在鼠标按住期间不产生任何额外视觉变化，包括缩放、变色、压暗与阴影改变。按住期间维持按下之前的 Default、Hover、Selected、Highlighted、Open 或 Focused 外观。

覆盖范围：

1. 视频卡片、库文件夹卡片、Shiori 列表卡片的按下缩放。
2. 剧集编号按钮的按下缩放。
3. 播放页圆形按钮、倍速胶囊按钮、倍速菜单项的按下缩放与按下配色。
4. Sidebar 顶层导航项与其展开箭头的按下压暗。
5. 其余沿用系统默认按下压暗的按钮：Workbench 通用按钮、主按钮、危险按钮、纯文字动作按钮、工具条按钮、图标按钮、输入框清除按钮、弹层行、封面摘要动作按钮、结果分组标题、库文件夹标题、播放页音量与窗口控制按钮、Command Panel 行、Playback Overlay 顶栏按钮、设置页分段控件、表格复选框。

## 2. Token 清理

`--scale-library-media-card-pressed` 在本需求后无任何组件使用，从设计系统与实现中一并移除。

## 3. 不变项

1. Hover、Selected、Highlighted、Open、Focused、Disabled 的外观与触发条件不变。
2. 焦点环不属于按下视觉，保持现状；菜单打开时的焦点处理沿用 `docs/human/design/UI Application Rules.md`。
3. 按钮的点击判定区域、命中范围与动作行为不变。
4. 播放页进度条与音量条的拖动反馈不属于按下视觉，不受影响。

# 验收

1. 逐类按钮与卡片按住鼠标不放，画面与按下之前完全一致；松开后动作照常执行。
2. Sidebar 顶层导航项按住不放不出现压暗。
3. 在 Hover 状态下按住，Hover 外观保持不变，既不叠加也不消失。
4. 倍速菜单项按住不放只显示 Highlighted 背景，无缩放。
5. `--scale-library-media-card-pressed` 在设计系统与代码中均无残留。
6. 现有自动化端到端与单元用例全部通过。