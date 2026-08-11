# 版本

main

# 需求描述

扩展现有 CueSeeker Debug E2E 控制器，增加应用内键盘事件命令，使端到端测试能够触发必须通过快捷键进入或操作的界面。

当前从外部模拟键盘输入可能被 macOS 拦截。正确方案是在 CueSeeker Debug App 内部生成键盘事件，并通过正常 AppKit 事件流程发送。

本需求不得通过申请 Accessibility、Input Monitoring 等系统权限解决，也不得增加直接打开 Cue Reel、直接切换界面或直接调用业务方法的测试后门。

# 需求目标

1. Debug E2E 控制器支持按需发送一次键盘按键。
2. 支持普通按键以及 Command、Option、Control、Shift、Function 等组合键。
3. 键盘事件发送给当前 CueSeeker Key Window 和当前 First Responder。
4. 快捷键必须经过与真实键盘输入一致的 AppKit 事件处理流程。
5. 支持通过快捷键触发 Cue Reel 等现有界面行为。
6. 不移动真实鼠标，不生成系统级全局键盘事件，不依赖系统辅助权限。
7. 该能力只存在于显式启用的 Debug E2E 流程中。

# 应用内键盘事件

Debug E2E 控制器新增键盘事件命令。

命令参数至少包括：

1. `key`：需要模拟的按键。
2. `modifiers`：需要同时按下的修饰键；没有修饰键时为空。
3. `sceneID`：当前完整界面状态标识。

`key` 应支持端到端测试需要使用的已知按键，包括：

1. 字母键。
2. 数字键。
3. Enter。
4. Escape。
5. Tab。
6. Space。
7. 方向键。

单次命令只表示一次非重复按键，不包含长按和自动重复。

# 事件处理要求

1. 控制器必须生成对应的 AppKit `keyDown` 和 `keyUp` 事件。
2. 事件必须包含与目标按键一致的 Key Code、字符信息和修饰键状态。
3. `keyDown` 和 `keyUp` 必须按照正常顺序发送到 AppKit 事件队列。
4. 事件必须由当前 CueSeeker Key Window 和 First Responder 按正常路径处理。
5. App 内现有的快捷键监听、菜单快捷键、SwiftUI 键盘处理和 AppKit Responder Chain 应能够收到事件。
6. 控制器不得直接调用快捷键最终对应的业务方法。
7. 控制器不得直接修改路由、播放状态、选择状态或界面状态。
8. 控制器不得增加“打开 Cue Reel”“切换模块”等业务语义命令。
9. 键盘事件处理完成后，应返回新的完整界面信息和 `sceneID`。

# 状态与错误处理

以下情况必须明确失败，不得静默忽略：

1. `sceneID` 已过期。
2. CueSeeker 当前没有可接收事件的 Key Window。
3. CueSeeker 当前不处于能够接收应用内键盘事件的状态。
4. `key` 不受支持。
5. `modifiers` 包含不受支持的值。
6. 无法创建 `keyDown` 或 `keyUp` 事件。
7. 事件发送过程中完整界面状态已经失效。

失败时不得：

1. 改用系统级 `CGEvent` 注入。
2. 请求 Accessibility 或 Input Monitoring 权限。
3. 调用外部键盘自动化工具。
4. 直接执行快捷键对应的业务操作。

# 测试原则

1. 测试流程必须预先声明按键、修饰键和界面状态前提。
2. 每次键盘事件必须使用当前有效的 `sceneID`。
3. 快捷键执行结果应通过真实 Debug E2E 截图、界面状态或对应日志验证。
4. 截图只用于验证快捷键结果，不用于识别当前应发送什么按键。
5. 测试不得根据截图临时选择其他快捷键或调用业务后门。
6. 键盘事件命令不能代替文本输入功能；本需求只处理单次按键和快捷键。

# Debug 与 Release 隔离

1. 键盘事件命令只在 `--cueseeker-debug-e2e` 显式启用时可用。
2. 普通 Debug 启动不得读取或发送测试键盘事件。
3. Release App 不得包含或启用该键盘事件控制流程。
4. 现有产品快捷键实现不得为了测试增加特殊分支。

# 验收标准

1. Debug E2E 控制器能够发送无修饰键的单次按键。
2. Debug E2E 控制器能够发送带修饰键的快捷键。
3. Enter、Escape、Tab、Space、方向键和测试所需字母键能够正常工作。
4. 键盘事件由当前 Key Window 和 First Responder 接收。
5. 快捷键经过现有 AppKit、SwiftUI、菜单或 Responder Chain 处理流程。
6. 需要快捷键触发的 Cue Reel 可以通过其现有快捷键正常打开。
7. Cue Reel 的打开过程不依赖直接路由、直接方法调用或测试专用业务入口。
8. 快捷键执行后的真实界面可以通过现有 Debug E2E 截图功能捕获。
9. 成功执行后返回新的完整界面信息和 `sceneID`。
10. 使用旧 `sceneID` 发送键盘事件时明确失败。
11. 不支持的按键或修饰键明确失败。
12. Key Window 不可用时明确失败。
13. 不申请 Accessibility 或 Input Monitoring 权限。
14. 不使用系统级全局键盘事件或外部自动化工具。
15. 不移动真实鼠标，不影响其他应用。
16. 不直接调用快捷键对应的业务方法或修改业务状态。
17. 普通 Debug 启动不主动执行键盘事件流程。
18. Release App 不包含或启用该 Debug 键盘事件功能。