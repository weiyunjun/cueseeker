# 版本
main

# 需求描述
1. 现状：Settings - Library中，移除一个地址，会稳定触发彩虹圆圈。
2. 修改方案：1. Removing 与 Indexing 必须互斥，但 Removing 不能阻塞 macOS 主事件循环。2. 删除时只移除目标 FTS 和排序记录，保留现有目标数据清理行为，不再全库重建；删除不会改变剩余结果的相对顺序。3. 增加大数据库删除性能测试和主线程响应测试。
3. 验收标准：1. 删除期间可观察到 removing(folder)，主事件循环持续响应。2. 保留 FTS 行不被重新编号。3. 失败时资料库地址和现有展示状态不被提前移除。4. Indexing 已开始时，Remove按钮变为disabled状态。5. 删除期间不再出现彩虹圆圈或其它视觉上的卡顿感受。

# 删除流程
1. 进入全局数据库操作状态：removing(folder)
2. 立即禁用 Add Folder、Remove、Index Now、数据库压缩
3. 后端同样拒绝新的 Index 请求，不能只依赖按钮禁用
4. 在串行数据库执行器中完成删除
5. 成功后刷新界面并回到 idle；失败则恢复状态并提示错误

# 细节说明
1. Indexing 已开始时，Remove按钮变为disabled状态，UI上拒绝用户移除。
2. Indexing 已开始时，后端也应该拒绝 Remove，双向互斥。