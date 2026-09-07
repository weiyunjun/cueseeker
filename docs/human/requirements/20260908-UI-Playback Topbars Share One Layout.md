# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Player Topbar Layout、Playback Topbar Layout、Icon Button、Player Title、Tabs、Tab、Height、Spacing、Player Chrome）
- `docs/human/design/UI Application Rules.md`（界面层级、全屏）

# 需求描述

## 1. 目标

Playback、Playback Overlay Current、Playback Overlay Playlist、Collage 四个界面的顶栏改为同一套布局：高度与红绿灯带一致，退出按钮改为 Icon Button，右侧加入任务与设置入口。

## 2. 尺寸与对齐

1. 四个界面的顶栏高度均为 `--height-app-topbar`（45px）。`--height-player-topbar` 退场；Overlay 顶栏当前未入档的 54px 一并取消。
2. 顶栏内所有元素垂直居中，与红绿灯同一中线。红绿灯位置不变。
3. 任务面板表头高度保持改动前的 54px，不随本次变化。

## 3. 结构

自左向右：

1. Playback：红绿灯、退出、Display Title、任务、设置。
2. Overlay Current：红绿灯、退出、Current 与 Playlist 的 Tabs、Collage、任务、设置。
3. Overlay Playlist：红绿灯、退出、Current 与 Playlist 的 Tabs、任务、设置。
4. Collage：红绿灯、退出、Editing Collage 标题、Collage、任务、设置。

Display Title、Tabs 与 Editing Collage 标题在顶栏内水平居中。右侧功能区贴右边界，右边距 `--spacing-4`，按钮间距 `--spacing-1`。退出按钮与红绿灯的间距不变。

## 4. 按钮

1. 退出、Collage、任务、设置均为 Icon Button / Default。退出图标 `chevron.left`，无 Open 态；Collage、任务、设置有 Open 态，Collage 在 Collage 界面为 Open。
2. 任务与设置的组件、角标、Open 态、行为与 Workbench 顶栏相同：任务打开任务面板，面板打开期间为 Open；设置打开设置窗口，窗口打开与最小化期间为 Open。
3. 视频页表面上的 Icon Button：图标色 `--color-player-text-primary`，Hover 与 Open 背景 `--color-player-control-bg-hover`。Overlay 表面沿用现有 Surface Hover 规则。
4. 视频页顶栏的三个按钮跟随 Player UI 显隐与交互抑制，与改动前的退出按钮一致；全屏时视频页顶栏照旧隐藏，Overlay 顶栏照旧显示。

## 5. 标题

1. Display Title 与 Editing Collage 标题统一为 `--font-size-body`（14px）、字重 600。`--font-size-player-topbar-title` 退场。
2. Display Title 保留白色、阴影、最大宽度与尾部截断。
3. Editing Collage 标题去掉图标，颜色为 `--color-tab-selected`。

## 6. 文案

`playback.collage.editing` 改为：简体 `正在编辑长截图…`、繁体 `正在編輯長截圖…`、英文 `Editing Collage…`，省略号均为单字符。

## 7. 设计文档同步

本需求验收通过后再更新设计文档：Height 移除 `--height-player-topbar`，Task Panel Layout 记录表头高度；Player Topbar Layout 与 Playback Topbar Layout 改为本需求的结构、尺寸与状态；Icon Button 的 Surface Hover 表加入视频页表面；Player Title 字号；App Topbar Layout 的 Hidden On Playback 改为只隐藏 Workbench 顶栏本身。

# 验收

1. 四个界面顶栏高 45px，红绿灯位置与改动前一致，退出、标题、Tabs、右侧按钮与红绿灯同一中线。
2. 四个界面自左向右的元素顺序与第 3 节一致，标题与 Tabs 居中，右侧按钮贴右边界，间距 4px，右边距 16px。
3. 退出按钮为 Icon Button 外观，Hover 有背景，点击返回来源页；Overlay 打开与关闭时它的位置不变。
4. 视频页与 Overlay 上分别点击任务按钮打开任务面板，按钮为 Open；关闭面板后回到 Default。角标随任务数显示。
5. 视频页与 Overlay 上分别点击设置按钮打开设置窗口，按钮为 Open；窗口最小化仍为 Open，关闭后回到 Default。
6. 进入 Collage 界面，Collage 按钮为 Open，标题无图标、文字带省略号；退出后按钮回到 Default。
7. 视频页 Player UI 隐藏时三个按钮一并隐藏且不可点击；全屏时视频页顶栏隐藏，Overlay 顶栏仍可用。
8. Display Title 与 Editing Collage 标题为 14px、600；Display Title 过长时尾部截断。
9. 任务面板表头高度与改动前一致。
10. Light 与 Dark、简体、繁体、英文分别核对四个界面的顶栏。
11. 现有自动化端到端与单元用例全部通过。