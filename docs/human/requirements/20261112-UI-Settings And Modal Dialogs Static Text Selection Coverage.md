# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **`Settings` 设置窗口右侧分类内容区覆盖（`L-02.3` ~ `L-02.5`）**：
   - 在 `Settings` 右侧全部 4 个分类页（`General`、`Play`、`Shortcuts`、`Subtitle`）中，开放所有卡片组标题（`Group Title`）以及每一行左侧的设置项名称、快捷键功能名称为可选展示文本（悬停显示 `I-beam` 指针，支持跨行连选、从右侧开关/控件或空白拖入起选、双击选词、三击选整段、视口边缘自动滚屏及 `Cmd + C` 复制，与 `Shortcuts` 页已有的红色校验提示无缝连入同一连续文本流）；
   - 设置窗口顶栏（含顶栏分类标题）、左侧分类导航栏、右侧开关/分段控制器/下拉按钮/颜色块/快捷键录制框（`C-01.5`）及恢复默认按钮保持不可选中文本。

2. **详情弹窗完整键值流覆盖（`L-06.8 File Detail Dialog`、`L-06.11 Task Detail Dialog`）**：
   - 在 `Folder Info`、`File Info`、`Task Info` 中，开放弹窗左上角主标题、顶部静态对象名称行（`Folder Info` 文件夹图标右侧名称、`Task Info` 任务图标右侧类型名称；`File Info` 顶部带下拉箭头的可点击配对文件切换触发器属于交互控件，除外）、下方所有属性分组标题（`Property Group Title`）、以及各属性行左侧固定属性名称（含关联文件/目录列表左侧的 `#1`、`#2`... 序号标签），与右侧已开放的属性值共同组成完整连续文本流（同一属性行左右两侧同时选中复制时以 `\t` 分隔，跨行以 `\n` 分隔）。

3. **其余模态对话框标题、表单标签、说明小字与通用空状态提示语覆盖（`L-06.1` ~ `L-06.10`、`C-09.2`）**：
   - 开放全部模态对话框与任务面板左上角主标题（`Edit Cover`、`New / Edit Excerpt List`、`Rename Folder / Files`、`WebDAV / SMB / FTP / NFS Folder`、`Export to Anki`、`Filter`、`Task`、`Confirmation`）；
   - 开放所有表单字段标签与列标题：`Excerpt List Editor` 的 `Name` / `Description` 标签、`Rename` 左侧 `Current Name` / `New Name` 标签（`Current Name` 标签与右侧当前名称同行同时选中时复制以 `\t` 分隔）、远程文件夹弹窗 Step 1 左侧 `Address` / `Port` / `Username` / `Password` 标签、`Export to Anki` 卡片区顶部的 `Front` / `Back` 列标题（同行同时选中时复制以 `\t` 分隔）及底部 `File Name` / `Location` 标签、`Filter` 各筛选维度分组标题（右侧选中数量胶囊徽章除外）；
   - 开放 `Edit Cover` 与 `Excerpt List Editor` 封面下方的尺寸与格式说明小字（`Support Text`），以及全应用所有 `C-09.2 Empty State` 大图标下方的提示语（下方可选操作按钮除外）；
   - 对话框关闭按钮与底部按钮、`Filter Chip` 与计数徽章、`Keycap`、`Export to Anki` 卡片内可拖拽排序的数据胶囊、封面选图遮罩与裁剪框保持不可选中文本。

# 验收标准

1. **`Settings` 四分类页验证**：在 `Settings` 全部 4 个分类页中，分组标题、左侧设置项/快捷键名称与校验红字均显示 `I-beam` 指针，支持跨分组连续拖选（含从右侧开关按钮向左拖入文字起选且不误触开关）、边缘滚屏、双击/三击选词与 `Cmd + C` 复制；顶栏、左侧导航栏与快捷键录制框不可选。
2. **详情弹窗与模态弹窗验证**：在 `Folder Info` / `File Info` / `Task Info`、`Rename`、`Export to Anki`、`Filter`、`Edit Cover`、`Excerpt List Editor`、远程连接弹窗及各空状态页中，所有指定标题、标签、说明小字与空状态提示语均支持 `I-beam` 选词复制；`File Info` 顶部配对文件下拉触发器与 `Export to Anki` 可拖拽数据胶囊不可选中文本；跨左右键值复制粘贴验证同行 `\t`、跨行 `\n` 分隔正确。