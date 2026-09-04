# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Navigation、App Sidebar Layout、App Topbar Layout）
- `docs/human/design/UI Application Rules.md`（按下、指针）

# 需求描述

## 1. 背景

进出播放页时视频画面尺寸变化，工作台外壳在动画期间被冻结，避免动画途中被点击引起布局竞态。冻结期间返回按钮、Sidebar Toggle 与 Sidebar 全部导航项同时切成禁用配色并整体压暗。双击顶栏缩放窗口复用了同一段冻结，于是缩放动画期间整条 Sidebar 变灰，只有 Settings 项因为被写死为始终可用而保持正常。

Sidebar 在任何时候都不应该出现禁用外观。

## 2. 尺寸过渡期间不改变外观

尺寸过渡冻结期间，Sidebar 全部项、Sidebar Toggle 与返回按钮维持进入冻结之前的外观，包括 Default、Selected 与 Focused，不切换文字与图标颜色，不整体压暗，不产生任何其它视觉变化。冻结的开始与结束在这三处都不可见。

## 3. 冻结的输入行为不变

冻结期间这三处仍然不响应点击，动作不发生；冻结结束后恢复响应。冻结的触发场景与时长维持现状，双击顶栏缩放窗口仍然属于冻结场景。

## 4. 硬编码不透明度清理

冻结期间叠加在 Sidebar 项与返回按钮上的 0.62 不透明度是设计系统中不存在的实现细节，一并移除，不用其它令牌替代。

## 5. 不变项

1. 返回按钮在一级页面本身的 Back Disabled 状态不变，其外观沿用现有规则；本需求只取消冻结带来的外观变化。
2. Sidebar 项的 Selected 外观、选中范围、点击动作与导航结果不变。
3. Sidebar Toggle 的展开收起行为与窄窗口自动收起不变。
4. Settings 项现状不变。
5. 冻结范围内的其它界面不在本需求范围内。

## 6. 文档同步

本需求验收后，`docs/human/design/UI Design System.md` 中 Sidebar Item 与 Sidebar Toggle 的 Disabled 状态在项目内已无触发条件，与本轮 UI 细调结果一并整理。

# 验收

1. 双击顶栏放大与还原窗口，整个动画期间 Sidebar 全部项、Sidebar Toggle 与返回按钮的颜色与明暗与动画前完全一致，选中项的橙色底与文字也不变暗。
2. 同一动画期间点击这三处不产生任何动作，动画结束后点击恢复正常。
3. 进出播放页的尺寸过渡期间，同样满足第 1、2 条。
4. 一级页面的返回按钮仍保持 Back Disabled 外观。
5. 代码中不再存在 0.62 的禁用不透明度。
6. 现有自动化端到端与单元用例全部通过。