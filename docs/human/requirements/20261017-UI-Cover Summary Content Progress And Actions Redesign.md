# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Toast Usage Registry.md`

# 需求描述

1. **Cover Summary 排版与间距 Token 调整（`UI Tokens.md` & `C-11.2 Cover Summary`）**：
   - 宽窗（Split Form）与窄窗（Backdrop Form）下的右侧文字+按钮内容区总高度保持 `180px` 不变。
   - **修改 Token**：
     - `--font-size-cover-summary-title`：`28px` -> `22px`（字重保持 `700`）。
     - `--gap-cover-summary-title-meta`：`14px` -> `8px`（标题与第 1 行副文案间距）。
   - **新增 Token**：
     - `--gap-cover-summary-meta-lines`：`6px`（第 1 行与第 2 行副文案间距）。
     - `--gap-cover-summary-progress-label`：`6px`（进度文字与进度条轨道间距）。
     - `--gap-cover-summary-progress-actions`：`14px`（进度条轨道与底部按钮行间距）。
     - `--height-cover-summary-progress-track`：`5px`（进度条轨道高度，圆角 `--radius-pill`）。
     - `--width-cover-summary-progress`：`290px`（进度条固定宽度，按英文语言下与 Library 二级界面 `...` 按钮右边缘对齐计算，Library 与 Excerpt 二级界面共用）。
   - 移除二级界面顶部封面图的 Hover 修改封面遮罩交互。

2. **Library 二级界面封面区内容、进度条与按钮扩展（`L-04.3 Library Folder Detail Layout`）**：
   - **两行副文案**：
     - 第 1 行：视频与字幕数量，中间以 2 个英文空格分隔（`xx videos  yy subtitles` / `xx 个视频  yy 个字幕`）。
     - 第 2 行：文件夹路径（单行尾部 `...` 截断）。
   - **按需显示进度条区域**：
     - 仅在有继续观看记录（主按钮为 `Resume`）时显示进度条区域；尚未观看过（主按钮为 `Play`）时隐藏进度条及上方文字，底部按钮保持贴底对齐。
     - 进度条上方文字：显示继续观看集数与时间戳，中间以 2 个英文空格分隔（如 `EP05  14:22 / 23:40`），右侧不显示百分比。
   - **底部按钮行（共 3 个按钮，间距 `--spacing-2: 8px`）**：
     - 按钮 1：`Resume` / `Play` 主按钮。
     - 按钮 2：`View in File`（简中 `在文件中查看` / 繁中 `在檔案中檢視`，图标 `folder`）。点击后跳转至 `File` 模块中该文件夹对应的视图；若该文件夹已从媒体库中移除，则拦截跳转并弹出 App Center Toast（Scenario ID：`library.folder.not_in_library`，图标 `warning`，时长 `3s`，英文 `Folder Not in Library` / 简中 `文件夹不在媒体库中` / 繁中 `檔案夾不在資料庫中`）。
     - 按钮 3：`...` 更多按钮（`36px × 36px`，图标 `dots-three`）。点击在按钮正下方弹出菜单，菜单项与 Library 一级界面卡片右键菜单一致（`Open Folder`、`Change Cover`、`Mark All as Finished`、`Mark All as Unwatched`、`Mark All as Watching`）。

3. **Excerpt 二级界面封面区内容、进度条与按钮扩展（`L-05.3 Excerpt List Detail Layout`）**：
   - **两行副文案**：
     - 第 1 行：摘录列表描述（单行尾部 `...` 截断；未填写时显示占位文案）。
     - 第 2 行：台词总数量与创建时间，中间以 2 个英文空格分隔（如 `128 excerpts  Created 2026-09-15`）。
   - **按需显示进度条区域**：
     - 仅在有继续播放记录（主按钮为 `Resume`）时显示进度条区域；尚未播放过（主按钮为 `Play`）时隐藏进度条及上方文字，底部按钮保持贴底对齐。
     - 进度条上方文字：显示 `#x / y  台词内容`（序号与台词内容之间以 2 个英文空格分隔，右侧不重复显示 `x / y`），最大宽度与进度条固定宽度一致，超出单行或遇换行时均在末尾以 `...` 截断。
   - **底部按钮行（共 2 个按钮，间距 `--spacing-2: 8px`，不包含 `Export to Anki`）**：
     - 按钮 1：`Resume` / `Play` 主按钮。
     - 按钮 2：`...` 更多按钮（`36px × 36px`，图标 `dots-three`）。点击弹出菜单，菜单项与 Excerpt 一级界面卡片右键菜单一致（`Edit List`、`Delete List`；仅剩 1 个列表时 `Delete List` 禁用；在二级界面确认删除当前列表后自动退回 Excerpt 一级界面并弹出删除成功 Toast）。

# 验收标准

1. 宽窗（Split Form）与窄窗（Backdrop Form）切换时，Library 与 Excerpt 二级界面封面区右侧内容总高度保持 `180px` 不变，标题字号为 `22px` Bold，顶部封面图 Hover 时不出现修改封面遮罩。
2. Library 二级界面副文案第 1 行为 `xx videos  yy subtitles`（2 个英文空格分隔）、第 2 行为文件夹路径；Excerpt 二级界面副文案第 1 行为描述、第 2 行为 `xx excerpts  Created yyyy-MM-dd`（2 个英文空格分隔）。
3. 当存在继续播放记录（`Resume`）时，两页均显示固定宽度进度条及上方进度信息（Library 为 `EPxx  mm:ss / mm:ss`，Excerpt 为 `#x / y  台词内容` 且在进度条右边缘处单行或遇换行以 `...` 截断）；当从未播放过（`Play`）时，不显示进度条区域，按钮保持在底部原位。
4. Library 二级界面底部显示 `Resume/Play`、`View in File`、`...` 三个按钮；点击 `View in File` 正常跳转到 File 对应目录视图，若文件夹已被移除则拦截并弹出 `Folder Not in Library`（`文件夹不在媒体库中`）Toast。
5. Excerpt 二级界面底部仅显示 `Resume/Play`、`...` 两个按钮；两页的 `...` 按钮弹出菜单遵守全局菜单模态与高亮冻结规则，菜单内容分别与各自一级界面卡片右键菜单一致，在 Excerpt 二级界面删除列表后自动退回一级界面。