# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Playback Feedback、Playback Feedback Overlay Layout、Player Chrome、Height、Size、Radius、Spacing、Typography、Shadow、Toast Motion）
- `docs/human/design/UI Application Rules.md`（界面层级）

# 需求描述

## 1. 目标

视频内反馈从 Center、Leading、Trailing 三个锚点收敛为画面正中一个锚点，样式由当前写死的数值改为引用已有令牌。本次不新增令牌。

## 2. 锚点

1. Playback Feedback 的 Position 输入取消，全部反馈固定出现在播放画面的正中。
2. 胶囊在画面内水平与垂直双向居中，位置不随 Player UI 显隐、全屏或 Overlay 开关变化。
3. 内容变长时胶囊以中心为基准向两侧延伸。
4. 方向由图标承担，不再由位置表达，也不加入方向性入场动效。

## 3. 样式

1. 高度 `--height-control`（40px）。
2. 圆角 `--radius-menu`（12px），取消全圆角。
3. 横向内距 `--spacing-3`（12px），图标与文字间距 `--spacing-2`（8px）。
4. 图标尺寸 `--size-player-circle-button-icon`（18px），颜色 `--color-player-text-primary`，不再单独投影。
5. 文字 `--font-size-body`（14px）、字重 `--font-weight-control`（500）、颜色 `--color-player-text-primary`，单行，超过 `--width-player-topbar-title-max`（520px）尾部截断。
6. 表面为背景 `--color-player-menu-bg`、毛玻璃与 0.5px 描边，不投阴影。与背景的分离由描边和底色承担，`--shadow-player-overlay` 不再用于播放反馈。
7. 反馈中的数字使用等宽数字，累计快进快退与音量变化时胶囊宽度不跳动。
8. 动效改用 `--duration-toast-motion` 与 `--easing-toast-motion`。

## 4. 层级

Playback Feedback 位于 Playback Overlay 与 Command Panel 之上，Subtitle Focus、Playlist、Command Panel 内触发的复制与 Save to Shiori 反馈在这些界面打开期间仍然可见。反馈依旧只有视觉，不接受输入，不参与界面层级与菜单模态。

## 5. 不变的部分

1. 每一条反馈的触发时机、图标、文案与停留时长保持现状。
2. 连续快进与快退的秒数累计以及超时清零行为保持现状。
3. Icon 与 Label 仍然都是可选的，全屏反馈保持无图标。

## 6. 设计文档同步

本需求验收通过后再更新设计文档：Playback Feedback 的 Anatomy 改为引用 Player Chrome 的浮层令牌、去掉 Shadow 并补齐 Sizes；Playback Feedback Overlay Layout 的 Position 由三值改为画面正中的单一锚点，并记录层级。

# 验收

1. 依次触发播放暂停、音量、倍速、字幕开关、全屏、快进快退、上一条下一条、复制、Shiori 各类反馈，全部出现在画面正中同一处。
2. 胶囊的中心与画面中心重合。
3. Player UI 显示与隐藏、进入与退出全屏、打开与关闭 Overlay，胶囊位置不变。
4. 连续按快进，秒数累计到三位数期间胶囊中心不动、数字不抖动。
5. 胶囊高 40px、圆角 12px、图标 18px、文字 14px，四周无可见阴影。
6. Subtitle Focus、Playlist、Command Panel 打开期间触发复制与 Save to Shiori，反馈可见且不遮挡这些界面的顶栏。
7. 列表名很长的 Save to Shiori 反馈在 520px 处尾部截断，不横穿画面。
8. 简体、繁体、英文分别核对全部反馈文案不换行、不溢出。
9. 现有自动化端到端与单元用例全部通过。