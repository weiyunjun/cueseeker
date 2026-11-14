# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/workbench/Settings and Localization.md`

# 需求描述

1. **空搜索词时搜索筛选对话框右下角主按钮文案（`L-06.6 Filter Dialog Layout`）**：
   - 在搜索场景（Workbench Search 与 Command Panel 二级搜索结果页共用的筛选对话框）下，当搜索词为空（未输入字符或仅包含空白字符）时，筛选对话框右下角主按钮保持可点击状态（不显示 `Spinner`），文案不再显示结果数，改为按当前对话框内已勾选的筛选条件总数（五个分组已勾选胶囊数量之和，与工具栏筛选按钮右侧计数徽章口径一致；数字展示为不带千分位逗号的连续阿拉伯数字）实时显示：
     - **0 项**：
       - 英文：`Apply 0 filters`
       - 简体中文：`应用 0 个筛选条件`
       - 繁体中文：`套用 0 個篩選條件`
     - **1 项**：
       - 英文：`Apply 1 filter`
       - 简体中文：`应用 1 个筛选条件`
       - 繁体中文：`套用 1 個篩選條件`
     - **N 项（N ≥ 2）**：
       - 英文：`Apply N filters`
       - 简体中文：`应用 N 个筛选条件`
       - 繁体中文：`套用 N 個篩選條件`
   - 当搜索词非空时，搜索筛选对话框右下角主按钮保持现有行为与文案不变（总数未知时显示 `Spinner` 与 `Calculating` 且为 `Disabled`；总数已知后显示 `Show 1 result` / `Show N results`）。

2. **其余界面与交互边界保持不变**：
   - Workbench Excerpt 二级详情页的筛选对话框保持现状不变：无论搜索词是否为空，总数未知时显示 `Spinner` 与 `Calculating`，总数已知后显示 `Show 1 excerpt` / `Show N excerpts`。
   - Command Panel 一级与二级界面的入口及布局结构保持不变。
   - 对话框内各筛选项胶囊、左下角 `Reset`、`Cancel`、对话框打开期间切换应用语言的即时文案刷新、无障碍焦点激活，以及点击右下角主按钮确认生效（勾选有变化时应用并持久化、无变化时直接关闭）的行为均保持不变。

3. **设计文档同步安排**：
   - 本次新增与修改的设计 Token 均为 0 个；关联 UI 设计文档待本次改动验收完成后再统一提交更新。

# 验收标准

1. **空搜索词三语文案与实时联动验收**：在 Workbench Search 搜索框为空（或仅含空白字符）时打开筛选对话框，初始无勾选显示 `Apply 0 filters` / `应用 0 个筛选条件` / `套用 0 個篩選條件`；勾选 1 项实时变为 `Apply 1 filter` / `应用 1 个筛选条件` / `套用 1 個篩選條件`；勾选多项实时变为 `Apply N filters` / `应用 N 个筛选条件` / `套用 N 個篩選條件`（无千分位逗号）；点击 `Reset` 清空勾选后实时回到 0 项文案；对话框打开期间切换英 / 简 / 繁语言，按钮文案即时刷新。
2. **生效与非空搜索词回归验收**：空搜索词下点击右下角主按钮可正常应用或清空筛选条件并关闭对话框，工具栏筛选按钮右侧计数徽章同步更新；输入非空搜索词后在 Workbench Search 或 Command Panel 二级搜索结果页打开筛选对话框，主按钮仍按原有规则显示 `Calculating` 与 `Show 1 result` / `Show N results`。
3. **Excerpt 详情页零影响验收**：在 Workbench Excerpt 二级详情页中，无论搜索框为空还是非空，打开筛选对话框时右下角主按钮均保持显示 `Calculating` 与 `Show 1 excerpt` / `Show N excerpts`，不受本次改动影响。