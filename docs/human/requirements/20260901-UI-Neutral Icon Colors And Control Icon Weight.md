# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon、Text，以及引用这三个图标色 token 的组件与布局条目）

# 需求描述

## 1. 目标

图标色并入中性文字色，三个偏蓝的图标色 token 全部退役。

## 2. 默认态

1. 现使用 `--color-icon-default` 的图标改为 `--color-text-secondary`：搜索框放大镜、Sidebar 一级与二级项图标、Settings 窗口的分类图标、Library / File 文件树的行图标、Destructive Button 的前置图标。
2. `--color-icon-default` 退役。

## 3. 更淡的默认态

1. 现使用 `--color-icon-muted` 且不表示禁用的图标改为 `--color-text-muted`：Library 列表行末的箭头、Library / File 文件树的展开箭头、Shiori 列表封面与视频封面的占位图标、表格内的 Cue 状态指示图标及其 Hover 底色。
2. `--color-icon-muted` 退役。

## 4. 禁用态

1. 现使用 `--color-icon-disabled` 的图标改为 `--color-text-disabled`：Toolbar Button 的前置图标与下拉指示器、Button 与 Destructive Button 的前置图标、Menu Item 的图标、Checkbox 的控件色。
2. 搜索框放大镜的禁用态现使用 `--color-icon-muted`，一并改为 `--color-text-disabled`。
3. `--color-icon-disabled` 退役。

## 5. 字重

1. 第 2 节列出的图标，字重统一改用 `--weight-control-icon`。实际发生变化的是搜索框放大镜与文件树行图标，由 Regular 改为 Medium；其余本已是该取值。
2. 第 3 节与第 4 节涉及的图标，字重不变。

## 6. 保持不变

1. `--color-icon-on-dark` 不变。
2. 播放器 chrome 的全部图标不变，继续使用 `--color-player-*`。
3. Progress Indicator 的 Spinner 不在本次范围。
4. 全部图标的尺寸与位置不变，按钮的背景、边框与状态规则不变。

# 验收

1. 界面上不再出现 `#667085`、`#98A2B3` 及其 Dark 对应值。
2. 搜索框内的放大镜与清除按钮颜色一致、字重一致。
3. Library 列表行末箭头、文件树展开箭头、封面占位图标、表格 Cue 状态指示图标比正文更淡，且明显深于禁用态。
4. 各类按钮与菜单项在禁用时的图标色与 `--color-text-disabled` 一致。
5. `--color-icon-default`、`--color-icon-muted`、`--color-icon-disabled` 不再出现在设计系统与代码中。
6. Light 与 Dark 两个主题分别核对以上各项。
7. 本次改动不新增任何自动化端到端或单元用例的失败。