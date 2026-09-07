# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（App Sidebar Layout、App Topbar Layout、Icon Button、Sidebar Item、Spacing）
- `docs/human/design/UI Application Rules.md`（界面层级）

# 需求描述

## 1. 目标

Settings 入口从 Sidebar 移到 Workbench 顶栏右上角，使它在 Sidebar 收起时同样可用，并让按钮反映设置窗口是否打开。

## 2. Sidebar

1. 移除 Settings 项，以及它上方的弹性留白。Sidebar 只剩顶部安全区与导航区。
2. 导航项仍为 Search、Recent、Library、File、Shiori，位置、尺寸、留白不变。
3. `Sidebar Item / Action` 变体在本次之后没有使用者。

## 3. 顶栏 Settings 按钮

1. 顶栏 Trailing Function Region 自左向右为 Task Entry、Settings Entry，Settings 贴内容右边界。
2. 两者间距为 `--spacing-1`。Task 按钮因此左移一个按钮宽加该间距。
3. Settings Entry 为 Icon Button / Default，图标 `gearshape`，纯图标，无文字，无角标。
4. 状态为 Default、Hover、Open、Focused，与 Task Entry 同一套。按钮不接受启动焦点。
5. 尺寸过渡期间按钮与 Task Entry 一致，不冻结、不改变外观。
6. 顶栏在播放页隐藏时，按钮一并隐藏。

## 4. 行为

1. 点击打开设置窗口；设置窗口已打开时把它提到最前。与改动前的 Sidebar Settings 项一致。
2. 系统菜单的设置项与 ⌘, 不变。
3. 设置窗口打开期间按钮为 Open 态；最小化到 Dock 期间仍为 Open；关闭后回到 Default。
4. 设置窗口与主窗口是同级的独立窗口。在主窗口内按下鼠标会让主窗口升到设置窗口之上，这是系统的窗口活动次序，不做额外处理。
5. 设置窗口处于最小化时点击按钮，直接从 Dock 还原并成为最前，不得先在屏幕中央闪现一帧再播放还原动画。

## 5. 文案

1. 新增 `topbar.settings`：简体 `设置`、繁体 `設定`、英文 `Settings`，用于按钮的提示与无障碍名称。
2. 设置窗口标题改用新增的 `settings.window.title`，三语同上。该窗口隐藏标题，此文案不在界面上出现。
3. `sidebar.settings` 随之退场。

## 6. 设计文档同步

本需求验收通过后再更新设计文档：App Sidebar Layout 去掉 Flexible Spacer 与 Settings Region；App Topbar Layout 的 Trailing Function Region 加入 Settings Entry 并记录 Task 到 Settings 的间距；组件表删除 Sidebar Item 的 Action 变体。

# 验收

1. Sidebar 只有五个导航项，底部没有 Settings；Sidebar 展开与收起时导航项位置与改动前一致。
2. 顶栏右上角自左向右为任务按钮与 Settings 按钮，间距 4px，Settings 贴右边界；Sidebar 展开与收起时都在。
3. 点击 Settings 打开设置窗口，窗口位置、尺寸、内容与改动前一致。
4. 设置窗口打开期间按钮为 Open 外观；把设置窗口最小化到 Dock，按钮仍为 Open；关闭设置窗口，按钮回到 Default。
5. 设置窗口已打开时再次点击按钮，设置窗口回到最前；把设置窗口最小化到 Dock 后点击按钮，它从 Dock 还原，过程中屏幕中央不出现闪现的设置界面。
6. ⌘, 与系统菜单的设置项照常打开设置窗口，按钮同步变为 Open。
7. 进入播放页后顶栏隐藏，Settings 按钮一并隐藏；返回 Workbench 后恢复。
8. 悬停按钮显示提示文案；Light 与 Dark、简体、繁体、英文分别核对 Sidebar、顶栏与按钮外观。
9. 现有自动化端到端与单元用例全部通过。