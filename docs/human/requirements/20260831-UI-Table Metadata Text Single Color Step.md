# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Tables）

# 关联需求

- `docs/human/requirements/20260830-UI-Neutral Text Ramp And Table Text Hierarchy.md`
- `docs/human/requirements/20260831-UI-Table Header Font Weight.md`

# 需求描述

## 1. 背景

Display Title 与 Time Range 当初升到 `--color-text-secondary`，是为了和当时同处
secondary 的列头拉开。列头随后降到 `--color-text-muted` 并改用 Medium 字重区分，
这个理由不再成立，内容区却留下了 secondary 与 muted 两档并存、分档依据说不清的状态。

表格改为：元信息统一为一档，层级交给字号与字重。

## 2. 文字指派

| 元素 | Color | Font Weight |
| --- | --- | --- |
| 列头（#、Cues、Display Title、Time Range、Date Added） | `--color-text-secondary` | Medium |
| 序号列 | `--color-text-muted` | Regular |
| 目标字幕 | `--color-text-primary` | Medium |
| Cue Group 附加字幕 | `--color-text-secondary` | Regular |
| Display Title | `--color-text-secondary` | Regular |
| Time Range | `--color-text-secondary` | Regular |
| Date Added | `--color-text-secondary` | Regular |

其中三处为变更，均由 `--color-text-muted` 改为 `--color-text-secondary`：列头、
Cue Group 附加字幕、Date Added。

`--color-text-muted` 在表格内仅保留给序号列。

## 3. 设计系统同步

1. `Table Header Cell / Label / Color` 改为 `--color-text-secondary`。
2. `Table Cell / Text / Color` 不再按列分档，合并为 `--color-text-secondary`。
3. `Table Cell / Interactive Text` 的 Cue Group 附加字幕 Color 改为
   `--color-text-secondary`。

## 4. 不变项

1. 所有字号、行高、间距、对齐、背景、Hover、选中、右键菜单与播放入口不变。
2. 文字色 token 的取值不变，不新增 token。
3. 不可用行的文字继续使用 `--color-text-muted`。
4. 表格内的标签（Tag）颜色不变。
5. 表格以外的界面不受影响。

# 验收

1. 列头与 Display Title、Time Range、Date Added 同色，仅靠字重区分。
2. 内容区的三列元数据颜色完全一致，不再分成两档。
3. Cue Group 附加字幕仍明显轻于目标字幕，靠字号、字重与颜色三项区分。
4. 表格内只有序号列使用 `--color-text-muted`。
5. Light 与 Dark 两个主题分别核对。
6. 本次改动不新增任何自动化端到端或单元用例的失败。