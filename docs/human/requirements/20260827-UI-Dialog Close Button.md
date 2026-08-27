# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialogs / Dialog、Icon Button）
- `docs/human/design/UI Application Rules.md`（界面层级）

# 需求描述

## 1. 范围

1. Edit Cover Dialog、Shiori List Editor Dialog、Confirmation Dialog。
2. Settings 窗口内的系统确认界面、系统文件选择面板、播放器窗口与 Settings 窗口不在范围内。

## 2. 呈现

1. 对话框 Header 行右端加一个关闭按钮，与标题同一行，右边距等于对话框自身的内边距。
2. 组件为 Icon Button / Default，图标为 xmark，Default、Hover、Focused、Disabled 沿用 Icon Button 已定义的状态。
3. 不新增、不修改、不替换任何 token。
4. 指针为箭头。

## 3. 行为

1. 关闭按钮的动作是关闭对话框，与该对话框是否存在 Cancel 无关。
2. Edit Cover 与 Shiori List Editor 在保存中时，关闭按钮禁用。
3. Confirmation 的关闭按钮只关闭对话框，不触发调用方传入的取消回调。
4. 不新增快捷键，Esc 与回车行为不变。

## 4. 保持不变

1. 三个对话框的标题、正文、按钮文案、按钮样式与顺序不变。
2. 对话框的压暗范围、输入屏蔽与叠加规则不变。

# 验收

1. 三个对话框右上角都出现 X，位置与视觉一致。
2. 点击 X 关闭对话框；在现有三个对话框上，其结果与点击 Cancel 一致。
3. Edit Cover 保存中、Shiori List Editor 保存中，X 呈禁用外观且点击无响应。
4. X 有 Hover 与 Focused 反馈，指针为箭头。
5. Esc 与回车行为与本需求前一致。
6. 现有自动化端到端与单元用例全部通过。