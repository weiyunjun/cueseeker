# 版本

main

# 关联设计

- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **Command Panel 默认（最大）宽度缩减为 `720px`（禁止硬编码与私自特殊实现）**：
   - 将 `--width-command-panel-max` 由 `1040px` 调整为 `720px`（新增 `0` 个 Token）；`--height-command-panel-max`（`720px`）、`--inset-command-panel-viewport`（`40px`）、窗口最小宽度与单张封面卡片最小宽度（`--width-library-recent-card-min: 220px`）均保持不变。
   - 在默认窗口宽度及更宽视口下，`Command Panel` 宽度为 `720px`（扣除左右各 `--spacing-5: 20px` 内容内边距后可用宽度 `680px`），二级封面网格默认恰好紧凑容纳一排 `3` 张封面卡片；视口继续收窄时维持既有留白与自适应列数收缩规则不变，`Command Panel` 右下角 `Toast` 锚定边距同步跟随新面板宽度。

2. **Command Panel 全部二级界面顶栏标题左对齐与截断悬停 Tooltip（`L-09.2`）**：
   - **统一左对齐排布**：`Command Panel` 全部二级界面（`Search Results`、`Recent Videos`、`Recent Excerpt Lists`）的顶部标题不再水平居中，统一紧贴左侧返回按钮右侧左对齐展示（与返回按钮间距 `--spacing-3: 12px`）。
   - **宽度边界、省略与选词复制**：标题向右延伸至右侧操作按钮区（`Search Results` 的 `Filter` / `Sort` 按钮组，间距 `--spacing-3: 12px`）或顶栏内容右内边缘；单行超出可用宽度时尾部 `...` 截断，保留既有文本划选能力，且选中截断标题复制时还原完整原文本。
   - **截断文本 Tooltip**：遵循全局截断文本补全 Tooltip 规范（同 `Workbench Page Title`），仅当二级界面顶栏标题因宽度限制实际发生尾部 `...` 省略时，指针悬停于标题文字热区满 `1s`（`--delay-tooltip-hover`）弹出 `C-08.6 Tooltip` 展示完整标题文本（最大宽度 `--width-tooltip-max`，超出自动折行，跟随当前 Light / Dark Mode）；标题完整显示未截断时不触发 Tooltip。

3. **Command Panel 一级界面底栏新增 `Close` + `Esc` 快捷动作按钮（`L-08.3`、`L-09.1`）**：
   - **显示范围与位置**：仅在 `Command Panel` 一级根界面（`Command Panel Root`）底栏右侧动作区新增关闭快捷动作按钮，排列在 `Open` `Return`（选中 `Copy Current Cue` 时为 `Copy` `Return`）左侧，按钮间距保持 `--spacing-2: 8px`；`Command Panel` 各二级界面底栏维持现状不变。
   - **文案与样式**：复用 `C-03.3 Shortcut Action Button / Popover Surface` 与固定键帽 `C-08.9 Keycap / Popover Surface`，文案使用既有标准关闭词条（英文：`Close`；简体中文：`关闭`；繁体中文：`關閉`），键帽固定显示 `Esc`。
   - **点击与无障碍交互**：鼠标点击该按钮或通过键盘/手柄无障碍激活时，执行与在一级界面按下 `Esc` 一致的关闭 `Command Panel` 动作（打开面板前暂停了播放且下层无 `Playback Overlay` 时照常恢复播放）；纳入 `Command Panel` 一级界面无障碍遍历序列，按底栏从左到右顺序位于 `Close` → `Open` / `Copy`。

4. **设计文档同步安排**：
   - 关联 UI 设计文档（`UI Tokens.md`、`UI Layouts - Playback.md`、`UI Accessibility Rules.md`、`Tooltip Usage Registry.md`）待本次改动完成视觉与交互验收后再统一最小化同步提交。

# 验收标准

1. **面板宽度与 3 列封面网格验收**：在默认窗口（`1000px` 宽）与全屏播放页下打开 `Command Panel`，面板宽度为 `720px`；进入 `Recent Videos` 与 `Recent Excerpt Lists` 二级页，默认一排紧凑展示 `3` 张封面卡片；将主窗口拉窄至最小宽度时面板与卡片列数正常收缩无裁切；在 `Command Panel` 内触发复制等操作时，右下角 `Toast` 严格对齐 `720px` 面板右内边缘。
2. **二级页顶栏左对齐、选词与截断 Tooltip 验收（Light & Dark）**：进入 `Search Results`、`Recent Videos` 与 `Recent Excerpt Lists` 二级页，顶部标题均紧贴返回按钮右侧左对齐；输入短搜索词时悬停标题满 `1s` 不弹出 Tooltip；输入超长搜索词（或拉窄窗口）使标题尾部出现 `...` 省略时，标题与右侧 `Filter` 按钮保持清晰间距，悬停在标题文字上满 `1s` 弹出对应明暗模式的完整文本 Tooltip（移出、按键或点击立即消失），拖选省略标题并复制可得到完整未截断搜索词。
3. **一级页底栏 `Close Esc` 按钮与无障碍验收（Light & Dark）**：打开 `Command Panel` 一级界面，右下角依次并排展示 `Close Esc` 与 `Open ↵`（选中 `Copy Current Cue` 时为 `Close Esc` 与 `Copy ↵`），简、繁、英三语文案切换准确，悬停与按下视觉同右侧按钮一致；点击 `Close Esc` 直接关闭 `Command Panel`（视频播放自动恢复符合既有规则）；按 `Tab` / `Shift + Tab` 或手柄肩键在一级界面遍历时，底栏依次选中 `Close` 与 `Open` / `Copy` 并可正常触发；进入任一二级界面后底栏不显示 `Close Esc`。