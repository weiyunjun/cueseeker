# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **窄窗口下浮层侧边栏不再随鼠标移出自动收起（`L-01.1 App Sidebar Layout`）**：
   - 保留窗口宽度小于 `--min-width-workbench-page-content` + `--width-app-sidebar` 时自动收起侧边栏的规则（仅在工作台可见或从播放页返回时判定）。
   - 当在窄窗口下展开浮层侧边栏（`Overlay`）后，移除「鼠标指针向右移出侧边栏宽度范围自动收起」的行为；展开后的浮层侧边栏仅在点击顶栏 `Sidebar Toggle` 按钮（或窗口再次跨阈值缩窄触发自动收起）时收起。

2. **播放页移除手柄操作自动隐藏 Player UI 与指针的遗留规则（`UI Interaction Rules.md` §10）**：
   - 在播放页（含全屏）使用手柄操作（方向输入或功能按键）时，不再主动隐藏 `Player UI` 与鼠标指针，也不打断或重置鼠标静止 3 秒自动隐藏的倒计时，与键盘按键行为保持一致。

3. **Command Panel 输入法候选区存在时按 `Esc` 优先关闭候选区（`L-09.1 Command Panel Root Layout`）**：
   - 当 `Command Panel` 一级界面搜索框处于聚焦状态且存在输入法未上屏候选文本（IME 组合态）时，按下 `Esc` 优先交由系统输入法关闭候选区并清除未上屏内容，`Command Panel` 保持打开且搜索框维持聚焦。
   - 当搜索框已无输入法候选状态时，按下 `Esc` 才关闭 `Command Panel`。

4. **移除业务对话框按下回车键直接触发右下角主按钮的交互（`L-06.1`、`L-06.2`、`L-06.3`、`L-06.5`、`L-06.6`）**：
   - 移除以下 5 个业务对话框右下角主功能按钮的回车键快捷触发：
     - `Edit Cover`（`Save`）
     - `Excerpt List Editor`（`Create` / `Save`）
     - `Rename Folder` / `Rename Files`（`Rename`）
     - `Export to Anki`（`Export`）
     - `Filter`（`Show xx results / excerpts`）
   - 在上述对话框打开期间（无论输入框是否聚焦），按下回车键均不触发右下角主按钮动作；`Confirmation` 二次确认对话框保持现状不变。

5. **设置页原生控件替换为应用内统一组件（`L-02.3 Settings Category Layout`、`C-04.1 Menu`、`C-10.2 Confirmation Dialog`、`L-06.7 Confirmation Dialog Layout`）**：
   - **`General → Language` 下拉菜单**：
     - 将系统原生下拉菜单替换为与 `Subtitle → Font` 一致的应用内下拉触发器与 `C-04.1 Menu / Dropdown Menu`。
     - 触发器宽度为 `--width-settings-popup`，具备 `Default`、`Hover`、`Pressed`、`Open` 状态；点击展开等宽下拉菜单，内部为 `Radio Menu Item`（展示全部支持的语言选项并勾选当前生效语言），遵守全局菜单模态、方向键/手柄导航、回车确认及 `Esc`/外部点击关闭规则。
   - **`Maintenance → Compact Database` 二次确认对话框**：
     - 将系统原生警告框替换为应用内统一的 `C-10.2 Confirmation Dialog`（`L-06.7 Confirmation Dialog Layout`），在设置窗口内居中展示并铺设对话框遮罩（保留设置窗口顶部红绿灯与标题栏拖拽区）。
     - 底部按钮依次为 `Cancel`（`Button / Neutral`，默认聚焦）与 `Compact Database`（`Button / Destructive`）；弹窗位于最上层期间，设置窗口左上角红灯关闭按钮不可用，且 `Cmd+Q` 与 Dock 菜单退出同样不生效。

# 验收标准

1. 将主窗口拉窄至侧边栏自动收起后，点击左上角 `Sidebar Toggle` 展开浮层侧边栏，将鼠标移出侧边栏区域到右侧页面上，侧边栏保持展开不自动收起；再次点击 `Sidebar Toggle` 可正常收起。
2. 在播放页（窗口或全屏）显示顶底栏与鼠标指针期间，使用手柄进行任意操作，播放器 UI 与鼠标指针不会立即消失，且静止满 3 秒后仍能正常按倒计时隐藏。
3. 打开 `Command Panel`，在搜索框使用中文/日文等输入法输入拼音出现候选词浮层时，按第一次 `Esc` 仅关闭输入法候选区并清除未上屏拼音，`Command Panel` 保持打开；再按一次 `Esc` 才关闭 `Command Panel`。
4. 分别打开 `Edit Cover`、`Excerpt List Editor`、`Rename`、`Export to Anki`、`Filter` 五个弹窗（含取消输入框焦点后），按下回车键均不会触发右下角的确认/保存/导出/筛选按钮。
5. 在设置窗口 `General → Language` 中，语言选择框呈现为与应用内 `Subtitle → Font` 一致的自定义下拉触发器与弹出菜单，支持鼠标、键盘方向键/回车/Esc 与手柄操作，切换语言后全界面即时生效；在 `Maintenance` 中点击 `Compact Database` 时，在设置窗口内居中弹出应用内统一的 `Confirmation Dialog`，打开期间设置窗口红灯不可点且 `Cmd+Q` 不退出，点击 `Cancel` 或按 `Esc` 关闭弹窗，点击 `Compact Database` 正常执行数据库压缩。