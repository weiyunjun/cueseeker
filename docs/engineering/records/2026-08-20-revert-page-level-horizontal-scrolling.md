# Revert Page-Level Horizontal Scrolling For Tables

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`

## Why

需求方向调整为两级横向滚动：页面级只负责页面内容溢出，表格列宽溢出重新交回表格
自己的横向 Scrollbar。原先「页面内容被表格列最小宽度顶住、整页一起横向滚动、页面
内边距跟着内容走」的三次提交与新方向冲突，全部撤回：

- `b086f214` 页面内容随组件最小宽度停止缩减（Chrome 被表格宽度顶住）
- `255cb5a9` Search Chrome 裁剪边界对齐表格视口
- `c08f5caf` 页面内边距移进表格滚动内容

撤回后回到 `77579a73`（Scrollbar 归页面）与 `baec9792`（不含表格页面的内容宽度下限）
的状态，作为新方向的起点。

## Also fixed

不含表格的页面加横向轴后，SwiftUI 双轴 ScrollView 会把比视口矮的内容在垂直方向
居中，Shiori 概览因此整块下沉。补上按视口高度的最小高度并顶部对齐，与
`Data/DataView.swift` 既有写法一致。

## Verification

- `swift build`、`swift test`：失败项与撤回前基线一致，没有新增失败。
- 撤回过程中 `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 的冲突按
  `77579a73` 版本解决。

## Outcome

符合预期。两级横向滚动的实现见后续记录。
