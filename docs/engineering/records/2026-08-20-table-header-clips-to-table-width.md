# Table Header Clips To The Table Width

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 滚动条归属第 8 条。

## Problem

只有表格自身横向滚动条的状态下，页面左右 Padding 可见，此时能看到表头的列画到了
Padding 上，看起来像"表头宽度和表格宽度不一致"。

表头的位置和宽度其实一直是对的，两条承载路径下都与表格滚动视图完全一致。真正的原因
是**表头不裁剪自己的内容**：表格横向滚动时，表头把列布局整体左移一个横向偏移量来跟随
表格，而表头视图从未开启图层裁剪，表格容器在新版外观下又明确关闭了裁剪，于是被移出去
的序号列和被推出右边的末列直接画到了页面左右 Padding 上。表体行不会这样，因为它们在
滚动视图的裁剪视图里面。

之前那次"表头下横线宽度不对"是同一个现象：横线一直是对的，越界的是表头的列内容。

## Change

`SubtitleVirtualTableHeaderView` 开启自身图层裁剪。列布局、横向偏移量、分隔线绘制都
没有改动。表格容器的裁剪设置保持不变——表头自己裁剪后问题即消失，改容器会影响选择
操作浮层与行内菜单的绘制范围。

关键文件：`Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`

## Verification

- `swift build`、`swift test`：失败项与改动前基线一致，没有新增失败。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 新增用例：表头与表格滚动
  视图的横向位置和宽度一致；表格存在横向溢出时表头开启了自身裁剪。
- Debug E2E：Shiori 二级页 `setWidth` 560，截图确认表头末列在表格右边界处被裁掉、
  表头列与表体列对齐，不再画到页面 Padding 上。

## Outcome

符合预期。表头 Hover、排序指示与表头文本选择待项目 Owner 在真机上确认没有被裁掉。
