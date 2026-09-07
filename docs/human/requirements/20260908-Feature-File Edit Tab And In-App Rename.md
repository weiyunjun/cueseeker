# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Tabs、Tab、Context Menu、Menu Item、Dialog、Text Field、Button / Neutral、Button / Primary、Library File Tree Layout、File Page Layout、Recent Layout、Task Panel Layout、Task Card Layout、Progress Indicator / Bar、Empty Hint）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中、指针）
- `docs/human/design/Data.md`（Index 流程、永久身份与路径分离）

# 需求描述

## 1. 目标

File 页面增加 `Index` 与 `Edit` 两个 Tab。Edit 提供 App 内改名：Folder 改名、视频与字幕整体改名。改名只改路径，不动任何 ID；观看状态、进度、历史、Shiori、封面全部保留；改名后无需 Index。本次不做 Folder 移动。

## 2. File 页面 Tabs

1. 页标题下方为 Tabs：`Index`、`Edit`，样式与 Recent 相同，首个标签与页面内容左边界对齐。
2. Index 为现有 File 页面的全部内容，不变。
3. 默认 Index；Tab 选择在 App 运行期间保留，重启回到默认。

## 3. Edit 树

1. 结构：Folder → Display Title → 视频文件、字幕文件。不显示根目录层级；根目录自身含配对时也是一个 Folder。
2. Folder 标签显示完整路径，其余行、图标、缩进、字号、颜色沿用 Library File Tree Layout。
3. Folder 与 Display Title 默认折叠；展开状态离开页面后回到默认；顺序与 Metadata 展平后一致。
4. Folder 行允许 Hover，与 Display Title 行相同；Metadata 页不改。
5. 数据库没有任何配对时，整页显示 Metadata 现有的空内容提示。

## 4. 右键菜单

1. Folder 行：`Rename Folder`。
2. Display Title、视频、字幕行：`Rename Files`，作用于该视频及其全部匹配字幕。
3. Index、移除根目录、数据库压缩进行中时两项置灰；改名任务运行或排队期间，Index 页的 Add Folder、Index Now、Remove 置灰。
4. 菜单模态与滚动与其他 Workbench 右键菜单一致，滚动为整窗口禁止。

## 5. 改名 Dialog

1. 结构：Header（标题、关闭按钮）；静态文字（当前名）；Text Field（新名）；Footer（Cancel、Primary 确认）。复用 Shiori List Editor 的 Form Region 与 Footer，无封面列。
2. Folder 改名：静态文字为完整路径，输入框只编辑最后一段。
3. 整体改名：静态文字为当前公共名，即去掉一级与二级扩展名后的公共部分；输入框编辑新公共名，各文件的扩展名尾巴不变。
4. 语法校验在 Dialog 即时提示，不合法不能确认：空或仅空白；与原名相同（区分大小写，仅 Unicode 规范化不同视为相同）；以 `.` 开头；以空格或 `.` 结尾；含 `\ / : * ? " < > |` 或控制字符；为 Windows 设备名（CON、PRN、AUX、NUL、COM1–COM9、LPT1–LPT9，不分大小写，带扩展名也算）。
5. 确认后关闭 Dialog，任务入队。

## 6. 任务

1. 两种任务：`Rename Folder`、`Rename Files`，进入现有任务队列，一次一个。
2. 两个阶段：冲突检测、执行，进度条各占一半；Current 卡片显示阶段文字与进度条。
3. 冲突检测只读，任一不满足即转 Incomplete 并说明原因：涉及文件存在且大小、修改时间与数据库一致；用改名后的文件名列表模拟 Data.md 的匹配规则，所在文件夹的配对与改名前一一对应，只有本任务的文件换名；新路径在磁盘上不存在（存在但与源为同一对象不算），在数据库中也不存在；涉及视频不是当前播放视频；队列中排在后面的导出任务不引用涉及文件。
4. 执行：Folder 改名为一次文件夹重命名，其下全部文件与已索引子文件夹的路径按前缀级联更新，该文件夹是根目录时根目录记录一并更新。整体改名逐文件重命名，某个文件失败则已改的改回。
5. 数据库在一个事务内更新：涉及文件的身份行与所有存路径的列；受影响文件夹的 Display Title、Search 排序与 Library 展示行按文件夹范围重算；其余数据一律不动。事务失败则文件系统改回。
6. 排队任务使用入队时的路径；源已被前面的任务改掉时由冲突检测拒绝。
7. Current 的 Remove：排队中可移除，运行中不可移除。
8. Completed 卡片：Folder 改名显示任务名、旧名、新名、时间；整体改名显示任务名、全部文件旧完整路径、全部文件新完整路径、时间。路径一行一个，超长沿用明细行的中间截断。Incomplete 多一行报错。
9. 任务完成后 Library、Search、Recent、Shiori、Edit 树立即显示新名，与 Index 完成后的刷新一致。

## 7. 文案

| 用途 | English | 简体 | 繁体 |
| --- | --- | --- | --- |
| Tab | Index | 索引 | 索引 |
| Tab | Edit | 编辑 | 編輯 |
| 菜单项、任务名、Dialog 标题 | Rename Folder | 重命名文件夹 | 重新命名資料夾 |
| 菜单项、任务名、Dialog 标题 | Rename Files | 重命名文件 | 重新命名檔案 |
| 输入框标签 | New Name | 新名称 | 新名稱 |
| 确认按钮 | Rename | 重命名 | 重新命名 |
| 阶段 1 | Checking for conflicts | 正在检测冲突 | 正在檢查衝突 |
| 阶段 2 | Renaming | 正在重命名 | 正在重新命名 |
| 校验：空 | Enter a name | 请输入名称 | 請輸入名稱 |
| 校验：相同 | The name is unchanged | 名称未改变 | 名稱未變更 |
| 校验：非法 | The name can't start with a period, end with a space or period, contain \ / : * ? " < > \|, or be a Windows reserved name | 名称不能以 . 开头，不能以空格或 . 结尾，不能包含 \ / : * ? " < > \|，也不能是 Windows 保留名 | 名稱不能以 . 開頭，不能以空格或 . 結尾，不能包含 \ / : * ? " < > \|，也不能是 Windows 保留名稱 |
| 冲突：已变化 | Files changed since the last index. Index again first | 文件在上次索引后已变化，请先重新索引 | 檔案在上次索引後已變更，請先重新索引 |
| 冲突：同名 | “{name}” already exists in this folder | 文件夹中已存在“{name}” | 資料夾中已存在「{name}」 |
| 冲突：配对 | Renaming to “{name}” would change how videos and subtitles are paired | 改为“{name}”会改变视频与字幕的匹配关系 | 改為「{name}」會改變影片與字幕的配對關係 |
| 冲突：播放中 | The video is playing | 该视频正在播放 | 該影片正在播放 |
| 冲突：导出 | A queued export uses these files | 排队中的导出任务正在使用这些文件 | 排隊中的匯出任務正在使用這些檔案 |
| 执行失败 | Couldn’t rename “{path}”. Files were restored | 无法重命名“{path}”，文件已恢复 | 無法重新命名「{path}」，檔案已還原 |
| 写库失败 | Couldn’t update the database. Files were restored | 无法更新数据库，文件已恢复 | 無法更新資料庫，檔案已還原 |

## 8. 实现约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. Tabs、树、右键菜单、Dialog、任务卡片复用现有实现，禁止另起一份。
3. 匹配模拟复用 Data.md 匹配规则的现有实现，只增加接受文件名列表的入口。
4. 任务记录表新增旧路径与新路径两列，现有列含义不变。

## 9. 设计文档同步

本需求验收通过后再更新设计文档：`UI Design System.md` 的 File Page Layout 增加 Tabs 与 Edit 树布局，Context Menu 增加两个菜单，Dialog 增加改名 Dialog 布局，Task Card Layout 增加两种任务的结构；`UI Application Rules.md` 指针规则 3 的界面切换清单增加 File 的 Index/Edit，菜单模态第 6 条表格增加 Edit 树右键菜单；`Data.md` 补充 App 内改名保持全部 ID，并把路径表述改为绝对路径是身份、相对路径随存。

# 验收

1. File 页标题下出现 Index、Edit 两个 Tab；Index 内容与改动前一致；离开再回来仍是上次的 Tab，重启回到 Index。
2. Edit 树从 Folder 起，标签为完整路径；根目录自身含配对时显示为一个 Folder；Folder 与 Display Title 默认折叠；Folder 行有 Hover。
3. Folder 行右键只有 Rename Folder；Display Title、视频、字幕行右键只有 Rename Files；Index 进行中两项置灰。
4. Dialog 结构与第 5 节一致；空名、原名、以 . 开头、含保留字符、Windows 设备名分别即时提示且不能确认。
5. Folder 改名成功后：Finder 中文件夹已改名；Edit 树、Library 卡片、Search 结果、Recent、Shiori 立即显示新名；含已索引子文件夹时其路径同步更新；根目录改名后 Index 页根目录列表同步更新。
6. 整体改名成功后：视频与全部匹配字幕在 Finder 中同时改名，扩展名不变；同文件夹其他对象的 Display Title 序号随排序变化正确更新。
7. 改名后观看状态、进度、历史、Shiori、自定义封面全部保留；随后 Index Now 报告全部文件未变化，不重新解析。
8. 只改大小写的改名成功，Finder 与 App 内均显示新大小写。
9. 冲突逐项验证：在 App 外修改涉及文件后改名、改为文件夹内已有名字、改为会收养孤儿字幕的名字、改名前先排队一个引用该文件的导出，均转 Incomplete 并显示对应报错，磁盘与数据库均无变化。
10. 任务面板：Current 显示两阶段进度；Completed 卡片字段与第 6.8 节一致；排队中可移除，运行中不可移除。
11. 三种语言、Light 与 Dark 分别核对。
12. 现有自动化端到端与单元用例全部通过；改名、回退、冲突检测有单元用例覆盖。