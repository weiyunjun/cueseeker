# 版本

main

# 关联需求

- `docs/human/requirements/20260819-Engineering-Remove Fixed E2E Scene Size Preconditions.md`
- `docs/human/requirements/20260815-Feature-Data Indexed Content Management.md`

# 需求目标

修正 Debug In-App E2E 流程中残留的固定场景尺寸依赖和过期导航坐标。

# 需求

1. E2E 不得因主窗口尺寸或缩放倍率不同而停止。
2. 删除与特定窗口宽度绑定的绝对内容边界验收值，改为根据当前窗口边界和设计间距验证。
3. 更新 Sidebar 坐标契约，使其与 Library、Data、Shiori 的当前顺序一致。
4. 操作坐标可以根据 `inspect` 返回的窗口边界计算，但不得通过截图重新寻找控件。
5. 保留 sceneID、窗口数量、窗口布局和过期场景拒绝规则。

# 范围

1. 仅修正 E2E 测试契约和相关文档。
2. 不修改产品界面、业务行为或 E2E Controller。

# 验收标准

1. 当前 `1445 × 821` 场景可以正常执行 Library 和 Shiori 二级界面截图流程。
2. 其他窗口尺寸和缩放倍率下，相同窗口布局不会被误判为无效。
3. Library、Data、Shiori 及其二级入口均能命中正确目标。
4. 不再存在依赖某个固定场景宽度的验收条件。