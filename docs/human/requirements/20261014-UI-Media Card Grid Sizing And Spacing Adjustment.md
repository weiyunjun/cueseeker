# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 封面图卡片尺寸与间距调整
1. **间距减少 8px 并固定**：封面图卡片网格的左右列间距与上下行间距统一减少 `8px`（由 `16px` 调整为 `8px`），且保持固定不变。
2. **卡片最小宽度改为 300px**：封面图卡片最小宽度由 `180px` 调整为 `300px`，保证窗口最小宽度下每行仅显示 1 张卡片，并让单张卡片展示更多文字。
3. **随窗口缩放卡片宽高**：移除封面图卡片的最大宽度限制（原 `220px`）。当窗口尺寸变化时，左右与上下卡片间距固定不变，按列等分缩放封面图卡片的宽度，卡片封面高度按 `16 / 9` 比例同步缩放。

## 2. 涉及界面
1. **Recent 界面**：Recent Videos、Recent Excerpt Lists。
2. **Library 界面**：一级文件夹网格界面、二级剧集网格界面。
3. **Excerpt 界面**：一级摘录集网格界面。
4. **Playback Overlay 界面**：Playlist（Video Playlist）剧集网格界面。
5. **Command Panel 界面**：Recent Videos、Recent Excerpt Lists 二级网格界面。

# 验收标准

1. 上述全部界面中，封面图卡片的左右与上下网格间距均固定为 `8px`。
2. 封面图卡片最小宽度为 `300px`，在窗口最小宽度下每行仅显示 1 张卡片。
3. 缩放窗口时，卡片之间的左右与上下间距保持不变，卡片宽度与高度随窗口尺寸自适应缩放。