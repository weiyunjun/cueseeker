# 版本

main

# 关联设计

- `docs/human/design/Toast Usage Registry.md`

# 需求描述

## 1. 批量操作失效拦截

1. 在 Search 与 Excerpt 的 Selection Action Overlay 中，执行 Export to Anki、Copy Deep Links、Copy Table 时校验所选条目：
   - 全部条目失效：拦截操作并弹出 Toast。单条为 `Cue Not in Library`，多条为 `Cues Not in Library`（中文提示与单数一致）。
   - 部分条目失效：仅对有效条目执行操作，界面的选择勾选状态保持不变。

## 2. 行菜单操作失效拦截

1. 在 Excerpt 列表的行菜单中，点击 `Move to List` 或 `Duplicate to List` 时：
   - 若该条目已失效，拦截操作并弹出 Toast `Cue Not in Library`。

# 验收

1. 勾选失效条目触发导出或复制：全部失效时按单复数正确弹出 Toast；部分失效时正常处理有效条目。
2. 在行菜单中对失效 Excerpt 触发移动或复制：操作被拦截并弹出 Toast。
3. 单元测试与集成测试全部通过。