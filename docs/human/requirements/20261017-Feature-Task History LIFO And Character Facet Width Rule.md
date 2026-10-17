# 版本

main

# 关联设计

- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/workbench/Search and Filter.md`

# 需求描述

1. **Task 界面 `Completed` 与 `Incomplete` 列表改为 LIFO（后进先出）顺序**：
   - **现状问题**：当前 `TaskRecordDatabase` 与 `TaskQueueStore` 将 `Current`、`Completed`、`Incomplete` 三个标签页均按 FIFO（先发起/先完成的排在前面）排列，导致刚完成或刚失败的任务排在列表最底部。
   - **新排序规则**：
     - **`Current`（进行中）标签页**：保持 **FIFO 顺序不变**（当前正在执行的任务排在最顶部，排队等待的任务按发起先后依次排在下方）。
     - **`Completed`（已完成）与 `Incomplete`（未完成）标签页**：改为 **LIFO 顺序（最新进入 Completed 或 Incomplete 状态的任务排在最顶部）**。
     - **运行期与持久化一致性**：当任务在运行期完成、失败或取消并转入 `Completed` / `Incomplete` 时，新记录插入到对应列表头部（Index `0`）；App 启动从 `TaskRecordDatabase` 读取历史记录时，同样保证最新完成/中止的记录排在最前面。

2. **表格筛选（Filter Dialog）中 `Characters`（字符数）切面的中英文字符宽度计算规则**：
   - **现状问题**：当前 `CueFacetCountCache`（使用 SQLite `LENGTH(l.content)`）、`SearchDatabase` 与 `ExcerptDatabase`（使用 `unicodeScalars.count`）将所有中英文字符均按 `1` 计数，不符合“中文算 2 个字符、英文算 1 个字符”的预期。
   - **新计算规则（Unicode East Asian Width 口径）**：
     1. **首尾裁剪（Trim）**：计算前仅对字幕行归一化单行文本 `content` 做**首尾空白字符裁剪（leading/trailing whitespace trim）**；正文内部的空格与标点符号保留并照常计入字符宽度。
     2. **单字符宽度权重**：遍历裁剪后字符串的 Unicode 标量（或字符），按 **Unicode Standard Annex #11 `East_Asian_Width`（东亚字符宽度）** 规则计算：
        - 凡 `East_Asian_Width` 属性为 **Wide (`W`)** 或 **Fullwidth (`F`)** 的字符（包括但不限于：中日韩统一表意文字汉字、日文平假名与片假名、韩文音节、全角空格 `U+3000`、全角标点符号、全角字母与数字等），**每个字符计为 `2`**；
        - 其余属性（`Narrow (N)`、`Halfwidth (H)`、`Neutral (Na)`、`Ambiguous (A)`，包括英文 ASCII 字母、数字、半角空格 `U+0020`、半角标点、拉丁扩展字母、西里尔字母等），**每个字符计为 `1`**。
     3. **分桶阈值保持不变**：`CueCharacterFacet` 的四个分桶区间保持 `1–10`、`11–20`、`21–30`、`31+` 不变（例如：6 个纯汉字的台词宽度为 `12`，归入 `11–20`；6 个纯英文字母的台词宽度为 `6`，归入 `1–10`；包含 1 个日文全角空格与 4 个假名的台词宽度为 `10`，归入 `1–10`）。
     4. **全链路与缓存一致性**：
        - `CueFacetCountCache`（SQLite 预计算切面缓存，可通过注册 SQLite 自定义标量函数或在写入/回填时统一计算持久化）、`SearchDatabase`（搜索结果动态切面统计与过滤）、`ExcerptDatabase`（摘录列表动态切面统计与过滤）必须复用同一套字符宽度计算实现。
        - 存量数据库中的旧 `CueFacetCountCache` 统计值需通过版本标记或缓存校验自动失效并按新规则重算回填，确保无搜索词/有搜索词下的筛选器计数与实际筛出结果 100% 一致。

3. **设计文档同步**：
   - 待全部改动验收通过后，同步更新 `Library and File.md` 与 `Search and Filter.md`。

# 验收标准

1. 在 Task 弹窗中，`Current` 列表保持按发起顺序 FIFO 排列；`Completed` 和 `Incomplete` 列表中最新完成或最新中止的任务始终排在最顶部（第一项），且重启 App 后顺序保持一致。
2. 字幕行首尾空白不计入字符数，内部半角空格计 `1`、全角空格（如日文空格 `　`）计 `2`、汉字/假名/全角标点计 `2`、英文字母/数字/半角标点计 `1`。
3. 在 Search 界面（含空查询预计算态与关键词搜索态）和 Excerpt 二级界面打开 Filter Dialog，四个 `Characters` 分桶（`1–10`、`11–20`、`21–30`、`31+`）显示的台词数量与勾选后表格实际筛出的行数完全一致，且存量媒体库升级后自动按新规则生效。