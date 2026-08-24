# 版本

main

# 关联设计

- `docs/human/design/Controller.md`

# 需求目标

将打开 Command Panel 的键盘快捷键从反引号键改为 K 键，使 Debug E2E 的 keyPress 能直接覆盖 Command Panel 流程。

# 需求

1. Playback Page 或 Playback Overlay 活跃、且焦点不在可编辑文本控件时，按 K 键打开 Command Panel。
2. 反引号键不再打开 Command Panel。
3. 手柄 Options 键改为对应 K 键，与 `docs/human/design/Controller.md` 一致。
4. 焦点在可编辑文本控件（含 Command Panel 搜索框）时，K 键按普通字符输入处理，不触发打开。
5. Command Panel 的关闭方式、页面切换、搜索行为、预填规则均不改变。
6. 更新受影响的自动化测试改用 K 键，并补充 Debug E2E 通过 keyPress 打开 Command Panel 的覆盖。

# 范围

1. 仅修改 Command Panel 的打开按键及对应手柄映射。
2. 不修改 Command Panel 内部功能、其他快捷键、其他界面的按键行为。

# 验收标准

1. 视频播放界面和 Playback Overlay 按 K 键可打开 Command Panel。
2. 按反引号键不再打开 Command Panel。
3. Command Panel 搜索框内输入 k 正常显示为文字。
4. 手柄 Options 键可打开 Command Panel。
5. Debug E2E 通过 keyPress "k" 可进入 Command Panel 并继续后续步骤。