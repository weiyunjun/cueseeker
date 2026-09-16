# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Filter Dialog Layout、Filter Chip、Dialog、Library Folder Card Layout）

# 需求描述

## 1. 范围

Search 与 Excerpt 二级界面共用的 Filter 对话框。

## 2. Folder 组

1. 在 Watch Status 之下新增 Folder 组，图标用已有的 `folder`。
2. 每个已索引且有视频配对的文件夹一个胶囊，与 Library Video 标签页是同一集合；名称为文件夹名，与 Video 标签页卡片上的 Folder Name 相同；顺序与 Video 标签页相同。
3. Search 与 Excerpt 都列出完整的文件夹；没有命中的文件夹显示 0，仍可点击。
4. 计数语义与其他组相同：本组数字忽略本组勾选，叠加其他组；其他组的数字叠加本组勾选。
5. 勾选与现有筛选一起记忆。

## 3. 索引后新增的文件夹

1. Folder 组有勾选时，索引后新增的文件夹为勾选；没有勾选时为未勾选。
2. 该规则对 Search 与每个 Excerpt 列表都成立，重启后同样成立。
3. 列出的文件夹全部未勾选时等同于没有筛选。

## 4. Language 组

Excerpt 与 Search 相同，列出索引中出现过的全部语言；列表里没有的显示 0。

## 5. 胶囊

1. 新增 token `--max-width-filter-chip`：`332px`。胶囊不超过该宽度，名称单行，超出时尾部省略号。
2. 其余尺寸、颜色与交互不变。

## 6. 对话框高度

1. 新增 token `--height-filter-dialog`：`600px`。对话框高度固定为该值，不随内容变化。
2. Header 与 Footer 不动，其间的各组滚动；内容不足时下方留空。
3. 窗口高度不足时按 Dialog 现有规则收缩。

## 7. 搜索顺序

1. Folder 组有勾选时，扫描先读勾选文件夹的文件，再读其余文件，两段内部仍按显示次序。
2. 扫描完成时快照回到显示次序，之后改勾选的投影不变。
3. 一趟全量扫描、两次推送、对话框更新时刻、总数未知时 Show 为 Disabled、完成后改勾选不重新搜索，均按 `20260915-Feature-Search Single Full Scan And Show Disabled Until Search Completes.md` 不变。

## 8. 基线

1. 改代码前在当前版本记录基线：无勾选搜索 `の`，冷 1 次、热 2 次，记录首屏与完成耗时。
2. 改完后同样测量：完成耗时不慢于基线，首屏一并对比，回退即停止并报告。
3. 再测只勾选一个 Folder 的 `の`：首屏不慢于无勾选，完成耗时相近。

## 9. 设计文档同步

验收通过后更新 `UI Design System.md`：Filter Dialog Layout 加入 Folder 组与固定高度，Filter Chip 加入最大宽度与截断，新增第 5、6 节的两个 token。

# 验收

1. 对话框底部为 Folder 组，图标为 folder；胶囊集合、名称与顺序和 Library Video 标签页一致；Search 与 Excerpt 都列出完整文件夹，没有命中的显示 0。
2. Excerpt 的 Language 组列出与 Search 相同的全部语言。
3. 五位数计数时一行放 2 个胶囊，长名称尾部省略号；对话框高 600，内容超出时中间滚动，不足时下方留空。
4. 勾选 Folder 后 Show：表格只含该文件夹的结果，行数等于总数；完成后改勾选不重新搜索。
5. 有勾选时索引新增文件夹后打开对话框，新文件夹为勾选；无勾选时为未勾选；重启后一致（人工验收）。
6. 第 8 节的三次测量已记录并满足要求。
7. 现有自动化端到端与单元用例全部通过；不为本需求新增 E2E 能力。