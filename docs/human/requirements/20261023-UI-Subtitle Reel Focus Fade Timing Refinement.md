# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **Subtitle Focus Motion 焦点淡入淡出与防抖时长 Tokens 调整**：
   - 修改 `--duration-subtitle-focus-fade-out`：由 `0.26s` 调整为 `0.30s`（开始导航时原聚焦字幕褪为未选中颜色的淡出时长）。
   - 修改 `--delay-subtitle-focus-fade-in`：由 `0.18s` 调整为 `0.10s`（导航防抖等待阈值）。
   - 修改 `--duration-subtitle-focus-fade-in`：由 `0.22s` 调整为 `0.30s`（停止导航满防抖阈值后，目标聚焦字幕过渡为选中颜色的淡入时长，与 `0.10s` 防抖等待合计 `0.40s`，同单步滚动同步收尾）。
   - 保持 `--duration-subtitle-focus-scroll`（`0.40s`）、`--easing-subtitle-focus-scroll`（`cubic-bezier(0.22, 1, 0.36, 1)`）与 `--easing-subtitle-focus-fade`（`cubic-bezier(0.37, 0, 0.63, 1)`）不变。

# 验收标准

1. 在字幕流中单步导航时，原焦点字幕在 `0.30s` 内平滑淡出为暗色，目标字幕在 `0.10s` 防抖后启动 `0.30s` 淡入，在 `0.40s` 滚动落位的同时完成亮起。
2. 连续导航（操作间隔小于 `0.10s`）期间途经字幕保持未选中暗色不闪烁；停止操作满 `0.10s` 后，当前中心字幕在 `0.30s` 内平滑淡入变亮。