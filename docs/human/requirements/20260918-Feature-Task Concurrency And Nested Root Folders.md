# 版本

main

# 关联设计

- `docs/human/design/Data.md`（Index 流程第 1–8 节）
- `docs/human/design/UI Design System.md`（Task Panel Layout、Task Card Layout、File Page Layout）

# 需求描述

## 1. 范围

任务队列由“同一时刻只执行一个任务”改为按类别并发；Index Now、Add Folder、Remove Folder 成为任务；根目录允许嵌套，有包含关系的根目录按最外层文件夹处理。本单取代此前需求中的“一次一个”。

## 2. 任务类别与并发

1. 导出类：Export to Anki。可连续新建，同一时刻执行一个，其余按发起顺序排队。
2. Index 类：Index Now、Add Folder、Remove Folder、Rename Folder、Rename Files。同一时刻最多存在一个，不排队；已存在时任务队列拒绝新建 Index 类任务。
3. 两类互不等待，可同时各执行一个。
4. 改名开始时，若有导出任务（执行中或排队）引用相同文件，改名转 Incomplete。
5. 导出开始时，若有正在执行的改名涉及它的文件，导出转 Incomplete。
6. 以上两种冲突，磁盘与数据库均无变化。
7. 数据库压缩为开发者选项，不进入任务队列。

## 3. 根目录分组

1. 添加文件夹不做拦截：相同文件夹、子文件夹、父文件夹都允许添加。
2. 有包含关系的根目录归为一组，由最外层文件夹代表。索引、移除与 Edit 显示都按代表文件夹处理。
3. 组的顺序取组内最早添加的文件夹的位置。例：依次添加 A、B、C，A 是 C 的子文件夹，则 Index 顺序为 C、B。
4. 添加与移除只处理覆盖范围的变化：
   1. 添加已被包含的文件夹：不索引。
   2. 添加父文件夹：只索引新增部分，子文件夹已有数据保留。
   3. 移除仍被其它根目录包含的文件夹：不删除数据。
   4. 移除父文件夹：只删除不再被任何根目录覆盖的部分。
5. 覆盖范围没有变化的 Add Folder 与 Remove Folder 仍创建任务，并立即完成。重复添加同一文件夹，列表不增加。
6. File 页根目录列表显示全部根目录，按添加顺序排列。
7. File 页 Edit 按组显示，每组以代表文件夹为准，组的顺序同第 3 条。

## 4. 任务行为

1. Index Now：按组顺序索引全部组。执行中可移除，四个阶段都在当前文件或封面完成后立即停止，已完成的组与已提交的数据保留。
2. Add Folder：索引新增的文件夹，完成后才加入根目录列表。执行中可移除，移除后按第 3 节第 4 条的移除规则清除它新增的数据，文件夹不加入列表，File 页不显示移除进度与“已移除”提示。
3. Remove Folder：确认对话框在创建任务之前；完成后根目录才从列表消失；File 页的移除进度与“已移除”提示保持不变。执行中不可移除。
4. Rename Folder、Rename Files：执行中不可移除。
5. 被移除的任务转 Incomplete，错误信息为 `Cancelled by user`。
6. 执行中退出 App，重新启动后任务转 Incomplete，错误信息为 `Interrupted before the task finished`；Add Folder 同时按第 2 条清除它新增的数据。
7. File 页的 Index 状态区保持不变，与任务卡片显示同一次任务的状态。

## 5. Index 进度

适用于 Index Now 与 Add Folder。

1. 四个阶段，权重固定：Scanning files 20%、Indexing subtitles 40%、Reading video info 20%、Generating covers 20%。
2. 与 Data.md 的对应：Scanning files 对应第 1、2 节；Indexing subtitles 对应第 3、4 节；Reading video info 对应第 5 节；Generating covers 对应第 6、7 节。
3. 阶段内按该阶段自己的数量均分本阶段权重：字幕文件数、待更新视频数、待生成封面数。
4. Scanning files 没有数量，进度停在阶段起点，结束时推进到 20%。
5. 数量为 0 的阶段按整段权重直接跳过。
6. 多组时总进度按组数均分。

## 6. 任务卡片

Index 与 Add Folder 的 Current 卡片自上而下：

1. Task Status Badge、任务名、Remove Action。
2. 文件夹完整路径，一行一个，超长时中间截断。Index 为全部代表文件夹，Add Folder 为新增的文件夹。
3. Progress Text：阶段、当前文件夹名、阶段内计数，例如 `Generating covers · Anime · 12 / 40`。Scanning files 不显示计数。
4. Progress Bar。

Remove Folder 的 Current 卡片自上而下：

1. Task Status Badge、任务名，不显示 Remove Action。
2. 根目录完整路径。

Remove Folder 没有 Progress Text 与 Progress Bar。

Index、Add Folder、Remove Folder 的 Completed 与 Incomplete 卡片自上而下：

1. 任务名、Delete Action。
2. 文件夹完整路径。
3. Index 与 Add Folder 左对齐显示结果摘要；时间右对齐，日期格式与现有卡片一致。
4. 错误信息，仅 Incomplete。

导出与改名卡片保持现状。

## 7. 置灰规则

1. 存在 Index 类任务时，Index Now、Add Folder、每行 Remove、Edit 的 Rename Folder 与 Rename Files 均为 Disabled。改名菜单的文字提示后续补充。
2. 存在 Index 类任务时，数据库压缩为 Disabled。
3. 导出的入口不受 Index 类任务影响。

## 8. 确认对话框

1. Remove Task 只出现在导出、Index Now、Add Folder 三种任务上，文案按任务类型区分，不再用文件名填空。
2. 导出的 Remove Task 与 Delete Record 文案保持现状。
3. 其余五种任务的 Delete Record 使用统一文案。

## 9. 文案

`{folder}` 为文件夹名。

| 用途 | English | 简体 | 繁体 |
| --- | --- | --- | --- |
| 任务名 | Index | 索引 | 索引 |
| 任务名 | Add Folder | 添加文件夹 | 加入資料夾 |
| 任务名 | Remove Folder | 移除文件夹 | 移除資料夾 |
| 阶段 1 | Scanning files | 正在扫描文件 | 正在掃描檔案 |
| 阶段 2 | Indexing subtitles | 正在解析字幕 | 正在解析字幕 |
| 阶段 3 | Reading video info | 正在读取视频信息 | 正在讀取影片資訊 |
| 阶段 4 | Generating covers | 正在生成封面 | 正在產生封面 |
| 结果摘要 | {count} subtitles indexed | 已索引 {count} 个字幕 | 已索引 {count} 個字幕 |
| 改名被拒 | An export task is using these files | 导出任务正在使用这些文件 | 匯出任務正在使用這些檔案 |
| 导出被拒 | A rename task is moving these files | 重命名任务正在移动这些文件 | 重新命名任務正在移動這些檔案 |
| 移除 Index Now | Index will stop and move to Incomplete. Folders already indexed keep their data. | 索引将停止并移入未完成。已完成索引的文件夹会保留数据。 | 索引將停止並移入未完成。已完成索引的資料夾會保留資料。 |
| 移除 Add Folder | Adding “{folder}” will stop and move to Incomplete. The folder is not added, and what it already indexed is removed. | 添加“{folder}”将停止并移入未完成。该文件夹不会被添加，已索引的内容会被清除。 | 加入「{folder}」將停止並移入未完成。該資料夾不會被加入，已索引的內容會被清除。 |
| 删除记录（导出以外） | Only the record is deleted. What the task did is not undone. | 只删除这条记录，不会撤销任务的结果。 | 只刪除這筆記錄，不會復原任務的結果。 |

## 10. 约束

1. 任务卡片、进度条、徽标复用现有实现，不为新任务另起一份。
2. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。

## 11. 设计文档同步

本需求验收通过后再更新 `UI Design System.md` 的 Task Card Layout 与 File Page Layout。

# 验收

1. 导出与 Index Now 同时执行，各自进度独立推进。
2. 连续新建两个导出，只有第一个执行，第二个为 Queued。
3. 存在 Index 类任务时，Index Now、Add Folder、每行 Remove、两个改名菜单、数据库压缩均为 Disabled，导出仍可新建。
4. 改名开始时有导出引用相同文件，改名转 Incomplete；改名执行中开始的导出引用其文件，导出转 Incomplete；两种情况磁盘与数据库均无变化。
5. Index 任务卡片依次经过四个阶段，阶段文字与计数正确，进度按 20 / 40 / 20 / 20 推进；全部文件未变化时后三个阶段整段跳过。
6. 在任一阶段移除 Index Now，当前文件或封面完成后即停止，转 Incomplete，错误信息为 `Cancelled by user`，已完成的组保留。
7. 移除执行中的 Add Folder 后转 Incomplete，该文件夹不在列表中，它新增的内容不出现在任何页面，其它根目录的数据不受影响，File 页不显示移除提示。
8. 任务执行中退出 App，重新启动后该任务为 Incomplete，错误信息为 `Interrupted before the task finished`；Add Folder 新增的数据已被清除。
9. 依次添加 A、B、C，A 是 C 的子文件夹：列表显示 A、B、C；Index Now 顺序为 C、B；Edit 先显示 C 组，A 的内容在 C 组内，再显示 B。
10. 添加已被包含的子文件夹或重复添加同一文件夹，任务立即完成且不索引；重复添加时列表不增加。
11. 添加父文件夹后，子文件夹已有数据保留，只索引新增部分。
12. 移除仍被父文件夹包含的子文件夹，任务立即完成且数据不变；移除父文件夹而子文件夹保留，只删除子文件夹以外的部分。
13. Remove Folder 完成后根目录从列表消失，Library、Search、Recent、Shiori 的刷新与改动前一致；卡片没有进度条，执行中没有 Remove Action。
14. 各确认对话框按第 9 节显示，不出现空引号。
15. File 页 Index 状态区的行为与改动前一致。
16. 现有自动化端到端与单元用例全部通过，调度判定与根目录分组有单元用例覆盖。