# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽）
- `docs/human/design/UI Design System.md`（Dialogs / Confirmation Dialog）

# 需求描述

## 1. 目标

Confirmation 与 Edit Cover、Shiori List Editor 同属对话框层，三者的呈现方式、压暗范围与输入屏蔽必须完全一致。

## 2. 屏蔽范围

1. Confirmation 打开期间，整个主窗口压暗，Sidebar、顶栏与页面一同变化，压暗强度与 Edit Cover、Shiori List Editor 一致。
2. Confirmation 打开期间，它之外的指针移动、hover、点击、滚轮与键盘一律不送达下层，Sidebar 与顶栏同样不接受输入、不出现 hover 变化。
3. Confirmation 打开期间，下层保持打开前的画面：当前项、高亮与选中停在原处。
4. Confirmation 关闭后下层恢复接受输入，高亮在指针真实移动之后才改变。

## 3. 统一呈现

1. 全部模态对话框由同一套模态呈现给出压暗与屏蔽，任何对话框不得自行绘制遮罩或自行实现屏蔽。
2. Confirmation 不再保留自绘的半透明遮罩。

## 4. 模态叠加

1. 对话框之上允许再打开 Confirmation，模态之间不互斥。
2. 叠加时上层 Confirmation 屏蔽下层对话框，关闭后下层对话框恢复接受输入。
3. 本需求不新增任何叠加场景，只要求机制允许。

## 5. 适用范围

1. 删除 Shiori 列表的确认。
2. 移除单条 Shiori 的确认。

## 6. 保持不变

1. Confirmation 的标题、正文、按钮文案、按钮样式与顺序不变。
2. 回车与 Esc 的行为不变。
3. 确认与取消触发的实际操作不变。
4. Settings 独立窗口内的系统确认界面不属于本需求。
5. 不新增、不修改、不替换任何颜色、尺寸、圆角与间距 token。

## 7. 设计文档同步

验收通过后，由人类维护者在 `UI Application Rules.md` 的「更高层界面的屏蔽」补充一条：对话框之间允许叠加，上层屏蔽下层。

# 验收

1. 在 Shiori 概览打开删除列表确认框：整窗口压暗，Sidebar 与顶栏的变化与打开 Edit List 时一致。
2. 确认框打开期间点击 Sidebar 任意项、顶栏返回按钮与侧栏开关，均无响应且无 hover 变化。
3. 确认框打开期间滚轮不滚动下层页面。
4. 取消或确认后下层恢复输入，卡片高亮停在打开前的位置，直到指针真实移动才改变。
5. 在 Shiori 列表表格移除单条 Shiori，第 1 至第 4 条同样成立。
6. 确认框上回车与 Esc 的行为与本需求前一致。
7. 现有自动化端到端与单元用例全部通过。