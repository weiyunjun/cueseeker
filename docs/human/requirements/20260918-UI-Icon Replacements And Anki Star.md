# 版本

main

# 关联设计

- `docs/human/design/Icon Registry.md`（制作规格、尺寸与线宽、图标名录）
- `docs/human/design/UI Design System.md`（各位置的图标尺寸与颜色 token）

# 需求描述

1. 本次只更换图形与新增一个自制图标，不改变任何位置的尺寸、颜色 token、状态与交互。
2. 摘录（Excerpt）语义由 `bookmark-simple` 改为 `heart`，其全部使用位置一并更换，并新增 Fill 变体用于「已存入」。
3. 截图由 `image` 改为 `camera`，播放控制条的截图按钮与播放反馈「截图已复制」一并更换。更换后 `image` 不再被任何位置使用。
4. Playback Overlay 的 Collage 由 `note-pencil` 改为 `images-square`。更换后 `note-pencil` 只用于 Excerpt List 卡片菜单 / Edit List，其含义相应改为「编辑」。
5. Workbench 的 Select 由 `note-pencil` 改为 `list-checks`，Search 与 Excerpt 工具栏共用同一个按钮。
6. Task 入口由 `list-checks` 改为 `tray`。任务界面是后台作业队列，托盘与其剩余数量徽标相符。
7. 新增自制图标 `anki-star`：取 Anki 标识的五角星，实心，逆时针倾斜 18 度使顶角偏左；只保留星形，不含文档底与外层白色描边，颜色随界面。绘制方式为实心填充加同色描边，沿用制作规格的 256×256 画布、描边 16、圆线端与圆拐角，线宽随显示尺寸取值。
8. `anki-star` 本次不投入使用，在图标名录中记为预留。

# 图标映射

| 位置 | 现用 | 改为 |
| --- | --- | --- |
| Excerpt 的全部使用位置 | `bookmark-simple`（含 Fill） | `heart`（含 Fill） |
| 播放控制条 / 截图；Playback Feedback（截图已复制） | `image` | `camera` |
| Playback Overlay / Collage | `note-pencil` | `images-square` |
| Search / Excerpt Toolbar / Select Mode Action | `note-pencil` | `list-checks` |
| Task Entry | `list-checks` | `tray` |
| 预留，暂无使用位置 | 无 | `anki-star`（自制，实心） |

# 验收

1. 上表各位置显示为新图形，尺寸与颜色与更换前一致。
2. 明暗外观下着色正确，各尺寸边缘清晰，同屏图标线宽观感一致。
3. Excerpt 封面占位为 57px 大图，心形的视觉重量由所有者实看确认。
4. `anki-star` 在名录各尺寸下可正常绘制，实心与圆拐角符合制作规格。
5. 视觉人工验收，逐个图标由所有者确认后回填设计文档。不为本需求新增 E2E 能力。