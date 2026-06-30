# 版本
main

# 需求描述
1. 需要修改Search和Shiori界面的表格的渲染方式。
2. Search界面，搜索/筛选/排序结果全量缓存cueGroupID和显示内容。
3. Search界面，完全禁用Core搜索缓存（ID-only小缓存也禁用）。
4. Search界面，搜索任意结果时，后台exact/progress应分段构造并发布compact display rows、cueGroupID、计数和文件摘要；UI只能暴露已可同步渲染的rows，确保rows label、滚动条rowCount、可立即渲染rows严格一致。
5. Shiori界面，常驻ID列表+计数+文件摘要。
6. Search和Shiori界面的Search，应该有一个通用的搜索核心，通用搜索核心应输出统一的结果ID、显示内容和列描述模型。Search与Shiori的差异通过数据范围、可用列和scope-specific row metadata表达（Shiori界面多出Date Added列，后续可能还会有其他列），而不是维护两套搜索/表格逻辑。