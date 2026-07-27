# 版本
main

# 需求描述

对前端 Search 状态所有权进行最小化架构调整，不改变现有产品行为。

1. 删除已确认不再使用的旧分组、卡片式搜索结果路径。
2. `SearchStore` 统一管理搜索查询、数据库访问、任务、分页游标、generation 和结果状态。
3. `AppCoordinator` 只保留播放、Shiori、Library 等跨功能协调。
4. View 只保留焦点、IME、滚动和临时选择等界面状态。
5. 收紧状态写入权限，通过必要的意图方法修改状态。
6. 保持现有 Search、Filter、Context、分页、选择和播放行为不变。
7. Playback Command Panel 搜索行为遵循 `docs/human/design/Command Panel.md`。
8. 不新增模块、框架、平行状态模型或无关抽象。
9. 按最小阶段修改、验证并分别提交 Git。