# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`

# 需求目标

统一 Workbench 八个界面的顶栏、页面标题、页面边界和视觉层级。

# 界面范围

一级界面：

- Search
- Recent
- Library
- Shiori

二级界面：

- Recent Videos
- Recent Shioris
- Library Folder Detail
- Shiori List Detail

# 顶栏

1. Sidebar 区域及 Sidebar Toggle 保持不变。
2. 非 Sidebar 顶栏改为所有 Workbench 界面共用的功能区。
3. 当前版本功能区只显示一个 Back 按钮，不显示页面标题或其他内容。
4. 一级界面的 Back 按钮 Disabled。
5. 二级界面的 Back 按钮 Enabled，返回对应一级界面。

# 页面标题

1. 以下界面在顶栏下方显示统一的页面标题：
   - Search
   - Recent
   - Library
   - Shiori
   - Recent Videos
   - Recent Shioris
2. 页面标题统一使用 `28px / Bold / Text Primary`。
3. Recent Videos 和 Recent Shioris 的页面标题右侧显示数量，数量使用 `18px / Regular / Text Secondary / Monospaced Digit`。
4. Library Folder Detail 和 Shiori List Detail 不增加页面标题，由 Cover Summary Card 显示当前内容标题。
5. Cover Summary Card 标题维持 `28px / Bold / White`。
6. Recent 一级界面内部的 Recent Videos、Recent Shioris 区块标题和计数维持当前样式和交互；计数保持 `14px / Regular / Text Secondary`。

# 页面间距

1. Search、Recent、Library、Shiori、Recent Videos 和 Recent Shioris 使用一致的页面内容边界。
2. 页面水平 Padding 使用 `--spacing-8 = 32px`；标题、Summary、操作区和 Grid/List 使用相同边界，标题视觉左边界与 Back 图标左边界对齐。
3. 页面顶部 Padding 使用 `--spacing-1 = 4px`，底部 Padding 保持 `--spacing-6 = 24px`。
4. Library Folder Detail 和 Shiori List Detail 的顶部 Padding 同样使用 `--spacing-1 = 4px`，相对原布局上移 `20px`。
5. 新增或调整的视觉值必须由共享设计 Token 表达，禁止页面私有硬编码。

# 设计记录

视觉验收完成后，由项目 Owner 将最终规则更新至 `UI Design System.md`。

# 验收标准

1. 八个界面的顶栏结构一致，非 Sidebar 区域不再显示标题。
2. Back 按钮的启用状态和返回目标正确。
3. 六个页面标题的字号、字重和颜色一致。
4. 六个页面的水平 Padding 均为 `32px`，标题与 Back 图标视觉左对齐，页面内容左右边界一致。
5. 六个页面的顶部 Padding 均为 `4px`，不存在过大的顶栏下方留白。
6. Recent Videos 和 Recent Shioris 的页面计数为 `18px`；Recent 一级界面内部区块标题和 `14px` 计数维持原样。
7. Library 和 Shiori 二级界面不存在重复标题，顶部留白减少 `20px`。
8. Light Mode、Dark Mode 及 Sidebar 展开、收起状态下布局正确。
