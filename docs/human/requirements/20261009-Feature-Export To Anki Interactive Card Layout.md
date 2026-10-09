# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialog、Settings Group Card、Filter Chip、Icon Button、Text Field、Button）
- `docs/human/design/UI Application Rules.md`（界面层级、焦点、指针）
- `docs/human/design/Icon Registry.md`（`dots-six-vertical`、`x`、`folder`）

# 需求描述

## 1. 结构变更

1. 移除现有的 `Cue Text Side` 切换栏以及 `Required` 与 `Optional` 复选框列表。
2. 移除原有的 `Video File Path` 与 `Subtitle File Path` 导出选项（Anki 不支持此地址）。
3. 导出项目候选池总计 7 项：`Screenshot`、`Audio`、`Cue Text`、`Cue Group Text`、`Display Title`、`Time Range`、`Deep Link`。
4. 表单核心区域调整为可交互的卡片排版区：
   1. `Available Items`：候选池，固定高度容纳所有徽章，全部移出时显示占位提示。
   2. `Card Layout`：包含 `Front` 与 `Back` 两列卡片放置区，最小容纳 5 个徽章高度，超过 5 个自适应撑开；内部为空时显示占位提示。
5. 对话框宽度保持 `--width-dialog-large`（600px），超出窗口可用高度时中间表单区域垂直滚动，Header 与 Footer 固定。

## 2. 交互与排序

1. Available Items、Front、Back 之间支持鼠标自由拖拽。
2. Front 与 Back 内的徽章带有 6 点拖拽手柄（`dots-six-vertical`）与删除按钮（`✕`）：
   1. 手柄支持在卡片内上下拖拽调整顺序，并在落位处显示高亮指示线。
   2. 点击删除按钮（`✕`）将该项目移回 Available Items。
3. Available Items 区域的徽章顺序固定：任何项目移回 Available Items 时，均按固定的标准顺序归位，不追加到末尾。

## 3. 默认值与记忆

1. 首次打开默认：Front 放置 `Audio`，Back 放置 `Cue Text`，其余 5 项位于 Available Items。
2. 徽章在各区域的位置与顺序在 App 重启后保留，Search 与 Excerpt 共享此配置。
3. File Name 与 Location 保留现有规则（File Name 每次打开生成，Location 记住上次选择）。

## 4. 校验拦截

1. 点击 Export 时，若 Front 或 Back 任一区域没有徽章：
   1. 拦截导出，保持对话框打开，不触发任务。
   2. 在为空的卡片内显示红色文字提示（颜色为 `--color-danger-text`），对应边框变红：
      - Front 为空：提示“正面不能为空” / “正面不能為空” / “Front cannot be empty”。
      - Back 为空：提示“背面不能为空” / “背面不能為空” / “Back cannot be empty”。
   3. 拖入徽章后错误状态自动清除。
2. File Name 校验保持现有重命名规则。

## 5. 卡片导出排版（所见即所得）

1. 导出 Anki 卡片的项目顺序严格与 Front、Back 区域内自上而下的视觉顺序一致。
2. Front 区域的项目渲染在正面（Question）；Back 区域的项目渲染在背面（Answer）的分割线下方。
3. 未放入 Front 或 Back 的项目不导出。

# 验收

1. 打开 Export to Anki 对话框：展示 Available Items、Front、Back 三个卡片区域，不再显示原复选框与单选控件。
2. 首次打开：Front 有 `Audio`，Back 有 `Cue Text`，其余 5 项在 Available Items；Available Items 高度固定不抖动。
3. 拖拽交互：
   1. 可在三者之间自由拖放。
   2. Front 和 Back 内可通过 6 点手柄自由调整上下位置。
   3. 点击 Front/Back 徽章右侧 `✕`，项目归位到 Available Items 且顺序保持固定。
4. 校验拦截：
   1. 将 Front 清空并点击 Export：拦截导出，Front 区域显示红字“正面不能为空”。
   2. 将 Back 清空并点击 Export：拦截导出，Back 区域显示红字“背面不能为空”。
   3. 补齐徽章后红字消失，可正常导出。
5. 导出验证：
   1. 调整徽章顺序并导出导入 Anki：卡片正面与背面内容及上下排列顺序与界面完全一致。
   2. 重启 App 后再次打开对话框：徽章落位与顺序保持上次配置。
6. 窗口缩小时中间区域出现滚动条，Header 与 Footer 正常固定。
7. 中简、中繁、英文三种语言文案正常。