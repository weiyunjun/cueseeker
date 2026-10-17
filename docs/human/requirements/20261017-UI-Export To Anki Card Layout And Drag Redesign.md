# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **Tokens 变更（`UI Tokens.md`）**：
   - 新增 `--font-size-anki-export-side-title`: `16px`（`Front` / `Back` 栏标题字号，字重 Semibold `600`）。
   - 新增 `--opacity-anki-export-dragging`: `0.5`（卡片内一维拖拽时数据对象本体的半透明不透明度）。
   - 修改 `--min-height-anki-export-card-box: 208px` 为 `--height-anki-export-card-box: 288px`（固定容纳 7 个数据对象的高度）。
   - 删除 `--height-anki-export-available-pool`（`96px`）、`--height-anki-export-drop-slot`（`6px`）、`--height-anki-export-drop-line`（`2px`）。

2. **布局重构（`L-06.5 Export to Anki Dialog Layout`）**：
   - 移除 `Available Items` 模块、`Card Layout` 标题以及两列外层的灰色背景容器（`--color-settings-group-bg`）。
   - 直接并列展示 `Front` 与 `Back` 两列，每列由顶部标题行与下方白色卡片容器（固定高度 `--height-anki-export-card-box: 288px`，内边距 `--spacing-2: 8px`）组成。
   - 标题行左侧为 `Front` / `Back` 标题（`--font-size-anki-export-side-title: 16px`，Semibold `600`），右侧为带边框底色的 `+` 按钮（尺寸 `32×32px`，样式复用 `C-03.1 Button / Neutral`，内部居中 `plus` 图标）。

3. **数据对象添加与删除**：
   - 同一面（`Front` 或 `Back`）内不能添加重复的数据对象；不同面之间允许各自添加同一个数据对象。
   - 当该面剩余未添加的数据对象 $\ge 2$ 个时：点击 `+` 按钮固定向下弹出菜单（`C-04.1 Dropdown Menu`），按标准顺序展示该面尚未添加的数据对象；点击菜单项将其追加到该面末尾。
   - 当该面仅剩 $1$ 个未添加的数据对象（已添加 6 个）时：点击 `+` 按钮不弹出菜单，直接将剩余的最后 1 个数据对象追加到该面末尾。
   - 当该面已添加全部 7 个数据对象时：`+` 按钮变为 `Disabled` 状态。
   - 点击数据对象右侧的 `✕` 按钮将其从当前面移除。

4. **卡片内一维拖拽排序**：
   - 数据对象样式保持不变（高度 `--height-filter-chip: 32px`，左侧 `dots-six-vertical` 拖拽手柄，右侧 `✕` 删除按钮，间距 `--spacing-2: 8px`）。
   - 数据对象仅在所属白色卡片内部沿垂直方向（一维）上下拖拽移动，不支持跨卡片拖拽。
   - 拖拽过程中不出现重复残影，被拖拽的数据对象本体变为半透明（`--opacity-anki-export-dragging: 0.5`）跟随移动；当越过相邻数据对象时实时平滑换位，松开鼠标即落定。

5. **空卡片校验与 Tooltip**：
   - 正常状态下白色卡片为空时不显示占位提示文本；点击 `Export` 时若 `Front` 或 `Back` 为空，拦截导出，对应白色卡片边框变红（`--color-danger-text`）并在卡片内部居中显示红色错误提示，添加任意数据对象后错误状态自动清除。
   - `+` 按钮支持 Tooltip（Scenario ID：`anki_export.card.add_item`，触发延迟 `1s`）：
     - 可用态：`Add Item` / `添加项目` / `加入項目`
     - Disabled 态：`All items added` / `已添加全部项目` / `已加入全部項目`

# 验收标准

1. `Export to Anki` 对话框不再展示 `Available Items`、`Card Layout` 标题及外层灰底，仅展示 `Front`、`Back` 标题行（左侧 `16px` Semibold 标题，右侧 `32×32px` 带边框底色 `+` 按钮）与固定 `288px` 高度的白色卡片。
2. `Front` 与 `Back` 可独立添加相同的数据对象，同一面内不重复：
   - 剩余可选 $\ge 2$ 项时，点击 `+` 固定向下弹出菜单，选择后追加至末尾；
   - 剩余可选仅 $1$ 项时，点击 `+` 直接添加该项，随后 `+` 按钮变为 `Disabled`；
   - 点击数据对象右侧 `✕` 可删除该项，删除后 `+` 按钮恢复可用。
3. `+` 按钮在可用态与 `Disabled` 态下悬停满 `1s` 均正确展示对应三语 Tooltip。
4. 在 `Front` 或 `Back` 卡片内上下拖拽数据对象时，仅做一维垂直移动，被拖拽项呈 `0.5` 半透明且无重复对象，跨过相邻项时实时换位。
5. 清空 `Front` 或 `Back` 后点击 `Export`，对应白色卡片边框变红并在卡片内部居中显示红色报错提示；点击 `+` 添加项目后报错消失。
6. 导出生成的 `.apkg` 卡片正反面内容及顺序与 `Front`、`Back` 列表完全一致（含正反面同时包含同一数据对象的情况），且配置在重启后保留。