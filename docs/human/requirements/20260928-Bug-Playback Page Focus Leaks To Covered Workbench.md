# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级）
- `docs/human/design/UI Design System.md`（Playback Overlay、各组件的 Focused 状态）
- `docs/human/requirements/20260911-UI-Keyboard Focus Ignores System Setting And Has No Default Focus.md`

# 需求描述

## 1. 现状

播放界面（Playback Page）打开时，处于底层的 Workbench（工作台）仍可被键盘导航（如 Tab / Shift-Tab）或焦点回退机制选为 First Responder。导致搜索框意外获取光标，播放快捷键与手柄控制失效，输入字符被错误键入底层工作台搜索框中。

## 2. 界面层级隔离

1. **播放界面打开期间，底层 Workbench 必须完全隔离**：
   - 工作台及其所有子控件（包括搜索框、表格等）不得响应键盘焦点，不得成为 First Responder。
   - 键盘导航（Tab 与 Shift-Tab）在播放界面中仅在当前可见顶层控件间流转，严禁穿透到底层工作台。
   - 播放期间后台任务（如 Index、Add Folder、Remove Folder）执行完成并刷新数据时，不得将焦点唤醒或恢复至底层工作台。
2. **文本输入判定作用域**：
   - 仅当处于顶层可见界面（如 Command Panel、对话框）的输入框获得焦点时，才视为正在输入并暂停播放快捷键响应；被覆盖层级的游离焦点不得阻塞播放快捷键与手柄控制。

## 3. 保持不变

1. Tab 与 Shift-Tab 在 Playback Overlay 内切换 Current / Playlist / Collage 的行为保持不变。
2. Command Panel 内搜索框自动获得焦点的规则保持不变。
3. 对话框（Dialog）打开时的焦点与模态规则保持不变。

# 验收

1. 在工作台搜索框输入文字后，播放任一结果进入播放界面。
2. 在播放界面按 Tab 或 Shift-Tab，光标严禁落入底层工作台搜索框，所有播放快捷键（如 Space、A、D、P 等）与手柄控制正常可用。
3. 播放期间后台任务完成并写库，播放控制与快捷键保持正常，不发生焦点转移。
4. 退出播放界面，工作台搜索框内容与离开时保持一致，无残留快捷键字符。
5. 单元测试与集成测试全部通过，不新增自动化 E2E 能力，由人工验收。