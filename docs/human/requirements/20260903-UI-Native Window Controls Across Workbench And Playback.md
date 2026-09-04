# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（App Topbar Layout、Player Topbar Layout、Playback Topbar Layout、Player Window Control Button、Player Circle Button）
- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽）

# 关联需求

- `docs/human/requirements/20260630-Feature-Player Chrome Tokens.md`（Player Window Control Button 令牌来源，本需求废弃）

# 需求描述

## 1. 目标

Workbench 与播放页统一使用系统原生红绿灯，由 App 内唯一的所有者决定其位置与显隐。移除播放页的自绘红绿灯。

## 2. 通用规则

1. 红绿灯属于窗口，不参与界面层级与菜单模态。任何界面状态下三个按钮可见、可用，包括 Overlay、Command Panel、对话框打开时。
2. 红灯关闭主窗口。黄灯、绿灯为系统原生行为：点击、Option 点击、悬停与长按出现的系统分屏菜单，均不拦截。
3. 指针移到任一红绿灯上，三个按钮显示符号；指针位于窗口左上角原生位置时不显示。
4. 对话框打开与关闭过程中，红绿灯不得出现在原生位置。
5. 全屏沿用系统标题栏。全屏进入与退出的动画期间不显示红绿灯；进入完成后由系统标题栏显示，退出完成后回到页面落位。
6. 三个按钮之间的间距为系统原生间距，不设令牌。所有位置数值必须有令牌，禁止硬编码。
7. 窗口已处于系统全屏时（含长按绿灯选择的分屏全屏），绿灯点击交给系统：CueSeeker 自己退出全屏并恢复全屏前状态，不影响其它 App 的全屏，不出现进入全屏的反馈。播放页只在窗口未全屏时把绿灯点击接入自身全屏命令。

## 3. Workbench

1. 位置不变：起点 `--spacing-6`，在 `--height-app-topbar` 内垂直居中。
2. 新增令牌 `--gap-app-topbar-toggle-after-window-controls`：侧栏收起时，侧栏开关到红绿灯区右缘的间距。取值：待填（现为 18px 硬编码）。
3. 红绿灯区宽度由三个按钮的实际边界决定，不设令牌。

## 4. 播放页

1. 位置与 Workbench 相同：起点 `--spacing-6`，在 `--height-app-topbar` 内垂直居中；返回按钮与红绿灯同一水平中线。
2. 显隐：无 Overlay 时跟随 Player UI，使用同一过渡；Overlay 打开时常显；Command Panel 打开时常显。
3. 移除自绘 Player Window Control Button 及其 SwiftUI 实现。播放页不再拦截窗口关闭；关闭前保存播放记录沿用现有路径。
4. 新增返回按钮，语义为现有红灯的「关闭视频，返回来源页」，文案沿用现有。组件为 Player Circle Button / Standard，图标 `chevron.left`，位于绿灯右侧。新增令牌 `--gap-player-window-controls-return`：绿灯到返回按钮的间距。取值：待填。
5. 返回按钮显隐与红绿灯一致，Command Panel 打开时不要求。

## 5. Playback Overlay 顶栏

1. 结构改为：红绿灯区与返回按钮、Tabs 居中、Collage 按钮靠右。
2. 红绿灯与返回按钮的位置以播放页顶栏为准，Overlay 打开前后不移动。
3. Collage 按钮的组件、文案与动作不变，仅位置移到右侧，右边距与现在的左边距相同。

## 6. 实现约束

1. 位置与显隐只有一个决定者；页面只报告自身状态，不各自摆放按钮。
2. 悬停符号通过窗口子类覆写系统私有方法配合自有跟踪区域实现，允许使用该私有 API。
3. 不新增状态源、缓存或第二条按钮实现。

## 7. 执行步骤

1. 测量：对话框打开时系统收回按钮的时机；原生绿灯进入全屏是否经过播放页的串行化尺寸过渡门。报告后再实现。
2. Workbench：悬停修正、对话框跳位修正、令牌化。
3. 播放页：所有者接管红绿灯、移除自绘实现、红灯语义、返回按钮、Overlay 顶栏改版。
4. 更新实施记录。

## 8. 设计文档

验收通过后更新：App Topbar Layout 增加 Window Controls 区与新令牌；Player Topbar Layout 改为原生 Window Controls 与返回按钮；Playback Topbar Layout 结构改为第 5 节；废弃 Player Window Control Button 及 `--color-player-window-*`、`--size-player-window-control-*`、`--gap-player-window-controls`；Application Rules 界面层级补充红绿灯不参与层级。

# 验收

1. Workbench：指针移到红绿灯上三个按钮显示符号，移到左上角原生位置不显示。
2. 四个对话框各打开、关闭一次，红绿灯无位置跳动。
3. 播放页红绿灯为系统原生样式；显隐跟随 Player UI；Overlay 与 Command Panel 打开时可见可用。
4. 绿灯点击进入全屏，悬停或长按出现系统分屏菜单；黄灯最小化。
5. 红灯关闭主窗口，播放记录已保存。
6. 返回按钮在播放页与 Overlay 中均回到来源页。
7. Overlay 顶栏 Collage 按钮位于右侧，Tabs 居中。
8. 全屏行为与本需求前一致。
9. 现有自动化端到端与单元用例全部通过。第 1、2、4 项由需求方人工验收。
10. 播放页长按绿灯选择 Left of Screen 或 Right of Screen 进入分屏全屏，再点击绿灯：CueSeeker 退出全屏并恢复此前窗口，另一 App 保持全屏，不出现 Enter Fullscreen 提示。
11. 全屏进入与退出的动画期间红绿灯不可见；退出动画结束后出现在页面落位。
12. Workbench 与播放页各截一张图，红绿灯的位置逐像素一致。