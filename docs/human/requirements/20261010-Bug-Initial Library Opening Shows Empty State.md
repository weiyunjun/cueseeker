# 版本

main

# 关联设计

- docs/human/design/UI Design System.md
- docs/human/requirements/20261009-Feature-Workbench Invalidation.md

# 需求描述

1. **现状问题**：
   - App 启动后首次打开 Library（无论是直接以 Library 页启动，还是在其他页启动后切换到 Library），界面均错误显示“还没有媒体库视频。”（`No library videos yet.`），只有离开 Library 页面再次切回时才会展示内容。

2. **修复要求**：
   - 首次挂载或打开 Library 页面时，必须正常执行冷数据水合加载并正确渲染媒体库文件夹列表，严禁展示假空状态。
   - 维持数据库变更时的冻结（Hold）规则：仅在 Library 已经加载有实体数据且后台发生变更时维持冻结；未加载任何数据的初始状态严禁拦截加载。

# 验收标准

1. **直接启动验证**：以 Library 标签页启动 App，页面直接正常渲染媒体库文件夹列表，不再出现“还没有媒体库视频”。
2. **切换切入验证**：以其他标签页（如 File）启动 App，切换到 Library 标签页，页面直接正常渲染媒体库文件夹列表。
3. **冻结规则回归**：当 Library 已有数据呈现时，后台发生数据库增删变更，处于 Library 时界面保持冻结不跳变；切出再切回时正常刷新为最新数据。