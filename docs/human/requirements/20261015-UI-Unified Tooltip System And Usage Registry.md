# 版本

main

# 关联设计

- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Interaction Rules.md`

# 需求描述

1. **Tooltip 视觉样式与 Tokens（黑底白字统一容器）**：
   - **容器外观**：背景复用 `--color-toast-bg`（Light `rgba(31,31,31,0.90)`，Dark `rgba(45,45,50,0.92)`，叠加毛玻璃），边框复用 `--color-toast-border`（`1px`，`rgba(255,255,255,0.15)`），阴影复用 `--shadow-popover`，不带三角箭头。
   - **Tooltip 排版**：圆角 `--radius-field`（`6px`），内边距水平 `--spacing-2`（`8px`）、垂直 `--spacing-1`（`4px`）；主文本字号 `--font-size-control`（`14px`）、字重 `--font-weight-control`（`500`）、颜色 `--color-player-text-primary`（`rgba(255,255,255,0.94)`）；超长截断补全文本最大宽度 `280px`，超出自动折行。
   - **同行快捷键样式**：位于功能名称右侧（间距 `6px`），采用纯文本样式，字号 `--font-size-control`（`14px`）、字重 `--font-weight-control`（`500`）、颜色 `--color-player-text-secondary`（`rgba(255,255,255,0.62)`）。
   - **台词状态提示（原 Cue State Tip）**：移除独立的标题与多行卡片结构（场景 24 内容已变更、场景 25 台词不可用），统一简化为普通标准单行 Tooltip（仅展示状态原因文案，末尾不加句号）。

2. **定位优先级、触发与消失规则**：
   - **定位与防裁切（Offset / Flip / Shift）**：以目标控件边界框为锚点，默认出现在控件正上方居中（`top`，锚点间距 `--spacing-2: 8px`）；当顶部距窗口边界不足以容纳 Tooltip 时，自动翻转至控件正下方居中（`bottom`，锚点间距 `--spacing-2: 8px`）；当水平居中导致左/右超出窗口安全边界时，沿水平方向平移（Shift），确保 Tooltip 距窗口四周始终不少于 `--spacing-2`（`8px`）。
   - **触发延迟**：指针移入热区并保持满 `1s` 后显示（具体场景遵循 `Tooltip Usage Registry.md`）。
   - **消失与互斥**：指针移出热区、鼠标按下或点击、滚动、键盘按键、打开菜单或对话框时立即隐藏；全局同一时刻最多显示 1 个 Tooltip。

3. **全场景接入与文案/交互修正**：
   - 严格按照 `docs/human/design/ui/Tooltip Usage Registry.md` 收录的 36 个场景接入英、简、繁三语 Tooltip：
     - 可配置快捷键的按钮动态读取 `Settings / Shortcuts` 当前生效键位（改键后同步变化，清空或冲突时不显示快捷键）；
     - 控件处于 `Disabled` 态时切换为展示对应的禁用原因文案（不显示快捷键）；
     - 截断文本（Workbench 顶栏标题、Player 顶栏标题、Filter Dialog 筛选项胶囊）仅在实际发生省略（`...`）时触发 Tooltip；
     - 所有 `More` 菜单触发按钮及菜单项（含禁用态）均不显示 Tooltip。
   - **存量文案与交互修正**：
     - 顶栏 `Back` 简/繁文案修正为 `后退 / 後退`。
     - 播放页顶栏返回工作台按钮（`player.topbar.return`）不显示 `Esc` 快捷键。
     - 播放控制栏原 `Repeat` 更名为 `Replay Current Cue / 重播当前台词 / 重播目前台詞`（同步更新 `Settings / Shortcuts` 对应动作名称），并移除触发该操作时的播放页 HUD/Toast 反馈。
     - 移除 `Dialog Close` 按钮多余的保存中禁用状态。

4. **设计文档同步**：
   - 待全部改动验收通过后，再将上述 Tooltip 样式、定位与交互规范同步更新至 `UI Tokens.md`、`UI Components - Domain.md` 与 `UI Interaction Rules.md`。

# 验收标准

1. Light 与 Dark 模式下，Workbench、对话框及播放页的所有 Tooltip（含表格台词状态提示）均呈现统一的黑底白字微透浮层样式（`--color-toast-bg` + `1px` `--color-toast-border`，主文本与快捷键字号均为 `--font-size-control: 14px`）。
2. 默认悬停满 `1s` 显示 Tooltip；普通区域默认在控件上方 `8px` 居中，顶栏等顶部空间不足处自动翻转至下方 `8px`，靠近窗口左右边缘时自动内移并保持至少 `8px` 窗口安全边距，无裁切溢出。
3. 点击、滚动、按键、移出或打开菜单/弹窗时 Tooltip 立即消失，不遮挡下拉菜单且菜单项无 Tooltip。
4. `Tooltip Usage Registry.md` 中的 36 个场景在英、简、繁三语下文案准确；修改或清空快捷键后按钮 Tooltip 实时同步；禁用态控件准确显示禁用原因；未截断的标题与 Filter Chip 不弹出冗余 Tooltip。
5. `Replay Current Cue / 重播当前台词` 文案在 Tooltip 与快捷键设置页一致，且触发重播当前台词时不再弹出 HUD/Toast。