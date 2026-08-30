# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Text、Tables、Menus）

# 需求描述

## 1. 文字色 Token 取值重定义

现有文字色偏蓝且最深一档过浅：`--color-text-primary` 只有 10.4:1，低于主流前端框架
最深一档 15–20:1 的区间一整档，导致界面整体发灰。重新定义为四档纯中性灰，相邻档之间
约 1.8 倍对比度：

- `--color-text-primary`：Light `#1F1F1F`；Dark `#F7F7F7`
- `--color-text-secondary`：Light `#494949`；Dark `#B9B9B9`
- `--color-text-muted`：Light `#717171`；Dark `#878787`
- `--color-text-placeholder`：Light `#9A9A9A`；Dark `#606060`
- `--color-text-disabled`：Light `#9A9A9A`；Dark `#606060`

原取值 `#404040`、`#535761`、`#667085`、`#98A2B3` 及其 Dark 对应值退役，不再作为
任何文字色使用。

Token 名称与数量不变。图标色、状态色、危险色、播放页 `--color-player-text-*` 不受影响。

## 2. 表格文字指派

| 文字 | Color | Font Weight |
| --- | --- | --- |
| Table Header Cell 标签 | `--color-text-muted` | Regular |
| 序号列 | `--color-text-muted` | Regular |
| 目标字幕 | `--color-text-primary` | Medium |
| Cue Group 附加字幕 | `--color-text-muted` | Regular |
| Display Title | `--color-text-secondary` | Regular |
| Time Range | `--color-text-secondary` | Regular |
| Date Added | `--color-text-muted` | Regular |

其中三处为变更：列头由 `--color-text-secondary` + Medium 改为上表取值；Display Title
与 Time Range 由 `--color-text-muted` 升为 `--color-text-secondary`；Display Title、
Time Range 与 Date Added 的字重由 Medium 降为 Regular。

目标字幕的 Medium 与 Cue Group 附加字幕的 Regular 是现状，上表记录规格，不产生改动。

所有列头的字号、字重、颜色必须完全一致，不因列而异。

## 3. 设计系统条目补记

以下四处为文档漏记或已不成立，本次一并补上：

1. `Table Cell / Interactive Text` 只记了一个颜色，实际有两行。补充为：目标字幕
   `--color-text-primary`，Cue Group 附加字幕 `--color-text-muted`。
2. `Table Cell / Text` 只记了一个颜色，本次起按列分档。改为：Display Title 与
   Time Range `--color-text-secondary`，序号与 Date Added `--color-text-muted`。
3. `Table Cell` 的两个变体都缺少 Font Weight 条目。补充为：目标字幕 Medium，
   其余一律 Regular。
4. `Table Header Cell` 的 Label 缺少 Font Weight 条目，补充为 Regular。

## 4. 不变项

1. 菜单的全部文字指派不变，仅随 token 取值变深。
2. 所有字号、行高、布局、间距、圆角、背景与图标色不变。
3. 搜索框占位符继续使用 `--color-text-placeholder`。
4. 表格行的 Hover、选中、右键菜单与播放入口不变。
5. 不可用行的目标字幕继续使用 `--color-text-muted`，字重跟随目标字幕。

# 验收

1. 表格四档颜色由深到浅依次拉开，目标字幕明显重于其余文字。
2. 五个列头的字号、字重、颜色完全一致。
3. Display Title 与 Time Range 深于 Date Added 与列头。
4. 菜单整体变深，Menu Title、分节标题、选项文字、计数四级层级关系不变。
5. 所有文字不再有蓝色倾向。
6. Dark 主题下 `--color-text-muted` 与 `--color-text-placeholder` 较改动前变暗，
   需在真机确认可读性后再接受本项。
7. `#404040`、`#535761`、`#667085`、`#98A2B3` 不再作为文字色出现在设计系统与代码中。
8. Light 与 Dark 两个主题分别核对以上各项。
9. 本次改动不新增任何自动化端到端或单元用例的失败。仓库现有失败项与本需求无关，
   在需求提交版本上同样存在。
10. 表格内除目标字幕外的全部文字为 Regular，目标字幕为 Medium。