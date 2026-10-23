# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **字体下拉触发器（`Settings - Subtitle - Font`）**：
   - 宽度为 `--width-settings-popup`，左侧单行展示当前选中的字体家族名称（默认显示 `System Font`），右侧显示下拉指示图标 `caret-down`。
   - 状态外观严格遵循按钮规范（`Default`、`Hover`、`Pressed`、`Open`）：菜单打开期间触发器处于 `Open` 态（外观同 `Hover`），不使用输入框聚焦蓝框；菜单关闭后立即退出 `Open` 态。

2. **字体下拉菜单结构与视觉规范（`C-04.1 Menu`、`C-04.3 Radio Menu Item`、`C-04.4 Menu Divider`、`C-07.1 Scrollbar`）**：
   - 移除菜单内的搜索输入框、`No Results` 空状态及私有菜单尺寸（移除 `--width-settings-font-menu` 与 `--max-height-settings-font-menu`），完全遵循标准 `Dropdown Menu` 容器、内边距、最大高度（`--max-height-menu`）及右侧垂直滚动条（`Scrollbar / Vertical`）规则。
   - 菜单项采用标准 `Radio Menu Item`，统一使用界面默认字体（`--font-family-base`）展示纯文本名称，左侧恒定预留勾选图标槽位，当前选中项显示 `check` 图标：
     - 首项为 `System Font`；
     - 下方为 1 条 `Menu Divider` 分隔线；
     - 分隔线下方按字母升序排列系统可用字体家族。

3. **菜单模态、交互与流畅度要求（`UI Interaction Rules.md` §3 & §4）**：
   - 菜单遵循全局菜单模态：弹出方向与高度在打开瞬间确定；打开时清除窗口内已有焦点，整窗口禁止底层页面滚动（滚轮仅在指针位于菜单上时滚动菜单本身），下层区域冻结 `Hover` 与点击；左键点击菜单外仅关闭菜单且不穿透，按 `Esc` 关闭菜单。
   - 打开时无默认高亮项；鼠标 `Hover` 与键盘/手柄方向导航合并为同一 `Hover` 高亮状态，遵循滚轮 `300ms` 防抖、键盘导航抑制鼠标 `Hover` 及高亮项无动画最小滚入可视区域规则。
   - 系统安装数百个字体时，进入 `Subtitle` 设置页、展开字体菜单、滚动列表及键鼠移动高亮均须保持即时响应、流畅无卡顿。

4. **设计文档一致性约束**：
   - 严禁硬编码或私自特殊实现，所有视觉与交互均须可体现在 UI 设计文档体系中；待实际 UI 验收定稿后同步更新 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. `Settings - Subtitle - Font` 点击触发器展开标准单选下拉菜单（无搜索框），触发器在菜单打开期间呈 `Open` 态（无聚焦蓝框），关闭后立即恢复。
2. 菜单首项为 `System Font`，下方隔 1 条 `Menu Divider` 后按字母升序展示系统字体家族，当前选中项左侧显示 `✓`，右侧滚动条符合 `C-04.1` 与 `C-07.1` 规范。
3. 菜单打开期间底层设置页禁止滚动、外部区域冻结 `Hover`，初始无默认高亮，鼠标悬停、滚轮防抖、键盘 `↑`/`↓`/`Return`/`Esc` 导航与外部点击关闭均符合全局菜单规则。
4. 电脑存在数百个字体时，切换至 `Subtitle` 设置页及展开、滚动、选择字体菜单全程流畅无卡顿，选中后字幕字体实时生效。