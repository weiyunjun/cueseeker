# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 顶栏标题与异常路由展示
1. **Library 二级界面**：顶栏始终显示标题 `Library`。
2. **Excerpt 二级界面**：顶栏始终显示标题 `Excerpt`。
3. **失效路由表现**：当访问的 Library 文件夹或 Excerpt 摘录集已被删除/失效时，顶栏标题依然保持对应的 `Library` 或 `Excerpt`，不再展示 `Unknown Page`；页面内容区分别展示具体缺失提示：
   - Library 二级界面提示：`此文件夹不在媒体库中。`（`This folder is not in the library.`）
   - Excerpt 二级界面提示：`此摘录集已不存在。`（`This excerpt list no longer exists.`）

## 2. Recent 界面标签居中
1. 顶部分类切换标签（`Recent Videos` / `Recent Excerpt Lists`）水平居中显示，与 Playback Overlay 及 Task 界面的 Tab 居中视觉保持一致。
2. 下方的卡片网格依然保持原有的网格自适应流式排版。

## 3. Library 一级界面纯卡片化
1. 移除顶部的 Summary 行（包含 `xx Folders · yy Videos · zz Subtitles` 统计文本与 `Add Folder` 按钮）。
2. 移除 `Video / Metadata` 标签切换栏。
3. Library 一级界面滚动区域内仅保留展示视频文件夹卡片网格。

## 4. Library 二级界面移除 Metadata
1. 移除 `Video / Metadata` 标签切换栏及元数据视图。
2. Cover Summary 封面信息卡片下方直接连接剧集卡片网格，两者垂直间距遵循设计规范标准的 24px（`--gap-cover-summary-to-toolbar`）。

## 5. Metadata 文件树 UI 代码清理
1. 彻底删除废弃的 `LibraryFileTree.swift`。
2. 清理 `WorkbenchTestLibraryView.swift` 中关于元数据标签、文件树渲染及 `LibraryContentSegment` 分支代码。
3. 确保 File 页面（`WorkbenchFileView`）依赖的底层数据源不被破坏。

# 验收

1. **顶栏标题与容错**：进入 Library 和 Excerpt 二级界面，顶栏均正确显示对应标题；手动测试已删除的文件夹或摘录集历史路由时，顶栏依然保留业务标题，内容区准确展示“不在媒体库中”或“已不存在”的提示信息。
2. **Recent 标签居中**：Recent 界面顶部的 `Recent Videos` 与 `Recent Excerpt Lists` 处于水平正中位置，切换正常，下方卡片列表显示及交互正常。
3. **Library 界面精简**：Library 一级界面无统计行、无 Add Folder 按钮、无标签栏，首屏直接展示视频文件夹网格；二级界面无标签栏，Cover Summary 下方直接展示剧集卡片。
4. **代码无冗余**：成功删除 `LibraryFileTree.swift`，工程通过单元测试与编译。