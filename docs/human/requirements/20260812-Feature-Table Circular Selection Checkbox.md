# 版本
main

# 设计依据
`docs/human/design/UI Design System.md` 的 `2.2 Selection Controls`

# 问题描述
Filter Checkbox、Table Selection Checkbox 和 Playback Selection Checkbox 属于同一个 Checkbox Component，但当前相同状态使用了不同颜色。

# 需求描述
1. 所有 Checkbox Variant 必须继承 Checkbox Shared States 的颜色规则，不得自行使用其他颜色 Token。
2. 当前统一范围包括：
   - Filter Checkbox
   - Table 表头和各行的 Selection Checkbox
   - Playback Selection Checkbox
3. Unchecked 使用：
   - Background：`--color-bg-checkbox-unchecked`
   - Border：`--color-border-checkbox`
4. Checked 使用：
   - Background：`--color-bg-checkbox-checked`
   - Indicator：`--color-checkbox-icon`
5. Indeterminate 使用 Checked Background 和 Indicator 颜色。
6. Disabled 使用 Shared Disabled 状态定义的颜色。
7. `--color-text-muted` 不再作为 Checked Checkbox 的背景或 Control 颜色。
8. 相同状态的颜色必须由同一共享规则维护；除非设计文档明确增加 Variant Override，否则不允许界面自行覆盖。
9. Table Selection Checkbox 由圆角方形改为圆形。

# 不变范围
1. Filter 和 Table Checkbox 继续使用 `--size-checkbox`。
2. Playback Checkbox 继续使用 `--size-playback-collage-checkbox`。
3. 点击范围、Hover、Focus Ring、键盘操作、选择逻辑和 Disabled 条件保持现状。
4. Filter Calculating 状态继续保持原有 Checked 或 Unchecked 视觉。
5. Playback 焦点状态与 Checkbox 状态继续相互独立。

# 验收标准
1. Light 和 Dark Appearance 下，三个 Checkbox Variant 的相同状态使用完全一致的颜色 Token。
2. Table 表头、Table 行、Filter 和 Playback 的 Checked、Unchecked、Indeterminate（适用时）及 Disabled 状态均符合 Shared States。
3. Variant 之间只保留设计文档明确规定的尺寸和交互差异。
4. 自动化测试直接验证三个 Variant 使用同一组 Shared Checkbox 颜色，而不是仅验证两个界面彼此相同。
5. 现有选择、点击范围和键盘交互测试全部通过。