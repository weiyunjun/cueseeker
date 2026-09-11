# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Dialog、Segmented Control、Checkbox、Text Field、Icon Button、Button）
- `docs/human/design/UI Application Rules.md`（界面层级、焦点）
- `docs/human/design/Icon Registry.md`（`link-simple`、`subtitles`、`video`、`folder`）

# 需求描述

## 1. 入口

1. 在 Search 与 Shiori 表格中执行 Export to Anki 时，先打开 Export to Anki 对话框，不再弹出系统保存面板。

## 2. 对话框

1. 结构，从上到下：
   1. Header：Title `Export to Anki`、Close Button
   2. `Cue Text Side`：Segmented Control，选项 `Front`、`Back`
   3. `Required`：Checkbox `Cue Text`、`Audio`，始终勾选，不可取消，显示为 Checked + Disabled
   4. `Optional`：Checkbox `Screenshot`、`Cue Group Text`、`Display Title`、`Time Range`、`Deep Link`、`Subtitle File Path`、`Video File Path`
   5. `File Name`：Text Field
   6. `Location`：文件夹完整路径，右侧为 Icon Button / `folder`
   7. Footer：`Cancel`、`Export`
2. 宽度 `--width-dialog-large`，高度随内容，随窗口缩小按 Dialog 规则处理；内容滚动时滚动条不预留宽度，与 Shiori List Editor 一致。
3. 布局：
   1. 组标题同 Text Field 的 Label，与内容相距 `--spacing-2`；组与组相距 `--spacing-4`。
   2. 勾选项每行两个、两列等宽，按上列顺序从左到右、从上到下排列；行距 `--spacing-3`，列距 `--spacing-4`；勾选框与文字相距 `--spacing-2`，文字为 `--font-size-body`、`--color-text-primary`。
   3. Location 路径的字号与颜色同 Rename 的 Current Name，单行，过长时中间截断；文件夹按钮的字形右缘与内容右缘对齐。
4. 普通对话框：不阻止关闭 App；打开时没有默认焦点；回车等同 Export，Esc 与 Close Button 等同 Cancel。

## 3. 默认值与记忆

1. 默认：Cue Text Side 为 `Back`；Optional 只勾 `Screenshot`；File Name 为现有默认文件名；Location 为 Downloads 文件夹。
2. Cue Text Side、Optional 的勾选与 Location 在 App 重启后保留，Search 与 Shiori 共用；File Name 每次打开按当时时间重新生成。
3. 保留的文件夹已不存在时，Location 回到 Downloads 文件夹。

## 4. 操作

1. 点击文件夹按钮打开系统文件夹选择面板；选定后更新 Location，对话框保持打开。
2. 点击 Export：
   1. File Name 为空或不合规时，按 Rename 的校验规则与提示文案（不含"名称未改变"）在输入框下方提示，对话框保持打开。
   2. File Name 不以 `.apkg` 结尾时自动补上。
   3. 目标文件已存在时弹出系统警告框：标题 `“<文件名>” already exists. Do you want to replace it?`，说明 `A file or folder with the same name already exists in the folder “<文件夹名>”. Replacing it will overwrite its current contents.`，按钮 `Cancel`、`Replace`（Destructive）。Cancel 回到对话框；Replace 继续导出并覆盖。
   4. 通过后对话框关闭，导出进入任务队列，在任务界面查看进度与结果，与现有 Anki 导出任务相同。

## 5. 卡片内容

1. 字幕文字所在的一面由 Cue Text Side 决定，从上到下：
   1. Cue Text
   2. Cue Group Text：同一 Cue Group 中 Cue Text 以外的字幕行，按字幕中的顺序，每行一行
   3. Display Title 与 Time Range，同一行，中间两个空格；Time Range 格式与表格的 Time Range 列相同
   4. Deep Link、Subtitle File Path、Video File Path 的图标，同一行，中间各两个空格；图标依次为 `link-simple`、`subtitles`、`video`
2. 另一面为 Audio 与 Screenshot。
3. 背面先显示正面的内容，与现在相同。
4. 未勾选的项不出现；某项没有内容时不出现（如单语字幕没有 Cue Group Text，没有 Cue 身份的 Shiori 没有 Deep Link）；一行中的项都不出现时整行不出现。
5. 点击图标：Deep Link 打开该 Cue 的 Deep Link；Subtitle File Path、Video File Path 分别用系统默认 App 打开字幕文件、视频文件。只要求 Anki 桌面版可用。

## 6. 保持不变

1. 卡片沿用现有样式；牌组、音频、截图的生成方式与卡片编号规则不变。

# 验收

1. 在 Search 与 Shiori 中执行 Export to Anki：打开对话框，不弹出系统保存面板。
2. 首次打开：`Back` 选中；Required 两项勾选且不能取消；Optional 只勾 `Screenshot`；Location 为 Downloads；没有控件获得焦点。
3. 修改 Cue Text Side、Optional 与 Location 后重启 App 再打开：保持修改后的值，File Name 为新的时间。
4. 对话框打开时点击红灯或按 Cmd+Q：App 直接退出。
5. 点击文件夹按钮：弹出系统文件夹选择面板，选定后 Location 更新。
6. 清空 File Name 后点击 Export：输入框下方出现提示，对话框不关闭。
7. 导出到已存在的文件：出现系统警告框；Cancel 回到对话框；Replace 后文件被覆盖。
8. 导出后：任务界面显示该任务的进度与结果。
9. 全部勾选、`Back`，导入 Anki：正面为音频与截图；背面依次为 Cue Text、Cue Group Text、Display Title 与 Time Range、三个图标；三个图标分别打开 Deep Link、字幕文件、视频文件。
10. `Front`，导入 Anki：正面为字幕文字一面的内容；背面在其后显示音频与截图。
11. 只勾 `Screenshot` 导出，以及导出单语字幕：卡片上没有空行。
12. 窗口缩到最小：对话框变窄变矮，Header 与 Footer 不动，中间内容滚动，滚动条不预留宽度。
13. Light 与 Dark 分别核对对话框。
14. 本次改动不新增任何自动化端到端或单元用例的失败。