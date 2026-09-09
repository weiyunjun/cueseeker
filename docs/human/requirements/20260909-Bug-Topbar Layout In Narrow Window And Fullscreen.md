# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（App Topbar Layout、Player Topbar Layout、Playback Topbar Layout、Workbench Titled Page Layout、App Sidebar Layout、Player Title、Workbench Page Title）
- `docs/human/design/UI Application Rules.md`（全屏）

# 需求描述

## 1. Workbench 顶栏与页面同宽同滚动

1. 顶栏的后退、前进、标题与右侧的任务、设置是同一行，最小宽度与页面一致，为 `--min-width-workbench-page-content`。
2. 右区窄于该最小宽度时，这一行按最小宽度排版，与页面共用同一个横向滚动偏移，右侧按钮随之移出与移回可视区。
3. 红绿灯与 Sidebar Toggle 属于窗口带与侧栏段，不参与这一行的排版与滚动。
4. 该情形只在侧栏展开且窗口宽度小于自动收起阈值时出现。

## 2. 顶栏标题自适应

1. Workbench、Playback、Playback Overlay、Collage 四个顶栏的标题按可用宽度自适应，任何窗口宽度下都不与左右两侧的元素重叠。
2. 居中的标题与 Tabs 保持在顶栏中线上，可用宽度为顶栏宽度减去左右两侧占用中较大一侧的两倍，再减去与两侧的间距。Player Title 另受 `--width-player-topbar-title-max` 上限约束。
3. Workbench 标题不居中，可用宽度为这一行内后退、前进与任务、设置之外的剩余空间，尾部截断。
4. Player Title 改为中间截断：标题形如 `名称 - 序号`，截断只吃名称部分，尾部的 ` - 序号` 不省略。标题没有序号时同样使用中间截断。

## 3. 播放页与 Playback Overlay 的全屏顶栏

1. 全屏时视频页顶栏照常显示，跟随 Player UI 显隐与交互抑制，与非全屏一致。
2. 全屏时红绿灯由系统标题栏显示，两个顶栏的返回按钮不再预留红绿灯的位置，改为贴 `--padding-player-topbar-x` 居左；标题居中，任务与设置居右。
3. 非全屏时返回按钮的位置不变。

## 4. 播放页不影响侧栏自动收起

1. 侧栏自动收起只在 Workbench 可见时判定。
2. 播放页期间的窗口宽度变化不改变侧栏的展开或收起状态。
3. 退出播放页回到 Workbench 时，按当时的窗口宽度重新判定一次。

## 5. 保持不变

1. 不新增 Token。
2. 侧栏宽度、自动收起阈值、页面最小宽度与页面横向滚动条位置不变。
3. 顶栏高度、元素顺序、间距与非全屏时的红绿灯位置不变。

# 验收

1. 窗口 480、侧栏展开：Workbench 标题不被任务与设置按钮遮挡；横向滚动页面时顶栏这一行与页面一起平移，右侧按钮可以滚入可视区。
2. 收起侧栏后横向滚动消失，顶栏右侧按钮回到贴右边界。
3. 播放页窗口 480：标题不遮挡红绿灯与右侧按钮，尾部 ` - 序号` 完整可见；加宽窗口后标题逐步还原。
4. Playback Overlay 与 Collage 在窗口 480 下，Tabs 与编辑标题不与两侧元素重叠。
5. 播放页进入全屏：顶栏显示，返回按钮贴左边距，标题居中，任务与设置可点；鼠标静止 Player UI 隐藏时顶栏一并隐藏，移动后一并恢复。
6. Playback Overlay 与 Collage 全屏：返回按钮同样贴左边距。
7. 侧栏展开、窗口 900 时进入播放页，缩到 600 再放大回 900，退出播放页：侧栏仍为展开。
8. 同一路径缩到 600 后直接退出播放页：侧栏按规则收起。
9. 第 1 至 4、7、8 条用现有 Debug E2E 控制器覆盖；第 5、6 条需要进出全屏，控制器没有对应命令，走人工验收，不为本需求新增 E2E 能力。

# UI 文档同步

验收完成后，由人类维护者更新并提交 `docs/human/design/UI Design System.md`：

1. App Topbar Layout 补 Function Region 与 Trailing Function Region 的最小宽度与横向滚动规则。
2. Player Topbar Layout 与 Playback Topbar Layout 补全屏状态：顶栏照常显示，返回按钮改用 `--padding-player-topbar-x`。
3. Player Title 的 Truncated 改为中间截断并写明序列号不省略，Maximum Width 改为上限且不超过可用宽度。
4. App Sidebar Layout 的 Auto Collapse 补「只在 Workbench 可见时判定，退出播放页时重新判定一次」。