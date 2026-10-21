# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **分离 `Hover` 与 `Select` 状态及适用范围**：
   - **`Hover` 实时判定（全界面统一）**：当鼠标箭头未处于隐藏状态，且当前界面未被已打开的菜单或上层弹窗冻结时，所有界面均根据鼠标当前所在位置实时判断和更新 `Hover` 效果（包括界面刚打开或切换时、关闭菜单解冻后、以及从其他应用切回主窗口时）。
   - **`Select` 适用范围**：仅 **Playback 界面的封面卡片**（Playback Overlay 视频 Playlist、Command Panel 的 `Recent Videos` 与 `Recent Excerpt Lists`）、**所有弹出菜单的菜单项**、以及 **Command Panel 首页菜单项** 拥有 `Select` 状态。Workbench 界面的封面卡片与表格无 `Select` 状态；Playback 字幕流（Reel）维持现有定焦滚动表现不变。
   - **视觉叠加优先级**：`Hover` 与 `Select` 视觉效果不叠加；当同一条目同时处于 `Hover` 与 `Select` 时，仅显示 `Select` 样式。

2. **新增 `Select` 视觉样式**：
   - **封面卡片**：保留现有高亮底色作为 `Hover` 样式，在 `Hover` 基础上将背景色加深一档作为 `Select` 样式；处于 `Hover` 或 `Select` 时封面图均保持 `1.02` 倍放大。
   - **菜单项（含普通菜单、Command Panel 首页菜单项、播放页深色菜单、危险删除菜单项）**：保留现有高亮底色作为 `Hover` 样式，在 `Hover` 基础上将背景色加深一档作为 `Select` 样式。

3. **默认 `Select` 与键盘/手柄导航滚动规则**：
   - **默认 `Select`**：Playback 封面卡片与弹出菜单项沿用现有默认选中规则；Command Panel 首页菜单项默认选中第 1 项。
   - **导航与自动滚动**：所有支持 `Select` 的区域均支持键盘方向键、手柄十字键与左摇杆导航（鼠标移动与右键点击不改变 `Select`）。仅当 `Select` 导航后目标内容显示不全时，自动滚动界面以完整显示该内容（超长极端内容尽量多显示）；鼠标 `Hover` 绝不触发界面自动滚动。

4. **滚轮滚动防抖（`300ms`）与右键菜单解冻重判**：
   - **滚轮防抖**：滚轮或触控板滚动期间保持滚动前的 `Hover` 与指针样式不变；自最后一次滚动事件起静止满 `300ms` 后（若期间鼠标发生移动则立即响应），按鼠标当前位置重新判断并更新 `Hover` 与指针样式。
   - **右键菜单与解冻流程**：右键点击仅打开菜单并冻结当前画面的 `Hover` 状态，不改变 `Select`，也不在表格 Cues 列非文字空白区域右键时强行绘制台词下划线。左键点击菜单外任意位置关闭菜单后，解除冻结并立即按当前鼠标位置重新判断 `Hover`；菜单打开期间直接右键点击其他目标时，按「关闭旧菜单 $\rightarrow$ 解除冻结 $\rightarrow$ 按当前鼠标位置更新 `Hover` $\rightarrow$ 弹出新菜单并冻结」的顺序执行。

5. **播放页浮层指针显隐与指针样式简化**：
   - **浮层打开不主动唤醒指针**：打开 Playback Overlay 或 Command Panel 时，不再主动显示已隐藏的鼠标箭头（指针隐藏期间不产生任何 `Hover` 效果，直至移动鼠标唤醒指针）。
   - **指针样式跟随 `Hover` 同步更新**：移除界面切换与键盘导航时强制将指针重置为默认箭头的规则；鼠标指针样式（默认箭头、封面卡片与表格可点击台词文字的 `Grab` 手型、非 `Grab` 可拖选文字与输入框的 `I-beam`）直接随当前最上层可交互界面的 `Hover` 判定同步更新。

# 验收标准

1. **视觉与叠加表现**：封面卡片与各类菜单项的 `Hover`（浅底）与 `Select`（深底）样式区分清晰；当鼠标悬停在已处于 `Select` 的卡片或菜单项上时，只显示 `Select` 样式，不发生颜色叠加。
2. **右键菜单与解冻重判**：
   - 在 Workbench 或 Playback 界面右键点击封面卡片弹出菜单后，左键点击菜单外空白区域，菜单关闭且原卡片的 `Hover` 立即消失（Playback 界面的 `Select` 仍保持在原选中卡片上）；菜单打开期间直接右键点击另一张封面卡片，旧卡片 `Hover` 消失、新卡片获得 `Hover` 并弹出新菜单。
   - 在表格 Cues 列非文字空白区域右键弹出菜单时，仅保持该行背景 `Hover`，台词文字不出现下划线。
3. **Command Panel 唤出与滚轮/方向键配合**：
   - 在视频播放页将鼠标停在即将出现 `Recent Excerpt Lists` 的位置并唤出 Command Panel：若此时鼠标可见，则 `Recent Videos` 为 `Select`（深底）、`Recent Excerpt Lists` 为 `Hover`（浅底）；若此时鼠标已隐藏，则打开后鼠标保持隐藏，仅 `Recent Videos` 为 `Select`（深底），无 `Hover` 效果。
   - 在 Command Panel 的 `Recent Videos` 中，鼠标悬停到显示不全的边缘封面卡片时页面不会自动滚动；使用滚轮滚到底部停稳满 `300ms` 后，指针下的卡片显示 `Hover`（浅底）且指针变为 `Grab` 手型，此时按键盘方向键仍从原 `Select` 卡片导航到下一张卡片并自动滚动使新 `Select` 卡片完整显示。
4. **应用切换与指针同步**：在 Workbench 表格悬停某行后切换到其他应用、将鼠标移出表格再切回 CueSeeker，原表格行的 `Hover` 立即清除；切换进入新界面、关闭菜单或按方向键移动 `Select` 时，只要鼠标可见且位于封面卡片或表格台词文字上，卡片/文字正常保持 `Hover` 且鼠标指针正常显示为 `Grab` 手型。