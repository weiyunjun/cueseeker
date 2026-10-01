# 版本

main

# 关联设计

- `docs/human/design/Data.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 资料库任务期间界面保持可用

1. Index、Add Folder、Remove Folder 执行期间，Search 与 Excerpt 各级界面照常显示且可操作，不自动清空，不发生刷新闪烁。

## 2. 任务完成后惰性刷新

1. 资料库任务完成后，当前停留在 Search 或 Excerpt 界面时不立即重刷列表。
2. 界面再次出现时（包括切换标签页返回、前进/后退、从播放页返回、Excerpt 一二级切换），读取最新数据库状态：
   - Excerpt 界面标记失效与变更条目，保留滚动位置与 Filter 筛选条件。
   - Search 界面在用户点击结果播放时同步剔除失效项；未进入播放前保持现有结果。

# 验收

1. 延时模拟下，后台任务执行期间进入或停留在 Search 与 Excerpt：内容不清空，操作流畅。
2. 任务完成后停留在界面：无自动刷新，无闪烁。
3. 离开后再返回 Excerpt 界面：失效条目标记正确呈现，滚动位置与 Filter 保留。
4. 点击失效 Search 条目播放再返回：失效条目已从搜索结果中剔除。
5. 单元测试与集成测试全部通过。