# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Settings Category Layout、Text Field、Keycap、Icon Button、Playback Footer Layout）
- `docs/human/design/UI Application Rules.md`（菜单模态）

# 需求描述

## 1. 范围

1. 设置窗口新增 Shortcuts 分类，位于 Play 之下，用于修改播放页、Playback Overlay 与 Command Panel 的键盘快捷键。
2. 只做键盘；手柄改键本版本不做，也不显示。

## 2. 页面

1. 自上而下：Page Title；Open Command Panel 一行，不属于任何分组；Section Title `Playback` 及其功能；Section Title `Playback Overlay & Command Panel` 及其功能。
2. 分组不加说明文字；不列出不可修改的键；不设「全部恢复默认」。
3. 每行依次为功能名称、录入栏、恢复默认按钮。功能名称一列取全页最长名称的宽度，录入栏与该列相隔 `--spacing-6`，不右对齐。
4. 功能名称沿用其它设置分类现有的名称样式。
5. 录入栏以 Keycap 显示按键，⇧ 与主键各占一个 Keycap；回车使用 Playback Footer 中 Play 的回车图标。
6. 录入栏下方常驻一行，沿用 Text Field 的 Validation Message，与录入栏左边缘对齐；这一行兼作行距，行与行之间不再另加间距。
7. 恢复默认按钮在当前为默认键时不可用。

## 3. 功能与默认键

| 位置 | 功能 | 默认键 |
| --- | --- | --- |
| 分组之上 | Open Command Panel | `K` |
| Playback | Play / Pause | `Space` |
| Playback | Seek Backward | `←` |
| Playback | Seek Forward | `→` |
| Playback | Volume Up | `↑` |
| Playback | Volume Down | `↓` |
| Playback | Speed Down | `⇧ ,` |
| Playback | Speed Up | `⇧ .` |
| Playback | Previous | `A` |
| Playback | Next | `D` |
| Playback | Toggle Subtitles | `Q` |
| Playback | Repeat | `R` |
| Playback | Copy Screenshot | `P` |
| Playback | Toggle Fullscreen | `F` |
| Playback | Open Playback Overlay | 回车 |
| Playback Overlay & Command Panel | Save to Shiori | `S` |
| Playback Overlay & Command Panel | Copy Cue Text | `C` |
| Playback Overlay & Command Panel | Copy Deep Link | `X` |
| Playback Overlay & Command Panel | Edit Collage | `P` |

## 4. 录入

1. 点击录入栏进入录入：显示占位文字，录入栏内右侧出现 ×（Icon Button / Inline Clear）。录入栏不参与 Tab 切换。
2. 录入期间键盘只归录入栏，App 菜单快捷键也不生效；被系统拦截的按键（例如 ⌘Tab、⌘Space）照常由系统处理，录入状态不变。
3. 合法按键：写入并结束录入。
4. Esc 或点击录入栏以外：结束录入，键位不变。
5. 点击 ×：清空该功能的快捷键并结束录入。
6. 只按修饰键不算输入，继续等待主键。

## 5. 允许的按键

1. 只接受单键，或 ⇧ 加单键。Backspace 与 Delete 可以作为快捷键。
2. 以下按键不写入，下方显示提示，保持录入：

| 按键 | 提示 |
| --- | --- |
| 含 ⌘、⌃、⌥ 的组合 | 含修饰键 |
| Tab | 保留键 |
| 回车与方向键，用于 `Playback Overlay & Command Panel` 分组的功能或 Open Command Panel 时 | 保留键 |
| F1–F12、Home、End、Page Up、Page Down | 不支持 |

## 6. 冲突

1. 同一分组内的功能不能使用相同的键；Open Command Panel 与全部功能比较；不同分组之间可以相同。
2. 出现相同的键时照常写入，冲突各方的录入栏显示 Text Field 的 Error 外观，下方显示「冲突」文案，涉及多个功能时用逗号分隔。
3. 冲突期间，该键对冲突各方都不生效；任意一方改键、清空或恢复默认后冲突解除，各方恢复。
4. 恢复默认遵循同一规则：默认键已被占用时进入冲突。

## 7. 生效与联动

1. 改键立即生效，冲突状态一并保存，App 重启后保留。
2. Playback Overlay 与 Command Panel 页脚中 Save to Shiori、Copy Cue Text、Copy Deep Link 的 Keycap 显示当前键位；功能处于冲突或已清空时，按钮只显示文字，点击照常执行。

## 8. 文案

| 用途 | English | 简体 | 繁体 |
| --- | --- | --- | --- |
| 分类名称 | Shortcuts | 快捷键 | 快速鍵 |
| 录入占位 | Press a key | 按下按键 | 按下按鍵 |
| 冲突 | Conflicts with “{name}” | 与“{name}”冲突 | 與「{name}」衝突 |
| 含修饰键 | Can’t include ⌘, ⌃ or ⌥ | 不能包含 ⌘、⌃ 或 ⌥ | 不能包含 ⌘、⌃ 或 ⌥ |
| 保留键 | Reserved key | 保留按键 | 保留按鍵 |
| 不支持 | Not supported | 不支持此按键 | 不支援此按鍵 |

功能名称与分组标题的简体、繁体沿用 App 中已有的同名文案，没有现成文案的按同样风格翻译。

# 验收

1. Play 之下出现 Shortcuts，页面结构、分组与默认键符合第 2、3 节；默认状态没有冲突提示，恢复默认按钮都不可用。
2. 改一个键后立即生效，旧键不再触发；恢复默认后回到默认键。
3. 录入中按 Esc 或点击别处，键位不变；点 × 后该功能没有快捷键；按 ⌘Q 不退出 App。
4. Backspace、Delete 能录入；第 5 节不允许的按键逐类试过，均不写入、提示正确、仍在录入。
5. 同组两个功能改成同一个键：两行都提示冲突，按该键两者都不执行；改掉其中一个后两者恢复。
6. 不同分组可以使用相同的键；Open Command Panel 与任一功能相同时都提示冲突。
7. 页脚 Keycap 随改键变化；冲突或清空时只显示文字，点击照常执行。
8. 重启 App 后，改键与冲突状态保留。
9. 英文、简体、繁体，以及 Light、Dark 下分别核对。
10. 本次改动不新增任何自动化端到端或单元用例的失败。