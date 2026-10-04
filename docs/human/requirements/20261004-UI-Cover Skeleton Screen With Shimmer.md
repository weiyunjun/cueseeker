# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 封面图骨架屏与微光动效（Cover Skeleton Screen with Shimmer）
1. **替代静态占位**：
   - 彻底移除封面图在加载/排队期间原本死板的静态灰色底块与居中小图标（`libraryCoverPlaceholderBg + AppIconImage`）。
   - 替换为带微光扫光动画（Shimmer）的圆角骨架屏，高光带自左向右循环平移动画，色彩在 Light/Dark 模式下与所在表面层级相协调。
2. **渐进式平滑过渡**：
   - 图片解码完成后，骨架平滑淡出，真实封面以淡入动画（Crossfade，约 0.2s Ease-out）呈现，杜绝突兀闪现与切图生硬感。
3. **覆盖范围**：
   - 所有包含封面图的区域：
     - Recent 界面（Recent Videos 与 Recent Excerpt Lists 卡片封面）。
     - Library 一级界面（Folder 卡片封面）与二级界面（Video 剧集卡片封面）。
     - Excerpt 一级界面（Excerpt List 封面卡片）。
     - Excerpt 二级界面顶部大封面（`CoverSummaryCard`）。
     - Playback Overlay 界面（Playlist 视频封面）。
     - Command Panel 界面（Recent Videos 与 Recent Excerpt Lists 封面）。

## 2. 防闪烁机制（Anti-Flicker Rule）
1. **即时就绪直接渲染**：
   - 若封面图已在内存缓存中，或在延迟感知阈值（约 100ms ~ 120ms）内即完成读取解码，直接渲染真实图片，**不触发骨架屏**，防止在极快场景下骨架屏一闪而过产生视觉频闪（Flicker）。
2. **超时平滑进入骨架态**：
   - 超过阈值尚未就绪的封面（如快速双击顶栏最大化导致大量新卡片瞬时涌入排队），无缝进入微光骨架态，直到自身解码完成并平滑淡入。

# 验收标准

1. **窗口缩放与重排表现**：
   - 双击顶栏最大化窗口或快速拉伸窗口宽度时，新涌入视口的卡片封面优雅展示微光骨架流动，随后依序平滑淡入真实封面，不再出现灰色死板小图标。
2. **防闪烁验证**：
   - 正常浏览、页面回退或图片已在缓存中的卡片，切换时直接展示内容，无骨架屏闪烁。
3. **视觉一致性**：
   - Recent、Library、Excerpt、Playback Overlay 与 Command Panel 的所有封面骨架尺寸、圆角与扫光动效完全统一并自适应深浅色模式。