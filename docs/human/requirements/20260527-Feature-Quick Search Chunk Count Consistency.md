### 版本
feature/playback-quick-search
### 需求描述
1. 视频播放页，Quick Search复用搜索页的同一个计数入口。
2. 选中chunk时，右上角的数字，与搜索页结果页的xx results一致，即exact count。
3. 计数查询必须后台执行，不阻塞UI。后台搜索完毕后要更新到前端界面。
4. 显示顺序保持 API 返回顺序；后台计数可以按当前选中优先，不要求阻塞式按顺序完成。
5. 本次需求不修改UI界面和API请求的逻辑。
### 验收重点
1. chunks返回后，右上角的数字不能一直转圈。
2. 左右切换chunk时，旧chunk的count不能显示到新chunk。