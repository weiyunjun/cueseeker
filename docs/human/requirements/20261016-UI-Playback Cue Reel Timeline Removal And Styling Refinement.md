# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **移除非 Collage 界面的左侧点线时间轴（`C-13.4`、`L-08.4`、`L-08.5`、`L-09.3`）**：
   - 在 `L-08.4 Playback Current Layout`、`L-08.5 Playback Playlist Layout`（`Subtitle Playlist`）与 `L-09.3 Command Panel Search Results Layout` 中，移除左侧圆点（`Dot`）、连接线（`Connector`）及时间轴左侧占位间距，台词内容直接左对齐。
   - `L-08.6 Playback Collage Editor Layout` 保持现有左侧复选框（`Checkbox`）时间轴布局不变。

2. **放大 Metadata 字号并新建专属 Token（`C-13.1` & `UI Tokens.md`）**：
   - 新增字号 Token `--font-size-playback-cue-metadata: 14px`。
   - `C-13.1 Playback Cue Metadata` 的字号改用 `--font-size-playback-cue-metadata`（`14px`），其余行高、字重与间距保持不变。

3. **更新 Subtitle Focus 与 Metadata 配色（`UI Tokens.md` & `C-13.1` ~ `C-13.3`）**：
   - `--color-subtitle-focus-overlay-bg`：Light `#FAFBFD`；Dark `#18181B`。
   - `--color-subtitle-focus-cue-selected`：Light `#0F172A`；Dark `#FFFFFF`。
   - `--color-subtitle-focus-cue-group-selected`：Light `#334155`；Dark `rgba(255,255,255,0.68)`。
   - `--color-subtitle-focus-cue-unselected`：Light `rgba(15,23,42,0.26)`；Dark `rgba(255,255,255,0.26)`。
   - `C-13.1 Playback Cue Metadata` 文字颜色改为区分台词选中态与未选中态：
     - `--color-playback-cue-metadata-selected`：Light `rgba(15,23,42,0.56)`；Dark `rgba(255,255,255,0.56)`。
     - `--color-playback-cue-metadata-unselected`：Light `rgba(15,23,42,0.22)`；Dark `rgba(255,255,255,0.20)`。

4. **设计文档同步**：
   - 待实际 UI 效果验收完毕后，再将最终 Token 与组件布局变更同步更新至 `docs/human/design/ui/` 下对应文档。

# 验收标准

1. `Playback Current`、`Subtitle Playlist` 与 `Command Panel Search Results` 均不再显示左侧点线时间轴，台词与 Metadata 左边缘对齐；`Collage Editor` 右侧字幕流仍保留左侧复选框。
2. 台词下方 Metadata 字号为 `14px`，选中台词与未选中台词的 Metadata 分别按选中态与未选中态颜色渲染，未选中 Metadata 不再比未选中台词更亮或更深。
3. Light Mode 与 Dark Mode 下 Playback Overlay 背景色、选中主/副台词颜色、未选中台词颜色均符合新配色规格。