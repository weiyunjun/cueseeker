# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **分组顺序与 Border 动态显隐（`L-02.5 Settings Subtitle Layout`）**：
   - 分组自上而下顺序改为：`Text` → `Position` → `Border` → `Shadow`，页底为 `Restore Defaults` 按钮。
   - `Border` 的 `Type` 简化为 `Outline` 与 `Background Box` 二选一，按选中项动态显隐设置行，不再使用置灰：
     - `Outline`：显示 `Type`、`Outline Color`、`Outline Width`、`Blur`。
     - `Background Box`：显示 `Type`、`Background Color`、`Background Opacity`、`Blur`。
   - `Shadow` 分组在两种模式下均生效且常驻可用，依次为：`Shadow Color`、`Shadow Opacity`、`Shadow Offset`。

2. **可搜索字体下拉框（`Font`）**：
   - 移除 `Choose…` 按钮与系统字体面板，改为下拉选择框（显示当前字体家族名称与下拉图标，首项为 `System Font`，仅列系统字体家族）。
   - 点击展开下拉菜单：顶部为 `Search Field`，下方为可滚动的 `Radio Menu Item` 列表；搜索无匹配项时显示 `No Results`。
   - 打开菜单时焦点自动进入搜索框，且方向键导航期间焦点始终留在搜索框内；初始打开及搜索词变化时默认高亮第 1 个结果，按 `↑` / `↓` 移动高亮，按 `Return` 选中当前高亮项并关闭菜单，按 `Esc` 或点击菜单外部关闭菜单。

3. **颜色输入框与预设色块面板（`Color`、`Outline Color`、`Background Color`、`Shadow Color`）**：
   - 移除系统调色板，改为行内颜色输入框：左侧为纯色圆角色块（无边框），右侧为固定不可编辑的 `#` 前缀与十六进制文本输入。
   - 点击整个颜色框聚焦输入的同时，下方自动浮出常用预设色块面板供点选；点击外部或失焦时关闭面板。
   - 支持 3 位与 6 位十六进制色值（3 位色值原样显示，不做额外展开）：
     - 输入或粘贴时瞬间剔除 `#`、换行符、空格、`.` 等非十六进制字符并转为大写，最多保留前 6 位；选中已有色值后输入或粘贴纯非法字符直接拦截，不清空原色值。
     - 满 6 位时实时生效；失焦时若为 4~5 位则截取前 3 位生效，若为 3 位直接生效，若为 0~2 位则恢复为上一次有效色值。

4. **数字输入框规则、值域与默认值（`C-01.4 Number Field`）**：
   - 所有数字框不显示上下微调按钮，仅允许输入整数数字 `0-9`（`Background Opacity` 与 `Shadow Opacity` 带 `%` 单位）。
   - 输入或粘贴含英文句号 `.` 或换行符的内容（如 `12.5`、`12\n34`）时，在第一个 `.` 或换行处直接截断（变为 `12`），并剔除其余非数字字符；超出上限时在输入瞬间截断为最大值；选中已有数字后输入或粘贴纯非法字符直接拦截。
   - 数字框与色值框按回车键无交互动作；为空或小于最小值时，仅在失焦时恢复上一次有效值或修正为最小值。
   - 各设置项值域与默认值：
     - `Size`：`1 ~ 200`，默认 `28`
     - `Letter Spacing`：`0 ~ 100`，默认 `0`
     - `Line Spacing`：`0 ~ 100`，默认 `6`
     - `Margin X`：`0 ~ 500`，默认 `25`
     - `Margin Y`：`0 ~ 500`，默认 `22`
     - `Outline Width`：`0 ~ 50`，默认 `2`
     - `Background Opacity`：`0 ~ 100`（`%`），默认 `50`
     - `Blur`：`0 ~ 50`，默认 `0`
     - `Shadow Opacity`：`0 ~ 100`（`%`），默认 `50`
     - `Shadow Offset`：`0 ~ 50`，默认 `0`
     - `Color` 默认 `#FFFFFF`；`Outline Color`、`Background Color`、`Shadow Color` 默认 `#000000`

5. **1080p 基准与字号算法**：
   - SRT 字幕尺寸与边距的缩放基准高度由 `720` 改为 `1080`。
   - `Size` 直接作为 `1080p` 基准下的标准字体字号（`pointSize`），移除 `ascent + descent` 行高折算。

6. **设计文档同步**：
   - 严禁硬编码私有样式；待实际 UI 验收定稿后，将最终组件、Token 与布局变更同步更新至 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. `Settings - Subtitle` 分组顺序为 `Text`、`Position`、`Border`、`Shadow`；切换 `Outline` 与 `Background Box` 动态显隐对应设置行，`Shadow` 始终可用。
2. `Font` 下拉框展开后焦点在搜索框，默认高亮第 1 个结果，支持实时过滤、`No Results` 提示、`↑`/`↓` 导航、`Return` 选中与 `Esc` 关闭。
3. 颜色框左侧为无边框纯色块，右侧带固定 `#` 前缀，点击聚焦并浮出预设色块；支持带 `#` 粘贴、3 位与 6 位色值、4~5 位失焦截取前 3 位、0~2 位失焦恢复原值。
4. 数字框无上下按钮，粘贴 `12.5` 截断为 `12`，超出上限实时截断，空值或小于最小值在失焦时恢复/修正，按回车无动作。
5. SRT 字幕按 `1080p` 基准与直接字号算法渲染，修改设置实时生效，`Restore Defaults` 正确重置全部默认值。