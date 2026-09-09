# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Text、Icon、Background）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中、按下）
- 视觉规格画布：https://claude.ai/code/artifact/1121f8c7-89ab-4c49-92de-02ee30631aa8

# 需求描述

## 1. 范围

纯图标按钮的 Open 态，共八个按钮：

1. Workbench 顶栏任务、顶栏设置。
2. Workbench 工具栏筛选、Select。
3. 播放页顶栏任务、顶栏设置。
4. Playback Overlay 顶栏任务、顶栏设置、Collage。

不在范围内：播放器底部控制条的全部控件，含字幕按钮与倍速按钮；纯图标按钮的 Hover、Default、Focused、Disabled；全部尺寸与圆角。

## 2. Open 态

1. Open 态不再与 Hover 相同，改为实心反色块：整个按钮盒填充一块不透明的灰，图标为纯白。
2. 背景使用现有 token `--color-text-muted`，Light `#717171`、Dark `#878787`。三个表面共用同一个值，不随所在表面变化。
3. 图标使用现有 token `--color-icon-on-dark` `#FFFFFF`。
4. 背景不透明，不使用任何透明度；图标线条之间露出的即是该背景本身，不出现第三个颜色或叠加层次。
5. 不新增任何颜色、尺寸、圆角或动效 token。

## 3. 保持不变

1. 全部纯图标按钮的 Hover 底色不变，各表面维持现状。
2. 按钮盒尺寸、圆角、图标尺寸与字重不变。
3. Focused 焦点环与 Disabled 外观不变；Disabled 不出现 Hover 与 Open。
4. 播放器底部控制条的形状、常驻背景、上一个与下一个的一体化容器、字幕按钮的开启外观、倍速按钮均不改动。
5. 八个按钮的动作、快捷键与可用性判定不变。
6. 按住不改变外观、菜单打开期间菜单之外不出现 Hover、尺寸过渡期间外观冻结等规则不变。
7. 指针为箭头不变。

# 验收

1. 筛选菜单打开期间，筛选按钮为实心灰底加纯白图标；与旁边静止的 Select 按钮一眼可分辨。
2. 任务面板打开期间任务按钮、设置窗口打开期间设置按钮、选择模式开启期间 Select 按钮、长截图编辑期间 Collage 按钮，均为同一外观。
3. Open 底为不透明实色，图标线条之间露出的是同一块灰，看不到半透明或叠加层次。
4. 播放页顶栏与 Playback Overlay 顶栏的任务、设置，Open 外观与 Workbench 的一致。
5. 同一按钮的 Hover 外观与改动前完全一致。
6. 播放器底部控制条与改动前完全一致，含字幕按钮的开启外观。
7. Light 与 Dark 两个主题分别核对以上各项。
8. 本次改动不新增任何自动化端到端或单元用例的失败。