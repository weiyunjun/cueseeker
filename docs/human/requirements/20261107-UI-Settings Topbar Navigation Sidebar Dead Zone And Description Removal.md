# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **Settings 窗口前进 / 后退导航与右侧固定顶栏布局（`L-02.1` / `L-02.3`）**：
   - **前进 / 后退历史记录（App 运行周期）**：
     - 采用与 Workbench 一致的浏览器式历史栈，生命周期为 App 本次运行期间。App 启动后首次打开 Settings 默认选中 `General`（处于历史起点，后退与前进均为 `Disabled`）。
     - 切换到另一个不同的设置分类时推入新历史节点，并截断当前位置之后的“可前进”记录；点击当前已选中的同一分类不新增历史记录。
     - 在 App 未退出的情况下关闭 Settings 窗口再重新打开，保留关闭前所在的分类与完整的前进/后退历史栈。
     - 通过左侧分类栏或后退/前进按钮切换分类时，收起当前页已展开的下拉菜单与颜色预设面板、取消输入框焦点，目标分类内容区回到顶部。
   - **右侧固定顶栏（Settings Topbar）结构与尺寸**：
     - 右侧区域拆分为顶部固定栏（高 `--height-settings-titlebar`：`36px`，背景 `--color-bg-surface`，不随下方内容滚动，空白区支持拖拽移动窗口与双击缩放）与下方可滚动的设置项内容区。
     - 顶栏内部垂直居中，左侧内边距为 `--spacing-6`（`24px`），右侧内边距为 `--padding-app-topbar-trailing`（`40px`），从左到右依次为：
       1. **后退按钮（Back Action）**：复用 `C-03.2 Icon Button / Dialog Close` 尺寸规格（宽高 `--size-dialog-close-button`：`24px`，圆角 `--radius-control`：`8px`，图标 `caret-left` 尺寸 `--size-dialog-close-icon`：`16px`）。
       2. **前进按钮（Forward Action）**：规格同后退按钮（图标 `caret-right`），与后退按钮间距 `--spacing-1`（`4px`）。
       3. **当前分类标题（Category Title）**：复用 `C-08.7 Section Title` 规格（字号 `--font-size-section-title`：`18px`，`Semibold`，颜色 `--color-text-primary`），与前进按钮间距 `--spacing-2`（`8px`），占据剩余宽度并在空间不足时尾部省略。
     - 后退与前进按钮的可用/禁用态 Tooltip 复用 `topbar.navigation.back` 与 `topbar.navigation.forward` 规范。
   - **下方分类内容区（`L-02.3`）**：
     - 移除原位于滚动区域顶部的页内标题（`Page Title`）及其与首个分组之间的 `--spacing-4` 间距。
     - 滚动内容区从顶栏（`36px`）下方开始，直接排列分组栈（`Group Stack`）；内容区顶部内边距设为 `--spacing-1`（`4px`），左、右、底部内边距保持不变。
   - **无障碍遍历顺序（`UI Accessibility Rules.md` §3.2）**：
     - Settings 窗口的无障碍循环顺序对齐 Workbench，依次为：**右侧顶栏（`Back` → `Forward`，含 `Disabled` 态） → 左侧分类导航栏（6 个分类项，从上到下） → 右侧当前分类内容区各设置控件**。

2. **消除 Workbench 与 Settings 左边栏导航标签的垂直死区（`L-01.1` / `L-02.2`）**：
   - 将 `L-01.1 App Sidebar Layout` 的 `Navigation Item Gap` 与 `L-02.2 Settings Sidebar Layout` 的 `Item Gap` 均由 `--spacing-1`（`4px`）调整为 `0px`。
   - 相邻 `C-05.3 Sidebar Item` 在垂直方向上无缝紧贴排列，从首项顶边到末项底边之间不存在任何点击落空的垂直死区。

3. **删除 Settings 各分类中的静态解释文字（`L-02.3`）**：
   - 移除 `L-02.3 Settings Category Layout` 中的分组副标题说明（`Group Description`）与设置行名称下方的说明文字（Row 说明）：
     - **`General` 页**：移除 `Appearance`、`Search`、`Language`、`Deep Link` 四个分组标题下方的说明，以及 `Appearance Mode`、`Prefill with Focused Cue`、`Play First Search Result` 三行名称下方的说明。
     - **`Play` 页**：移除 `Decode` 分组标题下方的说明，以及 `Decoder` 行名称下方的说明。
     - **`Maintenance` 页**：移除 `Maintenance` 分组标题下方的说明（卡片内的实时维护状态提示与底部数据库路径保留）。
     - **`Developer` 页**：移除 `Developer` 分组标题下方的说明，以及 `FTS Vocabulary Diagnostics` 行名称下方的说明（`FTS Vocabulary Data` 卡片内的状态文字保留）。

# 验收标准

1. **Settings 前进 / 后退与右侧顶栏布局**：
   - 右侧顶部固定为 `36px` 顶栏，左侧距分割线 `24px` 处依次排列 `24×24px` 后退按钮（`16px` 图标）、`4px` 间距、`24×24px` 前进按钮（`16px` 图标）、`8px` 间距与 `18px Semibold` 分类标题；下方设置卡片滚动时顶栏固定不动，顶栏空白处可拖动窗口与双击缩放。
   - 初次打开 Settings 时停留在 `General`，后退与前进均禁用；切换分类后可通过后退/前进在历史记录间往返，且关闭 Settings 窗口再重新打开时保留关闭前的分类与前进/后退历史栈。
   - 在 Settings 窗口按 `Tab` / `Shift + Tab`（或手柄 `R1` / `L1`）开启无障碍时，按「后退 → 前进 → 左侧 6 个分类项 → 右侧设置项」顺序循环遍历。
2. **左边栏无垂直死区**：
   - Workbench 与 Settings 左侧栏各导航标签之间垂直间距为 `0px`，在列表区域内沿垂直方向任意位置移动与点击均能连续命中对应标签，无未选中死区。
3. **静态解释文字清理**：
   - `General`、`Play`、`Maintenance`、`Developer` 页面中上述分组标题下方与设置项名称下方的静态解释文字全部移除；`Maintenance` 卡片内状态与数据库路径、`Developer` 词表诊断状态及 `Shortcuts` 冲突提示正常保留。