# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Toolbar Button、Background、Search / Shiori Toolbar Layout、Playback Topbar Layout）

# 需求描述

## 1. 范围

1. Workbench Search / Shiori 工具栏中搜索框右侧的 Select 按钮。
2. Playback Overlay 顶栏右侧的 Collage 按钮，含它在编辑长截图状态下的退出动作。
3. 第 3 节的背景规则适用于全部纯图标按钮，按钮范围沿用 `docs/human/requirements/20260905-UI-Icon Button Hover And Open Background.md` 第 1 节。

## 2. 改为纯图标按钮

1. 上述两个按钮由 Toolbar Button / Mode Toggle 改为 Icon Button / Default：透明底、无边框，按钮盒、圆角与图标尺寸沿用 Icon Button 现有 token，不新增 token。
2. 取消文字标签。图标沿用 `square.and.pencil`，开启态不换图标。
3. 开启态使用 Icon Button 的 Open 态：选择模式开启期间、长截图编辑期间背景与 Hover 相同，图标保持 `--color-text-secondary`。
4. Icon Button 的 Open 态含义随之扩展为：按钮挂靠的菜单或面板打开期间，或按钮所控模式开启期间。
5. Select 按钮在不能进入选择模式时使用 Icon Button 的 Disabled，Disabled 不出现 Hover。
6. 本需求不为这两个按钮增加悬浮提示。

## 3. Hover 与 Open 背景随所在表面

1. 纯图标按钮的 Hover 与 Open 背景取所在表面对应的 token：

| 所在表面 | 表面 Token | Hover / Open 背景 |
| --- | --- | --- |
| Workbench 页面与对话框 | `--color-bg-surface` | `--color-bg-hover` |
| Playback Overlay | `--color-subtitle-focus-overlay-bg` | `--color-playback-overlay-shortcut-button-bg-hover` |
| Command Panel | `--color-bg-popover` | `--color-command-panel-shortcut-button-bg-hover` |

2. 不新增颜色 token。
3. 图标颜色、图标尺寸、字重在 Hover 与 Open 时不变。

## 4. 组件与文档记录

1. 改后 Toolbar Button 及其 Action、Panel Trigger、Mode Toggle 三个变体在设计系统中无使用者，退役。代码中旧版控制条的清理不属于本需求。
2. 验收后在 `UI Design System.md` 中同步：Search / Shiori Toolbar Layout 的 Select Mode Action 组件改为 Icon Button；Playback Topbar Layout 的 Trailing Action Region 与 Exit Action 组件由 Button / Neutral 改为 Icon Button；Icon Button 的 Open 态与 Hover 背景按第 2、3 节改写。

## 5. 保持不变

1. 两个按钮的动作、快捷键与可用性判定不变。
2. 编辑长截图状态下顶栏的标题与其它内容不变。
3. 播放器 chrome 的图标按钮不在范围内，外观不变。
4. 按住不改变外观、菜单打开期间菜单之外不出现 Hover、尺寸过渡期间外观冻结等规则不变。
5. 指针为箭头不变。

# 验收

1. Workbench 搜索框右侧的 Select 按钮为无边框方形图标按钮，与左侧筛选按钮同尺寸、同圆角，在工具栏行内垂直居中对齐。
2. Playback Overlay 顶栏右侧的 Collage 按钮为同款纯图标按钮，进入长截图编辑后仍在原位并保持 Open 底色。
3. 进入选择模式后 Select 按钮保持 Open 底色，退出后恢复透明底。
4. 不能进入选择模式时 Select 按钮为 Disabled 图标色，悬停无底色。
5. Playback Overlay 上 Collage 按钮的 Hover 底色与底部 Save to Shiori 的 Hover 底色一致，且在 Overlay 表面上清晰可见。
6. Command Panel 二级页 Back 的 Hover 底色与该面板底部动作按钮的 Hover 底色一致。
7. Workbench 页面与对话框中的纯图标按钮 Hover 底色不变。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 本次改动不新增任何自动化端到端或单元用例的失败。