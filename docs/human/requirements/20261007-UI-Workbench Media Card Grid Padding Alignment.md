# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 新增设计 Token
1. **基础间距**：新增 `--spacing-5`: `20px`。
2. **卡片容器边距**：新增 `--padding-workbench-media-card-grid-inline`，Leading 为 `--spacing-5`（20px），Trailing 为 `--spacing-5` + `--width-page-scrollbar-channel`（36px）。

## 2. 封面卡片网格与上级容器对齐
由于封面卡片内置 12px 的 Hover 内边距，导致未 Hover 时封面图向内缩进。需区分上级容器左右边距以实现对齐：
1. **容器边距分离**：
   - 不包含封面卡片的容器（如排序栏、Summary 行、顶部大图）保持标准页面边距（Leading 32px, Trailing 48px）。
   - 包含封面卡片的容器使用 `--padding-workbench-media-card-grid-inline`（Leading 20px, Trailing 36px）。
2. **涉及界面**：
   - **Library 一级界面**：文件夹卡片网格（未 hover 时末列封面图右边缘与右上角排序按钮右边缘对齐）。
   - **Library 二级界面**：剧集卡片网格（未 hover 时封面图左右边缘与顶部大图齐平）。
   - **Excerpt 一级界面**：列表卡片网格（未 hover 时首列与上方 Summary 文本对齐，末列与 New List 按钮对齐）。
   - **Recent 界面**：Recent Videos 与 Recent Excerpt Lists 的卡片网格。
   - *(注：Excerpt 二级界面保持原有标准边距，不作调整)*。

# 验收标准

1. **Library 一级**：未 hover 时，最右侧封面图的右侧与右上角排序按钮的右侧垂直对齐。
2. **Library 二级**：未 hover 时，剧集卡片封面图的左右边缘与顶部大图的左右边缘视觉齐平。
3. **Excerpt 一级**：未 hover 时，首列封面与 Summary 文本对齐，末列封面与 New List 按钮右侧对齐。
4. **Recent 界面**：未 hover 时，卡片封面图左右边缘对齐到标准 32px / 48px 视觉线。
5. **交互一致性**：卡片在 hover 时背景向外延伸 12px，不产生裁剪或容器错位。