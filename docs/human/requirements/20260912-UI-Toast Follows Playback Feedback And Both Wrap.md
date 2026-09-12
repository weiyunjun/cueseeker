# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Toast、Playback Feedback、Player Chrome、Typography、Size、Spacing、Radius）
- `docs/human/design/UI Application Rules.md`（界面层级）
- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/Icon Registry.md`（尺寸与线宽表）

# 需求描述

## 1. 目标

Workbench 的 Toast 改用 Playback Feedback 的外观，两者的文案都改为换行，并修正 Toast 的位置与计时规则。两者仍是各自独立的组件，不合并。

## 2. Toast 外观

1. 表面照搬 Playback Feedback：背景 `--color-player-menu-bg`、毛玻璃、`--color-player-text-tertiary`（30%）描边、圆角 `--radius-playback-feedback`，不投阴影。浅色与深色外观相同，不分 Light / Dark。
2. 文字 `--font-size-toast`（16px）、字重 `--font-weight-control`、颜色 `--color-player-text-primary`，左对齐。
3. 新增图标槽位：尺寸 `--size-toast-icon`（23px，取自 `Icon Registry.md` 的尺寸与线宽表；表中未列出的尺寸不得使用），颜色 `--color-player-text-primary`，与文字间距 `--spacing-3`。
4. 图标独占一列，与第一行文字垂直居中；换行后各行的左边缘与第一行对齐，不进入图标所占宽度。
5. 同一事件在 Workbench 与播放页使用同一个图标。
6. 横向内距 `--spacing-4`，纵向内距 `--spacing-3`，高度由内容撑开，不设固定高度，不设最小宽度。

## 3. 换行与宽度

1. Toast 与 Playback Feedback 的文案都允许换行，不再尾部截断。
2. 实际宽度为内容宽度、最大宽度、窗口宽度减两侧 `--spacing-6` 三者中的最小值。
3. Toast 的最大宽度为 `--width-toast-max`（400px）；Playback Feedback 的最大宽度为 `--width-playback-feedback-max`（520px）。

## 4. Toast 位置

1. 最新一条 Toast 的中心与 App 窗口中心重合，窗口中心含 Sidebar 与顶栏在内。
2. 多条同时存在时，较早的依次向上堆叠，最新一条的落点不随数量变化。
3. 条间距 `--spacing-4`。

## 5. Toast 生命周期

1. 每条 Toast 出现时确定到期时刻，到点消失。App 是否有焦点、指针是否停在它上面、窗口是否可见都不影响计时。
2. 同时最多 4 条；再出现新的一条时，最早的一条立即消失，不排队等待。
3. 新触发的 Scenario ID 与文案同时与某条已显示的 Toast 相同时，重置那条的计时并把它移到最新位置，不新增一条。
4. Toast 不接受任何指针输入，落在它上面的点击穿透到下层。

## 6. Playback Feedback 的连带调整

1. `--height-playback-feedback` 由固定高度改为最小高度：单行时高度不变，换行时由内容撑开。
2. 纵向内距为 `--spacing-2`，单行时仍落在最小高度之内、由最小高度决定高度，换行后才由内距决定上下留白。横向内距不变。
3. 取消单行限制与尾部截断，按第 3 节换行，文字左对齐。
4. 最大宽度改用 `--width-playback-feedback-max`，不再引用 `--width-player-topbar-title-max`。
5. 图标与第一行文字垂直居中，换行后各行的左边缘与第一行对齐。

## 7. 不变的部分

1. 每个场景是否弹出反馈、文案、图标选择与停留时长保持现状，`Toast Usage Registry.md` 的内容不变。
2. Playback Feedback 的锚点、层级、动效、等宽数字与单槽替换保持现状。
3. Toast 的动效与 Scenario ID 保持现状。

## 8. 设计文档同步

本需求验收通过后再更新设计文档：Typography 补入 `--font-size-toast`，Size 补入 `--size-toast-icon`、`--width-toast-max`、`--width-playback-feedback-max`；Toast 的 Anatomy 补 Icon 与新表面、Sizes 补最大宽度与内距、States 去掉 Timer Paused；Playback Feedback 的 Height 改为最小高度、补入纵向内距并取消单行截断；新增 Toast Layout 一节记录锚点、堆叠方向、条间距、视口边距与层级；`UI Application Rules.md` 写明 Toast 不接受输入且点击穿透。

# 验收

1. Workbench 触发任一 Shiori 结果，Toast 为带图标的深色胶囊，浅色与深色外观一致，无阴影。
2. 单条 Toast 的中心与 App 窗口中心重合。
3. 连续触发多条，最新一条始终落在窗口中心，较早的向上堆叠。
4. 触发第 5 条时最早的一条立即消失，屏幕上始终不超过 4 条，没有延迟出现的 Toast。
5. 连按同一操作多次，只有一条 Toast 并重新计时。
6. Toast 出现后把指针停在它上面不动，到时照常消失。
7. Toast 出现后立即切到其它 App，10 秒后切回，Toast 已消失。
8. 点击被 Toast 覆盖的表格行，该行照常响应。
9. 满长度列表名触发的 Toast 换行显示完整文案，宽度不超过 400px。
10. 把窗口拖窄到 400px 以下，Toast 两侧各留 24px，不溢出。
11. 播放页依次触发暂停、音量、倍速、字幕开关、全屏、快进快退、上一条下一条、复制、Shiori，单行高度仍为 52px，位置仍在画面正中。
12. 播放页触发满长度列表名的 Shiori 结果，文案换行显示完整，不再截断，宽度不超过 520px。
13. 两个界面的图标尺寸都在 `Icon Registry.md` 的尺寸表内，Debug 构建下绘制不触发线宽断言。
14. 简体、繁体、英文各核对一遍，全部不溢出、不截断。
15. 现有自动化端到端与单元用例全部通过。