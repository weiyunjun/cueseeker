# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **表格普通模式选词交互微调（`C-06` / `L-05.5`）**：
   - **已失效（`Unavailable`）数据行的 `Cues` 文本指针与选词**：鼠标移入 `Unavailable` 行 `Cues` 文本（含主台词与附加字幕）时统一显示 `I-beam` 指针（首行左侧 `?` 状态图标 `Cue State Indicator` 保持默认箭头指针且不可选）；
   - **静态单元格双击与三击选词**：在固定表头各数据列标题（`Cues`、`Display Title`、`Time Range`、`Date Added`）、表体非点击数据列（`Display Title`、`Time Range`、`Date Added`）及 `Unavailable` 行 `Cues` 文本上，支持**双击选中所在词**、**三击选中当前单元格全文**；有效行可点击的 `Cues` 台词文字（`Grab` 指针）维持单击跳转播放，仅支持鼠标拖拽选词，不响应双击与三击选词；
   - **批量选择模式互斥与作用域边界**：进入批量选择模式（`Select Mode`）时立即清除表格内已有文字选区，期间表头与表体全部禁止选词；普通模式下表格选区严格自包含于表头与表体数据列（排除首列 `#` 选择/序号槽位与行尾 `dots-three` 按钮），不与表格上方的 `Cover Summary` 或工具栏串连，复制继续保持 TSV + HTML `<table>` 格式。

2. **从非文字区域或纯点击控件拖入表格起选**：
   - 在不承担自身拖拽职责的区域（页面空白、工具栏按钮/`Filter Chip`、左侧导航栏、`Cover Summary` 不可选区域，以及表格内部的首列 `#` 复选框/序号槽位、失效行 `?` 图标、行尾 `dots-three` 按钮、有效行 `Cues` 悬停底块内边距）按下鼠标左键并拖入表格可选数据区域时，自动进入表格选词；
   - **起点折算与点击取消**：进入表格选词后，**选区起点始终按最初按下鼠标的位置向表格投影折算**（如从左上角工具栏或左侧 `#` 列斜拉进入表格时，从投影落点对应的最前方单元格首字起选，不得丢弃最初按下位置而从半途跨界交点截断起选）；一旦触发表格选词，立即取消起手点击控件的按下态且松开鼠标时不触发原控件点击动作，拖选期间保持 `I-beam` 指针。

3. **全局 `Cmd + A`（全选）收敛**：
   - `Cmd + A`（及系统菜单栏 `Edit -> Select All`）全应用严格仅对当前拥有输入焦点的可编辑文本输入组件（`C-01.1 Text Field`、`C-01.2 Text Area`、`C-01.3 Search Field`、`C-01.4 Number Field`、`C-02.3 Color Well` 中的 `Hex Input`）生效；移除表格及其他非可编辑输入区域对 `Cmd + A` 的全选响应。

# 验收标准

1. **失效行指针与静态格双击/三击**：在 `Search` 与 `Excerpt` 普通模式表格中，悬停表头列标题、`Display Title`、`Time Range`、`Date Added` 及 `Unavailable` 行 `Cues` 文本均显示 `I-beam` 指针（`Unavailable` 行左侧 `?` 图标显示箭头），双击选中单词、三击选中该单元格全文；有效行 `Cues` 文本悬停显示 `Grab` 手型指针，原地单击正常跳转播放，双击或三击不触发双击/三击选词。
2. **跨控件/跨空白斜拉进表格手感正确**：从 `Search` / `Excerpt` 工具栏空白或按钮、`Cover Summary` 封面/按钮空白、左侧导航栏，或表格内部 `#` 列、`?` 图标、`dots-three` 按钮按下左键拖入表格数据列时正常起选；从左上角向右下斜拉进入表格时完整从首格首字选中（无半途截断漏字），且松开鼠标不误触发起手按钮或复选框；进入 `Select Mode` 时表格文字选区立即清除。
3. **`Cmd + A` 全局边界**：焦点在搜索框等可编辑输入框内时按 `Cmd + A`（或点击菜单 `Edit -> Select All`）正常全选输入框内容；焦点不在可编辑输入框内（含点击表格或在表格内选词后）按 `Cmd + A` 无任何全选动作。