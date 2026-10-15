# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`
- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/Data.md`
- `docs/human/design/Cue Parsing.md`
- `docs/human/design/Playback Edge Cases.md`
- `docs/human/design/Command Panel.md`
- `docs/human/design/Controller.md`

# 需求描述

1. **移除废弃文档与历史资源目录**：
   - 移除 `/docs/assets`、`/docs/chronicle`、`/docs/decisions`、`/docs/product`、`/docs/proposals`。
   - 移除 `/docs/human/design/archive`、`/docs/human/design/assets`。
   - 同步清理 `docs/engineering/` 下对上述已移除目录的引用规则。

2. **重构 `/docs/human/design/` 目录结构**：
   - 顶层新增全局索引 `Design Index.md`，下设 `ui/`、`data/`、`workbench/`、`playback/` 四个业务域文件夹。
   - 迁移既有文档：`Data.md` 与 `Cue Parsing.md` 迁入 `data/`；`Playback Edge Cases.md`、`Command Panel.md` 与 `Controller.md` 迁入 `playback/`；`Icon Registry.md` 与 `Toast Usage Registry.md` 迁入 `ui/`。
   - 规划并逐步补齐业务设计文档：`workbench/` 下补充 `Search and Filter.md`、`Library and File.md`、`Excerpt and Export.md`、`Settings and Localization.md`；`playback/` 下补充 `Playback Core.md` 并扩充 `Command Panel.md`。

3. **UI 设计文档卡片盒拆分与编号化（`docs/human/design/ui/`）**：
   - 新增 `UI Index.md`：定义各 UI 文档职责边界，建立组件（`C-xx`）与布局（`L-xx`）唯一编号索引表及按需检索规则。
   - 新增 `UI Design Rules.md`：提炼全局通用视觉与度量约束（全局无按下视觉效果、选中态组件白名单、基于 Cap 顶与可见边界的等距计算基准、Light/Dark 明暗表面层级与布局边距规则）。
   - 演进 `UI Interaction Rules.md`（原 `UI Application Rules.md`）：收敛界面层级屏蔽、菜单模态、Player UI 与指针显隐、鼠标指针形状优先级、焦点与快捷键规则，并预留无障碍交互章节。
   - 拆分原 `UI Design System.md` 为 `UI Tokens.md`、`UI Components - Controls.md`、`UI Components - Domain.md`、`UI Layouts - Workbench.md`、`UI Layouts - Playback.md`，为所有组件（含提拔为独立组件的 Breadcrumb）和布局分配唯一编号。

# 验收标准

1. 上述废弃目录全部移除，`/docs` 顶层仅保留 `human/`、`engineering/` 与 `changelog.md`，且 `docs/engineering/` 中无悬空目录引用。
2. `/docs/human/design/` 完成四域目录与索引重组，原 `UI Design System.md` 与 `UI Application Rules.md` 完成模块化拆分与编号化，内容无遗漏。