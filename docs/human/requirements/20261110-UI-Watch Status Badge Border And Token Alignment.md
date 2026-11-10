# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **新增观看状态徽章常驻边框颜色 Tokens（`UI Tokens.md`）**：
   - 在 `1.1 颜色 -> Status` 下新增 3 个观看状态边框色 Token：
     - `--color-watch-status-unwatched-border`：Light `#D0D5DD`；Dark `#3F3F46`
     - `--color-watch-status-watching-border`：Light `#93C5FD`；Dark `#2563EB`
     - `--color-watch-status-finished-border`：Light `#6EE7B7`；Dark `#059669`

2. **`C-08.1 Watch Status Badge` 常驻边框与规范 Token 对齐（`UI Components - Domain.md`）**：
   - 容器（`Container`）常驻显示 `--border-width-control`（`1px`）边框，圆角使用 `--radius-chip`（`6px`），内边距使用 `--padding-chip-x`（`10px`）与 `--padding-chip-y`（`4px`），文本字号使用 `--font-size-caption`（`12px`）、字重使用 `--font-weight-control`（`500`）。
   - 各状态（`States`）边框颜色分别绑定至对应 Token：
     - `Unwatched`：`--color-watch-status-unwatched-border`
     - `Watching`：`--color-watch-status-watching-border`
     - `Finished`：`--color-watch-status-finished-border`（含远程目录浏览中复用 `Watch Status Badge` `Finished` 样式的 `Added` 标签）
     - `Disabled`：`--color-border-disabled`

# 验收标准

1. 所有展示观看状态徽章的位置（含 `Recent`、`Library` 二级详情页、`Playback Overlay -> Video Playlist`、`Command Panel -> Recent Videos` 以及远程目录浏览已添加文件夹的 `Added` 标签）中，徽章均常驻显示 `1px` 对应状态边框，且圆角、内边距、字号与字重严格对齐文档 Token。
2. 在 Light Mode 与 Dark Mode 下，当视频卡片处于 `Selected` 或 `Hover` 状态且卡片底色与徽章底色相近时，徽章通过常驻边框保持清晰轮廓，不发生融底重合。